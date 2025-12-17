defmodule GiocciIntegrationTest do
  use ExUnit.Case

  @relay_name "giocci_relay"

  setup do
    :ok = Application.put_env(:giocci_relay, :relay_name, @relay_name)
    {:ok, _} = Application.ensure_all_started(:giocci_relay)

    :ok = Application.put_env(:giocci_engine, :engine_name, "giocci_engine")
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

  test "" do
    assert :ok = GiocciEngine.register_engine(@relay_name)
    assert :ok = GiocciClient.register_client(@relay_name)
    assert :ok = GiocciClient.save_module(@relay_name, GiocciIntegration)
    assert 3 = GiocciClient.exec_func(@relay_name, {GiocciIntegration, :add, [1, 2]})

    assert {:error, _} =
             GiocciClient.exec_func(@relay_name, {GiocciIntegration, :undefined_function, []})

    :ok = GiocciClient.exec_func_async(@relay_name, {GiocciIntegration, :add, [1, 2]}, self())

    assert_receive {:giocci_client, 3}
  end
end
