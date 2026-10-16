defmodule GiocciIntegrationTestTest do
  use ExUnit.Case

  @moduletag capture_log: true

  @relay_name "giocci_relay"
  @engine_name "giocci_engine"
  @client_name "giocci"
  @giocci_zenoh_config_path Path.expand("../../giocci/config/zenoh.json5", __DIR__)
  @giocci_relay_zenoh_config_path Path.expand("../../giocci_relay/config/zenoh.json5", __DIR__)
  @giocci_engine_zenoh_config_path Path.expand("../../giocci_engine/config/zenoh.json5", __DIR__)

  # Timeout for waiting engine response after it's stopped
  @engine_stopped_timeout 1000
  # Timeout for async message delivery
  @async_message_timeout 1000

  # Common setup for starting relay and client
  defp setup_relay_and_client do
    :ok = Application.put_env(:giocci_relay, :relay_name, @relay_name)
    {:ok, _} = Application.ensure_all_started(:giocci_relay)

    :ok = Application.put_env(:giocci, :client_name, @client_name)
    {:ok, _} = Application.ensure_all_started(:giocci)

    on_exit(fn ->
      :ok = Application.stop(:giocci)
      :ok = Application.delete_env(:giocci, :client_name)

      :ok = Application.stop(:giocci_relay)
      :ok = Application.delete_env(:giocci_relay, :relay_name)
    end)
  end

  # Setup for starting engine
  defp setup_engine do
    :ok = Application.put_env(:giocci_engine, :engine_name, @engine_name)
    :ok = Application.put_env(:giocci_engine, :relay_name, @relay_name)
    {:ok, _} = Application.ensure_all_started(:giocci_engine)

    on_exit(fn ->
      cleanup_engine()
    end)
  end

  # Cleanup engine application
  defp cleanup_engine do
    Application.stop(:giocci_engine)
    Application.delete_env(:giocci_engine, :engine_name)
    Application.delete_env(:giocci_engine, :relay_name)
    :ok
  end

  defp assert_normal_scenario_works do
    assert :ok == Giocci.register_client(@relay_name)
    assert :ok == Giocci.save_module(@relay_name, GiocciIntegrationTest)
    assert 3 == Giocci.exec_func(@relay_name, {GiocciIntegrationTest, :add, [1, 2]})

    assert {:error, "function_not_defined: {GiocciIntegrationTest, :undefined_function, []}"} ==
             Giocci.exec_func(
               @relay_name,
               {GiocciIntegrationTest, :undefined_function, []}
             )

    :ok = Giocci.exec_func_async(@relay_name, {GiocciIntegrationTest, :add, [1, 2]}, self())

    assert_receive {:giocci, 3},
                   @async_message_timeout,
                   "Expected async response with result 3"
  end

  describe "happy path" do
    setup do
      setup_relay_and_client()
      setup_engine()
      :ok
    end

    test "normal scenario" do
      assert_normal_scenario_works()
    end

    test "dynamically compiled module is saved and updated" do
      module = GiocciIntegrationTest.DynamicModule
      Code.compiler_options(ignore_module_conflict: true)

      [{^module, _beam}] =
        Code.compile_string("""
        defmodule #{inspect(module)} do
          use Giocci.DynamicModule
          def add(a, b), do: a + b
        end
        """)

      assert :ok == Giocci.register_client(@relay_name)
      assert :ok == Giocci.save_module(@relay_name, module)
      assert 3 == Giocci.exec_func(@relay_name, {module, :add, [1, 2]})

      [{^module, _updated_beam}] =
        Code.compile_string("""
        defmodule #{inspect(module)} do
          use Giocci.DynamicModule
          def add(a, b), do: a + b + 1
        end
        """)

      assert :ok == Giocci.save_module(@relay_name, module)
      assert 4 == Giocci.exec_func(@relay_name, {module, :add, [1, 2]})
    end
  end

  describe "engine start timing" do
    setup do
      setup_relay_and_client()

      :ok = Application.put_env(:giocci_engine, :engine_name, @engine_name)
      :ok = Application.put_env(:giocci_engine, :relay_name, @relay_name)

      on_exit(fn ->
        cleanup_engine()
      end)

      :ok
    end

    test "engine starts before save_module - modules are distributed on registration" do
      assert :ok == Giocci.register_client(@relay_name)
      {:ok, _} = Application.ensure_all_started(:giocci_engine)
      assert :ok == Giocci.save_module(@relay_name, GiocciIntegrationTest)

      assert 3 == Giocci.exec_func(@relay_name, {GiocciIntegrationTest, :add, [1, 2]})
    end

    test "engine starts after save_module - modules are distributed on engine registration" do
      assert :ok == Giocci.register_client(@relay_name)
      assert :ok == Giocci.save_module(@relay_name, GiocciIntegrationTest)
      {:ok, _} = Application.ensure_all_started(:giocci_engine)

      assert 3 == Giocci.exec_func(@relay_name, {GiocciIntegrationTest, :add, [1, 2]})
    end
  end

  describe "error cases" do
    test "redefining a dynamic module without use does not replace the saved BEAM" do
      setup_relay_and_client()
      setup_engine()
      module = GiocciIntegrationTest.StaleDynamicModule
      Code.compiler_options(ignore_module_conflict: true)

      [{^module, saved_beam}] =
        Code.compile_string("""
        defmodule #{inspect(module)} do
          use Giocci.DynamicModule
          def add(a, b), do: a + b
        end
        """)

      assert :ok == Giocci.register_client(@relay_name)
      assert :ok == Giocci.save_module(@relay_name, module)
      assert 3 == Giocci.exec_func(@relay_name, {module, :add, [1, 2]})

      [{^module, _untracked_beam}] =
        Code.compile_string("""
        defmodule #{inspect(module)} do
          def add(a, b), do: a + b + 1
        end
        """)

      assert 4 == apply(module, :add, [1, 2])
      assert {:error, "dynamic_module_stale"} == Giocci.save_module(@relay_name, module)

      # Client and engine share this VM, so local redefinition also changes the engine's loaded code.
      assert {:ok, stored_modules} = GiocciRelay.ModuleStore.get()
      assert [{^module, ^saved_beam, _filename}] = stored_modules[@client_name]
    end

    test "relay not started - register_client fails" do
      :ok = Application.put_env(:giocci, :client_name, @client_name)
      {:ok, _} = Application.ensure_all_started(:giocci)

      on_exit(fn ->
        :ok = Application.stop(:giocci)
        :ok = Application.delete_env(:giocci, :client_name)
      end)

      result = Giocci.register_client(@relay_name)
      assert {:error, error_msg} = result

      assert String.starts_with?(error_msg, "connection_failed: "),
             "Expected connection_failed but got: #{inspect(result)}"

      assert String.contains?(error_msg, "may not be running"),
             "Expected 'may not be running' message but got: #{inspect(result)}"
    end

    test "relay started but no engine - exec_func fails" do
      setup_relay_and_client()

      assert :ok == Giocci.register_client(@relay_name)
      assert :ok == Giocci.save_module(@relay_name, GiocciIntegrationTest)

      assert {:error, "engine_not_registered"} ==
               Giocci.exec_func(@relay_name, {GiocciIntegrationTest, :add, [1, 2]})
    end

    test "engine registered then stopped - exec_func fails" do
      setup_relay_and_client()
      setup_engine()

      assert :ok == Giocci.register_client(@relay_name)
      assert :ok == Giocci.save_module(@relay_name, GiocciIntegrationTest)

      # Engine is working
      assert 3 == Giocci.exec_func(@relay_name, {GiocciIntegrationTest, :add, [1, 2]})

      # Stop engine manually (on_exit will handle cleanup if this fails)
      cleanup_engine()

      # Engine is no longer available - Zenoh channel is closed
      result =
        Giocci.exec_func(@relay_name, {GiocciIntegrationTest, :add, [1, 2]},
          timeout: @engine_stopped_timeout
        )

      assert {:error, error_msg} = result

      assert String.starts_with?(error_msg, "connection_failed: "),
             "Expected connection_failed after engine stopped but got: #{inspect(result)}"

      assert String.contains?(error_msg, "may not be running"),
             "Expected 'may not be running' message but got: #{inspect(result)}"
    end
  end

  describe "operation when ZENOHD_CONNECT_ENDPOINTS is set" do
    setup do
      on_exit(fn ->
        :ok = System.delete_env("ZENOHD_CONNECT_ENDPOINTS")
      end)

      :ok
    end

    test "single endpoint: connects all components and normal scenario works" do
      :ok = System.put_env("ZENOHD_CONNECT_ENDPOINTS", "tcp/localhost:7447")
      setup_relay_and_client()
      setup_engine()

      assert_normal_scenario_works()
    end

    test "multiple comma-separated endpoints with spaces: connects and works" do
      # Using the multiple endpoints to test the comma-separated parsing while keeping
      # the test self-contained on a local machine
      :ok =
        System.put_env("ZENOHD_CONNECT_ENDPOINTS", "tcp/localhost:7447, tcp/192.168.0.95:7447")

      setup_relay_and_client()
      setup_engine()

      assert_normal_scenario_works()
    end

    test "trailing comma with whitespace: whitespace-only segments are ignored" do
      :ok = System.put_env("ZENOHD_CONNECT_ENDPOINTS", "tcp/localhost:7447, ")
      setup_relay_and_client()
      setup_engine()

      assert_normal_scenario_works()
    end

    test "empty string: does not override connect.endpoints and normal scenario works" do
      :ok = System.put_env("ZENOHD_CONNECT_ENDPOINTS", "")
      setup_relay_and_client()
      setup_engine()

      assert_normal_scenario_works()
    end

    test "commas-only: does not override connect.endpoints and normal scenario works" do
      :ok = System.put_env("ZENOHD_CONNECT_ENDPOINTS", ",,")
      setup_relay_and_client()
      setup_engine()

      assert_normal_scenario_works()
    end
  end

  describe "operation with zenoh_config_file_path" do
    setup do
      :ok = System.put_env("ZENOHD_CONNECT_ENDPOINTS", "tcp/localhost:7447")
      :ok = Application.put_env(:giocci, :zenoh_config_file_path, @giocci_zenoh_config_path)

      :ok =
        Application.put_env(
          :giocci_relay,
          :zenoh_config_file_path,
          @giocci_relay_zenoh_config_path
        )

      :ok =
        Application.put_env(
          :giocci_engine,
          :zenoh_config_file_path,
          @giocci_engine_zenoh_config_path
        )

      on_exit(fn ->
        :ok = Application.delete_env(:giocci, :zenoh_config_file_path)
        :ok = Application.delete_env(:giocci_relay, :zenoh_config_file_path)
        :ok = Application.delete_env(:giocci_engine, :zenoh_config_file_path)
        :ok = System.delete_env("ZENOHD_CONNECT_ENDPOINTS")
      end)

      :ok
    end

    test "all components start and normal scenario works with zenoh_config_file_path" do
      setup_relay_and_client()
      setup_engine()

      assert_normal_scenario_works()
    end
  end

  describe "measure_to feature" do
    setup do
      setup_relay_and_client()
      setup_engine()
      :ok
    end

    test "receives measurements each operation via measure_to" do
      assert :ok == Giocci.register_client(@relay_name, measure_to: self())

      assert_receive {:giocci_measurements,
                      %{
                        client_send_timestamp_to_relay: _,
                        relay_recv_timestamp_from_client: _,
                        relay_send_timestamp_to_client: _,
                        client_recv_timestamp_from_relay: _,
                        client_to_relay: _,
                        relay_to_client: _
                      }}

      assert :ok == Giocci.save_module(@relay_name, GiocciIntegrationTest, measure_to: self())

      assert_receive {:giocci_measurements,
                      %{
                        client_send_timestamp_to_relay: _,
                        relay_recv_timestamp_from_client: _,
                        relay_send_timestamp_to_engine: _,
                        engine_recv_timestamp_from_relay: _,
                        engine_send_timestamp_to_relay: _,
                        relay_recv_timestamp_from_engine: _,
                        relay_send_timestamp_to_client: _,
                        client_recv_timestamp_from_relay: _,
                        client_to_relay: _,
                        relay_to_engine: _,
                        engine_to_relay: _,
                        relay_to_client: _
                      }}

      assert 3 ==
               Giocci.exec_func(
                 @relay_name,
                 {GiocciIntegrationTest, :add, [1, 2]},
                 measure_to: self()
               )

      assert_receive {:giocci_measurements,
                      %{
                        client_send_timestamp_to_relay: _,
                        relay_recv_timestamp_from_client: _,
                        relay_send_timestamp_to_client: _,
                        client_recv_timestamp_from_relay: _,
                        client_send_timestamp_to_engine: _,
                        engine_recv_timestamp_from_client: _,
                        engine_send_timestamp_to_client: _,
                        client_recv_timestamp_from_engine: _,
                        client_to_relay: _,
                        relay_to_client: _,
                        client_to_engine: _,
                        engine_to_client: _
                      }}

      :ok =
        Giocci.exec_func_async(@relay_name, {GiocciIntegrationTest, :add, [1, 2]}, self(),
          measure_to: self()
        )

      assert_receive {:giocci, 3},
                     @async_message_timeout,
                     "Expected async response with result 3"

      assert_receive {:giocci_measurements,
                      %{
                        client_send_timestamp_to_relay: _,
                        relay_recv_timestamp_from_client: _,
                        relay_send_timestamp_to_client: _,
                        client_recv_timestamp_from_relay: _,
                        client_to_relay: _,
                        relay_to_client: _
                      }}
    end
  end

  describe "inspection" do
    @describetag :inspect

    test "local information and relay inspection work without registration or engines" do
      setup_relay_and_client()

      assert {:ok,
              %{
                client_name: @client_name,
                key_prefix: "",
                zenoh_id: zenoh_id,
                router_ids: router_ids,
                peer_ids: peer_ids
              }} = Giocci.Inspect.connection_info()

      assert is_binary(zenoh_id)
      assert is_list(router_ids)
      assert is_list(peer_ids)
      assert {:ok, []} = Giocci.Inspect.list_relays()
      assert {:ok, []} = Giocci.Inspect.list_engines(@relay_name)
      assert {:ok, []} = Giocci.Inspect.list_modules(@relay_name)

      assert {:error, "module_not_found"} =
               Giocci.Inspect.list_functions(@relay_name, GiocciIntegrationTest)

      assert {:error, "module_not_found"} =
               Giocci.Inspect.module_info(@relay_name, GiocciIntegrationTest)

      assert {:ok, relay_info} = Giocci.Inspect.relay_info(@relay_name)
      assert relay_info.name == @relay_name
      assert relay_info.giocci_version == to_string(Application.spec(:giocci_relay, :vsn))
      assert relay_info.elixir_version == System.version()
      assert relay_info.otp_release == System.otp_release()
      assert is_binary(relay_info.system_architecture)
      assert is_integer(relay_info.uptime_ms) and relay_info.uptime_ms >= 0
      assert is_integer(relay_info.schedulers_online) and relay_info.schedulers_online > 0
      assert {:ok, %{rtt_ms: rtt}} = Giocci.Inspect.ping_relay(@relay_name)
      assert rtt >= 0
      assert {:ok, []} = Giocci.Inspect.list_relays()
    end

    test "registered engines are listed and queried directly without client registration" do
      setup_relay_and_client()
      setup_engine()

      assert {:ok, [@engine_name]} = Giocci.Inspect.list_engines(@relay_name)
      assert {:ok, engine_info} = Giocci.Inspect.engine_info(@engine_name)
      assert engine_info.name == @engine_name
      assert engine_info.giocci_version == to_string(Application.spec(:giocci_engine, :vsn))
      assert engine_info.elixir_version == System.version()
      assert engine_info.otp_release == System.otp_release()
      assert is_binary(engine_info.system_architecture)
      assert is_integer(engine_info.uptime_ms) and engine_info.uptime_ms >= 0
      assert is_integer(engine_info.schedulers_online) and engine_info.schedulers_online > 0
      assert {:ok, %{rtt_ms: rtt}} = Giocci.Inspect.ping_engine(@engine_name)
      assert rtt >= 0
      assert {:ok, []} = Giocci.Inspect.list_relays()

      cleanup_engine()
      assert {:ok, [@engine_name]} = Giocci.Inspect.list_engines(@relay_name)
      assert {:error, reason} = Giocci.Inspect.ping_engine(@engine_name, timeout: 250)

      assert String.starts_with?(reason, "connection_failed:") or
               String.starts_with?(reason, "timeout:")
    end

    test "multiple queryables on the same inspection key report an ambiguous reply" do
      setup_relay_and_client()
      key = "giocci/inspect/relay/#{@relay_name}"

      {:ok, queryable_id} =
        Zenohex.Session.declare_queryable(Giocci.SessionManager.session_id(), key)

      task = Task.async(fn -> Giocci.Inspect.list_engines(@relay_name, timeout: 1_000) end)
      assert_receive %Zenohex.Query{key_expr: ^key, zenoh_query: query}, 1_000

      {:ok, payload} = Giocci.Utils.encode({:ok, %{data: [], measurements: %{}}})
      assert :ok = Zenohex.Query.reply(query, key, payload)

      assert {:error, reason} = Task.await(task, 1_500)
      assert reason == "zenohex_error: expected one reply for '#{key}', got 2"
      assert :ok = Zenohex.Queryable.undeclare(queryable_id)
    end

    test "a key prefix containing inspect preserves ordinary registration and save results" do
      prefix = "tenant/inspect/demo"
      previous_client_prefix = Application.get_env(:giocci, :key_prefix)
      previous_relay_prefix = Application.get_env(:giocci_relay, :key_prefix)
      :ok = Application.put_env(:giocci, :key_prefix, prefix)
      :ok = Application.put_env(:giocci_relay, :key_prefix, prefix)

      on_exit(fn ->
        for {app, previous} <- [
              {:giocci, previous_client_prefix},
              {:giocci_relay, previous_relay_prefix}
            ] do
          if is_nil(previous) do
            Application.delete_env(app, :key_prefix)
          else
            Application.put_env(app, :key_prefix, previous)
          end
        end
      end)

      setup_relay_and_client()
      assert :ok = Giocci.register_client(@relay_name, measure_to: self())

      assert_receive {:giocci_measurements,
                      %{
                        client_send_timestamp_to_relay: _,
                        client_recv_timestamp_from_relay: _,
                        client_to_relay: _
                      }}

      assert :ok = Giocci.save_module(@relay_name, GiocciIntegrationTest)
      assert {:ok, [@relay_name]} = Giocci.Inspect.list_relays()

      assert {:ok, ["Elixir.GiocciIntegrationTest"]} =
               Giocci.Inspect.list_modules(@relay_name)
    end

    test "saved module information and functions reflect the relay's BEAM, not loaded code" do
      setup_relay_and_client()
      module = GiocciIntegrationTest.InspectedModule
      module_name = Atom.to_string(module)
      on_exit(fn -> :persistent_term.erase({Giocci.DynamicModule, module}) end)
      Code.compiler_options(ignore_module_conflict: true)

      [{^module, beam}] =
        Code.compile_string("""
        defmodule #{inspect(module)} do
          use Giocci.DynamicModule
          defstruct [:value]
          defmacro sample(expr), do: expr
          def __custom__, do: :ok
          def add(a, b \\\\ 1), do: a + b
        end
        """)

      assert :ok = Giocci.register_client(@relay_name)
      assert {:ok, [@relay_name]} = Giocci.Inspect.list_relays()
      assert :ok = Giocci.save_module(@relay_name, module)
      assert {:ok, [^module_name]} = Giocci.Inspect.list_modules(@relay_name)

      :code.purge(module)
      assert :code.delete(module)
      assert :code.is_loaded(module) == false

      assert {:ok, [{"__custom__", 0}, {"add", 1}, {"add", 2}]} =
               Giocci.Inspect.list_functions(@relay_name, module)

      assert :code.is_loaded(module) == false

      assert {:ok,
              %{
                module: ^module_name,
                beam_sha256: hash,
                beam_size_bytes: size,
                saved_at: %DateTime{time_zone: "Etc/UTC"} = saved_at
              }} = Giocci.Inspect.module_info(@relay_name, module)

      assert hash == Base.encode16(:crypto.hash(:sha256, beam), case: :lower)
      assert size == byte_size(beam)

      [{^module, _local_beam}] =
        Code.compile_string("""
        defmodule #{inspect(module)} do
          def add(a, b), do: a + b + 10
        end
        """)

      assert {:ok, [{"__custom__", 0}, {"add", 1}, {"add", 2}]} =
               Giocci.Inspect.list_functions(@relay_name, module_name)

      assert {:ok, %{beam_sha256: ^hash, saved_at: ^saved_at}} =
               Giocci.Inspect.module_info(@relay_name, module_name)

      [{^module, updated_beam}] =
        Code.compile_string("""
        defmodule #{inspect(module)} do
          use Giocci.DynamicModule
          def add(a, b), do: a + b + 1
        end
        """)

      assert :ok = Giocci.save_module(@relay_name, module)
      assert {:ok, [{"add", 2}]} = Giocci.Inspect.list_functions(@relay_name, module_name)

      assert {:ok, %{beam_sha256: updated_hash, saved_at: updated_at}} =
               Giocci.Inspect.module_info(@relay_name, module_name)

      assert updated_hash == Base.encode16(:crypto.hash(:sha256, updated_beam), case: :lower)
      assert updated_hash != hash
      assert DateTime.compare(updated_at, saved_at) == :gt
    end

    test "relay restart leaves client history but exposes missing registration" do
      setup_relay_and_client()
      assert :ok = Giocci.register_client(@relay_name)
      assert {:ok, [@relay_name]} = Giocci.Inspect.list_relays()

      assert :ok = Application.stop(:giocci_relay)

      assert {:error, [%{relay: @relay_name, reason: reason}]} =
               Giocci.Inspect.list_relays(timeout: 250)

      assert String.starts_with?(reason, "connection_failed:") or
               String.starts_with?(reason, "timeout:")

      assert {:error, relay_error} = Giocci.Inspect.list_engines(@relay_name, timeout: 250)

      assert String.starts_with?(relay_error, "connection_failed:") or
               String.starts_with?(relay_error, "timeout:")

      {:ok, _} = Application.ensure_all_started(:giocci_relay)

      assert {:error, [%{relay: @relay_name, reason: "client_not_registered"}]} =
               Giocci.Inspect.list_relays()

      assert {:error, "client_not_registered"} =
               Giocci.save_module(@relay_name, GiocciIntegrationTest)

      assert :ok = Giocci.register_client(@relay_name)
      assert {:ok, [@relay_name]} = Giocci.Inspect.list_relays()
    end

    test "invalid stored BEAM is reported without changing stored state" do
      setup_relay_and_client()
      module_name = Atom.to_string(GiocciIntegrationTest)

      assert :ok =
               GiocciRelay.ModuleStore.put(
                 @client_name,
                 {GiocciIntegrationTest, <<1>>, ~c"invalid.beam"}
               )

      assert {:ok, [^module_name]} = Giocci.Inspect.list_modules(@relay_name)

      assert {:error, "invalid_beam"} =
               Giocci.Inspect.list_functions(@relay_name, module_name)

      assert {:error, "invalid_beam"} =
               Giocci.Inspect.module_info(@relay_name, module_name)

      assert {:ok, [^module_name]} = Giocci.Inspect.list_modules(@relay_name)
    end

    test "module queries use only this client's saved module namespace" do
      setup_relay_and_client()

      assert :ok =
               GiocciRelay.ModuleStore.put(
                 "another-client",
                 :code.get_object_code(GiocciIntegrationTest)
               )

      assert {:ok, []} = Giocci.Inspect.list_modules(@relay_name)

      assert {:error, "module_not_found"} =
               Giocci.Inspect.list_functions(@relay_name, GiocciIntegrationTest)

      assert :ok = Giocci.register_client(@relay_name)
      assert :ok = Giocci.save_module(@relay_name, GiocciIntegrationTest)

      assert {:ok, ["Elixir.GiocciIntegrationTest"]} =
               Giocci.Inspect.list_modules(@relay_name)

      assert {:ok, [{"add", 2}]} =
               Giocci.Inspect.list_functions(@relay_name, "Elixir.GiocciIntegrationTest")
    end
  end
end
