defmodule GiocciIntegrationTest do
  use ExUnit.Case

  @moduletag capture_log: true

  @relay_name "giocci_relay"

  describe "happy path" do
    setup do
      :ok = Application.put_env(:giocci_relay, :relay_name, @relay_name)
      {:ok, _} = Application.ensure_all_started(:giocci_relay)

      :ok = Application.put_env(:giocci_engine, :engine_name, "giocci_engine")
      :ok = Application.put_env(:giocci_engine, :relay_name, @relay_name)
      {:ok, _} = Application.ensure_all_started(:giocci_engine)

      :ok = Application.put_env(:giocci_client, :client_name, "giocci_client")
      {:ok, _} = Application.ensure_all_started(:giocci_client)

      on_exit(fn ->
        :ok = Application.delete_env(:giocci_relay, :relay_name)
        :ok = Application.stop(:giocci_relay)

        :ok = Application.delete_env(:giocci_engine, :engine_name)
        :ok = Application.stop(:giocci_engine)

        :ok = Application.delete_env(:giocci_client, :client_name)
        :ok = Application.stop(:giocci_client)
      end)

      :ok
    end

    test "normal scenario" do
      assert :ok = GiocciClient.register_client(@relay_name)
      assert :ok = GiocciClient.save_module(@relay_name, GiocciIntegration)
      assert 3 = GiocciClient.exec_func(@relay_name, {GiocciIntegration, :add, [1, 2]})

      assert {:error, "{GiocciIntegration, :undefined_function, []} not defined"} =
               GiocciClient.exec_func(@relay_name, {GiocciIntegration, :undefined_function, []})

      :ok = GiocciClient.exec_func_async(@relay_name, {GiocciIntegration, :add, [1, 2]}, self())

      assert_receive {:giocci_client, 3}
    end
  end

  describe "engine start timing," do
    setup do
      :ok = Application.put_env(:giocci_relay, :relay_name, @relay_name)
      {:ok, _} = Application.ensure_all_started(:giocci_relay)

      :ok = Application.put_env(:giocci_engine, :engine_name, "giocci_engine")
      :ok = Application.put_env(:giocci_engine, :relay_name, @relay_name)

      :ok = Application.put_env(:giocci_client, :client_name, "giocci_client")
      {:ok, _} = Application.ensure_all_started(:giocci_client)

      on_exit(fn ->
        :ok = Application.delete_env(:giocci_relay, :relay_name)
        :ok = Application.stop(:giocci_relay)

        :ok = Application.delete_env(:giocci_engine, :engine_name)
        :ok = Application.stop(:giocci_engine)

        :ok = Application.delete_env(:giocci_client, :client_name)
        :ok = Application.stop(:giocci_client)
      end)

      :ok
    end

    test "engine starts before GiocciClient.save_module/2" do
      assert :ok = GiocciClient.register_client(@relay_name)
      {:ok, _} = Application.ensure_all_started(:giocci_engine)
      assert :ok = GiocciClient.save_module(@relay_name, GiocciIntegration)

      assert 3 = GiocciClient.exec_func(@relay_name, {GiocciIntegration, :add, [1, 2]})
    end

    test "engine starts after GiocciClient.save_module/2" do
      assert :ok = GiocciClient.register_client(@relay_name)
      assert :ok = GiocciClient.save_module(@relay_name, GiocciIntegration)
      {:ok, _} = Application.ensure_all_started(:giocci_engine)

      assert 3 = GiocciClient.exec_func(@relay_name, {GiocciIntegration, :add, [1, 2]})
    end
  end
end
