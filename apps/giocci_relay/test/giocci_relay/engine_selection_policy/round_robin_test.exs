defmodule GiocciRelay.EngineSelectionPolicy.RoundRobinTest do
  use ExUnit.Case

  alias GiocciRelay.EngineSelectionPolicy.RoundRobin

  test "selects Engines in registration order and repeats after a full cycle" do
    assert {:ok, state} = RoundRobin.init([])
    state = RoundRobin.candidates_changed([], ["A", "B", "C"], state)

    {selected, _state} =
      Enum.map_reduce(1..7, state, fn _, state ->
        {:ok, engine, state} = RoundRobin.select(["A", "B", "C"], %{}, state)
        {engine, state}
      end)

    assert selected == ["A", "B", "C", "A", "B", "C", "A"]
  end

  test "an added Engine joins the rotation without resetting it" do
    {:ok, state} = RoundRobin.init([])
    {:ok, "A", state} = RoundRobin.select(["A", "B"], %{}, state)
    state = RoundRobin.candidates_changed(["A", "B"], ["A", "B", "C"], state)

    assert {:ok, "B", state} = RoundRobin.select(["A", "B", "C"], %{}, state)
    assert {:ok, "C", state} = RoundRobin.select(["A", "B", "C"], %{}, state)
    assert {:ok, "A", _state} = RoundRobin.select(["A", "B", "C"], %{}, state)
  end

  test "a new Engine follows the sole previously selected Engine" do
    {:ok, state} = RoundRobin.init([])
    {:ok, "A", state} = RoundRobin.select(["A"], %{}, state)
    state = RoundRobin.candidates_changed(["A"], ["A", "B"], state)
    assert {:ok, "B", _state} = RoundRobin.select(["A", "B"], %{}, state)
  end

  test "re-registration leaves the next selection unchanged" do
    {:ok, state} = RoundRobin.init([])
    {:ok, "A", state} = RoundRobin.select(["A", "B"], %{}, state)
    state = RoundRobin.candidates_changed(["A", "B"], ["A", "B"], state)
    assert {:ok, "B", _state} = RoundRobin.select(["A", "B"], %{}, state)
  end

  test "removing the next Engine selects its successor and removing all resets the state" do
    {:ok, state} = RoundRobin.init([])
    {:ok, "A", state} = RoundRobin.select(["A", "B", "C"], %{}, state)
    state = RoundRobin.candidates_changed(["A", "B", "C"], ["A", "C"], state)
    assert {:ok, "C", state} = RoundRobin.select(["A", "C"], %{}, state)

    state = RoundRobin.candidates_changed(["A", "C"], [], state)
    assert state == 0
    assert {:ok, "D", _state} = RoundRobin.select(["D"], %{}, state)
  end

  test "rejects unsupported options" do
    assert {:error, {:unexpected_round_robin_options, [unknown: true]}} =
             RoundRobin.init(unknown: true)
  end
end
