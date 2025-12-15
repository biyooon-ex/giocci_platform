defmodule GiocciIntegrationTest do
  use ExUnit.Case

  @relay_name "giocci_relay"

  setup do
    :ok = Application.put_env(:giocci_relay, :relay_name, @relay_name)
    {:ok, _} = Application.ensure_all_started(:giocci_relay)

    :ok = Application.put_env(:giocci_client, :client_name, "giocci_client")
    {:ok, _} = Application.ensure_all_started(:giocci_client)

    on_exit(fn ->
      :ok = Application.delete_env(:giocci_relay, :relay_name)
      :ok = Application.stop(:giocci_relay)

      :ok = Application.delete_env(:giocci_client, :client_name)
      :ok = Application.stop(:giocci_client)
    end)

    :ok
  end

  test "" do
    assert :ok = GiocciClient.register_client(@relay_name)
  end
end
