defmodule Giocci.WorkerTest do
  use ExUnit.Case
  import Mock

  setup_with_mocks([
    {Giocci.SessionManager, [], [session_id: fn -> :dummy_session_id end]}
  ]) do
    :ok
  end

  setup do
    pid = start_supervised!({Giocci.Worker, [client_name: "giocci"]})

    %{worker_pid: pid}
  end

  test "register_client/3" do
    assert {:error, "zenohex_error: badarg"} =
             Giocci.Worker.register_client("missing-relay")
  end

  test "save_module/3 returns error for unregistered relay" do
    assert {:error, "relay_not_registered"} =
             Giocci.Worker.save_module("missing-relay", Giocci.Worker)
  end

  test "exec_func/3 returns error for unregistered relay" do
    assert {:error, "relay_not_registered"} =
             Giocci.Worker.exec_func(
               "missing-relay",
               {Giocci.Worker, :start_link, [[]]}
             )
  end

  test "save_module/3 returns error for missing module", %{worker_pid: pid} do
    :sys.replace_state(pid, fn state ->
      %{state | registered_relays: ["relay-1"]}
    end)

    missing_module = Module.concat(["Giocci", "MissingModule"])

    assert {:error, "module_not_found"} =
             Giocci.Worker.save_module("relay-1", missing_module)
  end
end
