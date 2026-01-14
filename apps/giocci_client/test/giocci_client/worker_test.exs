defmodule GiocciClient.WorkerTest do
  use ExUnit.Case
  import Mock

  setup_with_mocks([
    {GiocciClient.SessionManager, [], [session_id: fn -> :dummy_session_id end]}
  ]) do
    :ok
  end

  setup do
    pid = start_supervised!({GiocciClient.Worker, [client_name: "giocci_client"]})

    %{worker_pid: pid}
  end

  test "register_client/3" do
    assert {:error, "zenohex_error: badarg"} =
             GiocciClient.Worker.register_client("missing-relay")
  end

  test "save_module/3 returns error for unregistered relay" do
    assert {:error, "relay_not_registered"} =
             GiocciClient.Worker.save_module("missing-relay", GiocciClient.Worker)
  end

  test "exec_func/3 returns error for unregistered relay" do
    assert {:error, "relay_not_registered"} =
             GiocciClient.Worker.exec_func(
               "missing-relay",
               {GiocciClient.Worker, :start_link, [[]]}
             )
  end

  test "save_module/3 returns error for missing module", %{worker_pid: pid} do
    :sys.replace_state(pid, fn state ->
      %{state | registered_relays: ["relay-1"]}
    end)

    missing_module = Module.concat(["GiocciClient", "MissingModule"])

    assert {:error, "module_not_found"} =
             GiocciClient.Worker.save_module("relay-1", missing_module)
  end
end
