defmodule Giocci.InspectTest do
  use ExUnit.Case
  import Mock

  setup do
    start_supervised!({Giocci.Worker, [client_name: "client", key_prefix: "scope"]})
    :ok
  end

  test "list_relays returns no candidates without contacting the relay" do
    with_mock Giocci.Utils,
      zenohex_get: fn _, _, _, _, _ -> flunk("unexpected remote query") end do
      assert {:ok, []} = Giocci.Inspect.list_relays()
    end
  end

  test "list_relays sorts confirmed relays and reports registration mismatches and timeouts" do
    :sys.replace_state(Giocci.Worker, fn state ->
      %{state | registered_relays: ["relay-c", "relay-a", "relay-b", "relay-a"]}
    end)

    test_pid = self()

    with_mocks([
      {Giocci.SessionManager, [], [session_id: fn -> :dummy_session_id end]},
      {Giocci.Utils, [],
       [
         zenohex_get: fn _,
                         key,
                         timeout,
                         %{data: %{client_name: "client"}},
                         record_measurements: false,
                         consolidation: :none ->
           send(test_pid, {:queried, key, timeout})

           case Path.basename(key) do
             "relay-a" -> {:ok, {:ok, %{data: true, measurements: %{}}}}
             "relay-b" -> {:ok, {:ok, %{data: false, measurements: %{}}}}
             "relay-c" -> {:error, "timeout: relay-c timed out after 70ms"}
           end
         end
       ]}
    ]) do
      assert {:warn, ["relay-a"],
              [
                %{relay: "relay-b", reason: "client_not_registered"},
                %{relay: "relay-c", reason: "timeout: relay-c timed out after 70ms"}
              ]} = Giocci.Inspect.list_relays(timeout: 70)

      for relay <- ~w(relay-a relay-b relay-c) do
        assert_receive {:queried, "scope/giocci/inspect/relay/" <> ^relay, 70}
      end
    end
  end

  test "list_relays returns all reasons when no registration can be confirmed" do
    :sys.replace_state(Giocci.Worker, fn state ->
      %{state | registered_relays: ["relay-b", "relay-a"]}
    end)

    with_mocks([
      {Giocci.SessionManager, [], [session_id: fn -> :dummy_session_id end]},
      {Giocci.Utils, [],
       [
         zenohex_get: fn _, key, _, _, record_measurements: false, consolidation: :none ->
           if String.ends_with?(key, "relay-a") do
             {:ok, {:ok, %{data: false, measurements: %{}}}}
           else
             {:error, "connection_failed: relay-b"}
           end
         end
       ]}
    ]) do
      assert {:error,
              [
                %{relay: "relay-a", reason: "client_not_registered"},
                %{relay: "relay-b", reason: "connection_failed: relay-b"}
              ]} = Giocci.Inspect.list_relays()
    end
  end

  test "inspection addresses engines directly without registering the client" do
    test_pid = self()

    with_mocks([
      {Giocci.SessionManager, [], [session_id: fn -> :dummy_session_id end]},
      {Giocci.Utils, [],
       [
         zenohex_get: fn _,
                         key,
                         _,
                         %{data: %{operation: operation}},
                         record_measurements: false,
                         consolidation: :none ->
           send(test_pid, {key, operation})
           {:ok, {:ok, %{data: :pong, measurements: %{}}}}
         end
       ]}
    ]) do
      assert {:ok, %{rtt_ms: rtt_ms}} = Giocci.Inspect.ping_engine("engine")
      assert rtt_ms >= 0
      assert_receive {"scope/giocci/inspect/engine/engine", :ping}
    end
  end

  test "remote module and function names stay strings without interning new atoms" do
    module_name = "Elixir.UnloadedModule#{System.unique_integer([:positive])}"
    function_name = "unloaded_function_#{System.unique_integer([:positive])}"
    assert_raise ArgumentError, fn -> String.to_existing_atom(module_name) end
    assert_raise ArgumentError, fn -> String.to_existing_atom(function_name) end

    with_mocks([
      {Giocci.SessionManager, [], [session_id: fn -> :dummy_session_id end]},
      {Giocci.Utils, [],
       [
         zenohex_get: fn
           _,
           _,
           _,
           %{data: %{operation: operation}},
           record_measurements: false,
           consolidation: :none ->
             value =
               case operation do
                 :list_modules ->
                   [module_name]

                 :list_functions ->
                   [{function_name, 0}]

                 :module_info ->
                   %{
                     "module" => module_name,
                     "beam_sha256" => String.duplicate("a", 64),
                     "beam_size_bytes" => 10,
                     "saved_at" => "2026-10-16T12:00:00Z"
                   }
               end

             {:ok, {:ok, %{data: value, measurements: %{}}}}
         end
       ]}
    ]) do
      assert {:ok, [^module_name]} = Giocci.Inspect.list_modules("relay")

      assert {:ok, [{^function_name, 0}]} =
               Giocci.Inspect.list_functions("relay", module_name)

      assert {:ok, %{module: ^module_name}} = Giocci.Inspect.module_info("relay", module_name)
      assert {:error, "unexpected_reply"} = Giocci.Inspect.module_info("relay", 123)
    end

    assert_raise ArgumentError, fn -> String.to_existing_atom(module_name) end
    assert_raise ArgumentError, fn -> String.to_existing_atom(function_name) end
  end

  test "inspection_info waits for a busy worker beyond the default GenServer timeout" do
    worker = Process.whereis(Giocci.Worker)
    :ok = :sys.suspend(worker)

    task = Task.async(fn -> Giocci.Worker.inspection_info() end)
    Process.sleep(5_100)
    pending = Task.yield(task, 0)

    :ok = :sys.resume(worker)
    assert pending == nil
    assert %{client_name: "client"} = Task.await(task, 1_000)
  end
end
