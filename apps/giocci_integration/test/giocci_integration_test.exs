defmodule GiocciIntegrationTest do
  use ExUnit.Case

  setup do
    :ok = Application.put_env(:giocci_client, :client_name, "giocci_client")
    {:ok, _} = Application.ensure_all_started(:giocci_client)

    on_exit(fn ->
      :ok = Application.delete_env(:giocci_client, :client_name)
      :ok = Application.stop(:giocci_client)
    end)

    :ok
  end

  test "" do
    assert {:error, _} = GiocciClient.register_client("non-existent relay")
  end
end
