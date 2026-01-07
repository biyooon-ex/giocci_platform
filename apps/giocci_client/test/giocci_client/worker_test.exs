defmodule GiocciClient.WorkerTest do
  use ExUnit.Case

  setup do
    _pid = start_supervised!({GiocciClient.SessionManager, []})
    _pid = start_supervised!({GiocciClient.Worker, [client_name: "giocci_client"]})

    :ok
  end

  test "register_client/3" do
    assert {:error, _} = GiocciClient.Worker.register_client("non-existent relay")
  end
end
