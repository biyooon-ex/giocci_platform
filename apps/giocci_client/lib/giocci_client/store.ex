defmodule GiocciClient.Store do
  @moduledoc false

  use Agent

  @agent_name __MODULE__

  def get(key, default \\ nil) do
    Agent.get(@agent_name, fn state -> Map.get(state, key, default) end)
  end

  def put(key, value) do
    Agent.update(@agent_name, fn state -> Map.put(state, key, value) end)
  end

  def delete(key) do
    Agent.update(@agent_name, fn state -> Map.delete(state, key) end)
  end

  def start_link(_args) do
    Agent.start_link(fn -> %{} end, name: @agent_name)
  end
end
