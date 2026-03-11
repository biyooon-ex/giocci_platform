defmodule Giocci.ExecFuncAsyncStore do
  @moduledoc false

  use GenServer

  @name __MODULE__
  @polling_interval 1000

  # API

  @spec get(reference()) :: {:ok, map()} | {:error, String.t()}
  def get(key) do
    GenServer.call(@name, {:get, key})
  end

  @spec put(reference(), map()) :: :ok
  def put(key, value) do
    GenServer.call(@name, {:put, key, value})
  end

  @spec delete(reference()) :: :ok
  def delete(key) do
    GenServer.call(@name, {:delete, key})
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: @name)
  end

  # callbacks

  def init(_args) do
    Process.send_after(self(), :polling, @polling_interval)
    {:ok, %{}}
  end

  def handle_info(:polling, state) do
    Process.send_after(self(), :polling, @polling_interval)
    {:noreply, state, {:continue, :check_timeout}}
  end

  def handle_continue(:check_timeout, state) do
    state =
      Enum.reduce(state, %{}, fn {exec_id, map}, acc ->
        if is_integer(map.timeout) and
             map.put_time + map.timeout < System.monotonic_time(:millisecond) do
          :ok = Zenohex.Subscriber.undeclare(map.subscriber_id)
          acc
        else
          Map.put(acc, exec_id, map)
        end
      end)

    {:noreply, state}
  end

  def handle_call({:get, key}, _from, state) do
    value = Map.get(state, key)

    if is_nil(value) do
      {:reply, {:error, "not_found"}, state}
    else
      {:reply, {:ok, value}, state}
    end
  end

  def handle_call({:put, key, value}, _from, state) do
    {:reply, :ok, Map.put(state, key, value)}
  end

  def handle_call({:delete, key}, _from, state) do
    {:reply, :ok, Map.delete(state, key)}
  end
end
