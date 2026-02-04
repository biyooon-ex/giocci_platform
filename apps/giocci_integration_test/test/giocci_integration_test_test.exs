defmodule GiocciIntegrationTestTest do
  use ExUnit.Case

  @moduletag capture_log: true

  @relay_name "giocci_relay"
  @engine_name "giocci_engine"
  @client_name "giocci"

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

  describe "happy path" do
    setup do
      setup_relay_and_client()
      setup_engine()
      :ok
    end

    test "normal scenario" do
      assert :ok == Giocci.register_client(@relay_name)
      assert :ok == Giocci.save_module(@relay_name, GiocciIntegrationTest)
      assert 3 == Giocci.exec_func(@relay_name, {GiocciIntegrationTest, :add, [1, 2]})

      assert {:error, "function_not_defined: {GiocciIntegrationTest, :undefined_function, []}"} ==
               Giocci.exec_func(
                 @relay_name,
                 {GiocciIntegrationTest, :undefined_function, []}
               )

      :ok =
        Giocci.exec_func_async(@relay_name, {GiocciIntegrationTest, :add, [1, 2]}, self())

      assert_receive {:giocci, 3},
                     @async_message_timeout,
                     "Expected async response with result 3"
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
end
