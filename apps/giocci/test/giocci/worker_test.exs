defmodule Giocci.WorkerTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  import Mock

  setup_with_mocks([
    {Giocci.SessionManager, [], [session_id: fn -> :dummy_session_id end]}
  ]) do
    :ok
  end

  setup do
    pid = start_supervised!({Giocci.Worker, [client_name: "giocci"]})

    %{worker_pid: pid}
  end

  test "register_client/3" do
    assert {:error, "zenohex_error: badarg"} =
             Giocci.Worker.register_client("missing-relay")
  end

  test "unregister_client/2 sends a request without local registration", %{worker_pid: pid} do
    reply = %{data: nil, measurements: %{}}

    with_mock Giocci.Utils,
      zenohex_get: fn _, key, timeout, term ->
        assert key == "giocci/unregister/client/relay-1"
        assert timeout == 5_000
        assert term == %{data: %{client_name: "giocci"}, measurements: %{}}
        {:ok, {:ok, reply}}
      end do
      assert :ok = Giocci.Worker.unregister_client("relay-1")
      assert :ok = Giocci.Worker.unregister_client("relay-1")
    end

    assert :sys.get_state(pid).registered_relays == []
  end

  test "unregister_client/2 removes only the target on success and sends measurements",
       %{worker_pid: pid} do
    :sys.replace_state(pid, fn state ->
      %{state | registered_relays: ["relay-1", "relay-2"]}
    end)

    measurements = %{
      client_send_timestamp_to_relay: 1,
      relay_recv_timestamp_from_client: 2,
      relay_send_timestamp_to_client: 3,
      client_recv_timestamp_from_relay: 4
    }

    with_mock Giocci.Utils,
      zenohex_get: fn _, _, timeout, _ ->
        assert timeout == 250
        {:ok, {:ok, %{data: nil, measurements: measurements}}}
      end do
      assert :ok = Giocci.Worker.unregister_client("relay-1", timeout: 250, measure_to: self())
    end

    assert_received {:giocci_measurements, %{client_to_relay: _, relay_to_client: _}}

    assert :sys.get_state(pid).registered_relays == ["relay-2"]
  end

  test "unregister_client/2 keeps local registration on errors", %{worker_pid: pid} do
    :sys.replace_state(pid, fn state -> %{state | registered_relays: ["relay-1"]} end)

    for response <- [
          {:error, "timeout"},
          {:error, "connection_failed"},
          {:ok, {:error, "term_not_expected"}},
          {:ok, :unexpected}
        ] do
      with_mock Giocci.Utils, zenohex_get: fn _, _, _, _ -> response end do
        expected =
          if response == {:ok, :unexpected} do
            {:error, "unexpected_reply"}
          else
            case response do
              {:ok, error} -> error
              error -> error
            end
          end

        assert ^expected = Giocci.Worker.unregister_client("relay-1")
        assert :sys.get_state(pid).registered_relays == ["relay-1"]
      end
    end
  end

  test "save_module/3 returns error for unregistered relay" do
    assert capture_log(fn ->
             assert {:error, "relay_not_registered"} =
                      Giocci.Worker.save_module("missing-relay", Giocci.Worker)
           end) == ""
  end

  test "save_module/3 warns when a registered relay loses its client registration",
       %{worker_pid: pid} do
    :sys.replace_state(pid, fn state -> %{state | registered_relays: ["relay-1"]} end)

    with_mock Giocci.Utils,
      zenohex_get: fn _, _, _, _ -> {:ok, {:error, "client_not_registered"}} end do
      log =
        capture_log(fn ->
          assert {:error, "client_not_registered"} =
                   Giocci.Worker.save_module("relay-1", Giocci.Worker)
        end)

      assert log =~ ~s(Relay "relay-1" may have lost the client registration)
      assert log =~ ~s|Giocci.register_client("relay-1")|
      assert log =~ "[warning]"
    end
  end

  test "save_module/3 does not warn for other relay errors", %{worker_pid: pid} do
    :sys.replace_state(pid, fn state -> %{state | registered_relays: ["relay-1"]} end)

    for response <- [
          {:ok, {:error, "module_not_found"}},
          {:error, "timeout"},
          {:error, "connection_failed"}
        ] do
      with_mock Giocci.Utils, zenohex_get: fn _, _, _, _ -> response end do
        assert capture_log(fn ->
                 assert {:error, _} = Giocci.Worker.save_module("relay-1", Giocci.Worker)
               end) == ""
      end
    end
  end

  test "exec_func/3 returns error for unregistered relay" do
    assert {:error, "relay_not_registered"} =
             Giocci.Worker.exec_func(
               "missing-relay",
               {Giocci.Worker, :start_link, [[]]}
             )
  end

  test "save_module/3 returns error for missing module", %{worker_pid: pid} do
    :sys.replace_state(pid, fn state ->
      %{state | registered_relays: ["relay-1"]}
    end)

    missing_module = Module.concat(["Giocci", "MissingModule"])

    assert {:error, "get_object_code_failed"} =
             Giocci.Worker.save_module("relay-1", missing_module)
  end

  test "save_module/3 sends dynamically compiled BEAM", %{worker_pid: pid} do
    module = Module.concat(__MODULE__, Dynamic)
    on_exit(fn -> :persistent_term.erase({Giocci.DynamicModule, module}) end)

    [{^module, beam}] =
      Code.compile_string("""
      defmodule #{inspect(module)} do
        use Giocci.DynamicModule
        def version, do: 1
      end
      """)

    assert :error == :code.get_object_code(module)

    :sys.replace_state(pid, fn state ->
      %{state | registered_relays: ["relay-1"]}
    end)

    test_pid = self()

    with_mock Giocci.Utils,
      zenohex_get: fn _session, _key, _timeout, %{data: %{module_object_code: object_code}} ->
        send(test_pid, {:sent_object_code, object_code})
        {:ok, {:ok, %{data: nil, measurements: %{}}}}
      end do
      assert :ok = Giocci.Worker.save_module("relay-1", module)
      assert_receive {:sent_object_code, {^module, ^beam, filename}}
      assert is_list(filename)
    end
  end

  test "save_module/3 rejects a cached BEAM after redefinition without use" do
    module = Module.concat(__MODULE__, Redefined)
    on_exit(fn -> :persistent_term.erase({Giocci.DynamicModule, module}) end)
    Code.compiler_options(ignore_module_conflict: true)

    [{^module, old_beam}] =
      Code.compile_string("""
      defmodule #{inspect(module)} do
        use Giocci.DynamicModule
        def version, do: 1
      end
      """)

    [{^module, _new_beam}] =
      Code.compile_string("""
      defmodule #{inspect(module)} do
        def version, do: 2
      end
      """)

    assert 2 == module.version()

    assert {:error, "dynamic_module_stale"} =
             Giocci.Worker.save_module("relay-1", module)

    [{^module, latest_beam}] =
      Code.compile_string("""
      defmodule #{inspect(module)} do
        use Giocci.DynamicModule
        def version, do: 3
      end
      """)

    assert latest_beam != old_beam
    assert {^module, ^latest_beam, _filename} = Giocci.DynamicModule.object_code(module)
  end

  test "save_module/3 returns error for a dynamic module without use" do
    module = Module.concat(__MODULE__, Untracked)

    [{^module, _beam}] =
      Code.compile_string("""
      defmodule #{inspect(module)} do
        def version, do: 1
      end
      """)

    assert {:error, "get_object_code_failed"} =
             Giocci.Worker.save_module("relay-1", module)
  end

  test "modules compiled to files still use the code path" do
    assert Giocci.DynamicModule.object_code(Giocci.Worker) ==
             :code.get_object_code(Giocci.Worker)
  end
end
