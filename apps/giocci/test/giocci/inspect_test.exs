defmodule Giocci.InspectTest do
  use ExUnit.Case
  import Mock

  setup do
    start_supervised!({Giocci.Worker, [client_name: "client", key_prefix: "scope"]})
    :ok
  end

  test "list_relays returns no candidates without contacting the relay" do
    with_mock Giocci.Utils,
      zenohex_get: fn _, _, _, _ -> flunk("unexpected remote query") end do
      assert {:ok, []} = Giocci.Inspect.list_relays()
    end
  end

  test "list_relays sorts confirmed relays and reports registration mismatches and timeouts" do
    :sys.replace_state(Giocci.Worker, fn state ->
      %{state | registered_relays: ["relay-c", "relay-a", "relay-b", "relay-a"]}
    end)

    test_pid = self()

    with_mocks([
      {Giocci.SessionManager, [], [session_id: fn -> :dummy_session_id end]},
      {Giocci.Utils, [],
       [
         zenohex_get: fn _, key, timeout, %{data: %{client_name: "client"}} ->
           send(test_pid, {:queried, key, timeout})

           case Path.basename(key) do
             "relay-a" -> {:ok, {:ok, %{data: true, measurements: %{}}}}
             "relay-b" -> {:ok, {:ok, %{data: false, measurements: %{}}}}
             "relay-c" -> {:error, "timeout: relay-c timed out after 70ms"}
           end
         end
       ]}
    ]) do
      assert {:warn, ["relay-a"],
              [
                %{relay: "relay-b", reason: "client_not_registered"},
                %{relay: "relay-c", reason: "timeout: relay-c timed out after 70ms"}
              ]} = Giocci.Inspect.list_relays(timeout: 70)

      for relay <- ~w(relay-a relay-b relay-c) do
        assert_receive {:queried, "scope/giocci/inspect/relay/" <> ^relay, 70}
      end
    end
  end

  test "list_relays returns all reasons when no registration can be confirmed" do
    :sys.replace_state(Giocci.Worker, fn state ->
      %{state | registered_relays: ["relay-b", "relay-a"]}
    end)

    with_mocks([
      {Giocci.SessionManager, [], [session_id: fn -> :dummy_session_id end]},
      {Giocci.Utils, [],
       [
         zenohex_get: fn _, key, _, _ ->
           if String.ends_with?(key, "relay-a") do
             {:ok, {:ok, %{data: false, measurements: %{}}}}
           else
             {:error, "connection_failed: relay-b"}
           end
         end
       ]}
    ]) do
      assert {:error,
              [
                %{relay: "relay-a", reason: "client_not_registered"},
                %{relay: "relay-b", reason: "connection_failed: relay-b"}
              ]} = Giocci.Inspect.list_relays()
    end
  end

  test "inspection addresses engines directly without registering the client" do
    test_pid = self()

    with_mocks([
      {Giocci.SessionManager, [], [session_id: fn -> :dummy_session_id end]},
      {Giocci.Utils, [],
       [
         zenohex_get: fn _, key, _, %{data: %{operation: operation}} ->
           send(test_pid, {key, operation})
           {:ok, {:ok, %{data: :pong, measurements: %{}}}}
         end
       ]}
    ]) do
      assert {:ok, %{rtt_ms: rtt_ms}} = Giocci.Inspect.ping_engine("engine")
      assert rtt_ms >= 0
      assert_receive {"scope/giocci/inspect/engine/engine", :ping}
    end
  end
end
