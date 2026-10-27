defmodule GiocciRelay.EngineSelectionPolicy.RoundRobin do
  @moduledoc false

  @behaviour GiocciRelay.EngineSelectionPolicy

  @impl true
  def init([]), do: {:ok, 0}
  def init(opts), do: {:error, {:unexpected_round_robin_options, opts}}

  @impl true
  def candidates_changed(old, new, next_index) do
    if new == [] do
      0
    else
      removed_before_next =
        old
        |> Enum.take(next_index)
        |> Enum.count(&(&1 not in new))

      next_index - removed_before_next
    end
  end

  @impl true
  def select(candidates, _request, next_index) do
    index = rem(next_index, length(candidates))
    {:ok, Enum.at(candidates, index), index + 1}
  end
end
