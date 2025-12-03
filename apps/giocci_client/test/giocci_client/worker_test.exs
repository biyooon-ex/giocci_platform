defmodule GiocciClient.WorkerTest do
  use ExUnit.Case

  setup do
    _pid = start_supervised!({GiocciClient.Worker, [client_name: "giocci_client"]})

    on_exit(fn ->
      :ok = Application.delete_env(:giocci_client, :client_name)
    end)

    :ok
  end

  test "register_client/3" do
    assert {:error, _} = GiocciClient.Worker.register_client("non-existent relay")
  end
end
