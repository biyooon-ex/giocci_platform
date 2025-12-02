defmodule GiocciClient.Worker do
  use GenServer

  @worker_name __MODULE__

  # API

  def register_client(relay_name, opts \\ []) do
    GenServer.call(@worker_name, {:register_client, relay_name, opts})
  end

  def save_module(relay_name, module, opts \\ []) do
    GenServer.call(@worker_name, {:save_module, relay_name, module, opts})
  end

  def exec_func(relay_name, mfargs, opts \\ []) do
    GenServer.call(@worker_name, {:exec_func, relay_name, mfargs, opts})
  end

  def exec_func_async(relay_name, mfargs, opts \\ []) do
    GenServer.call(@worker_name, {:exec_func, relay_name, mfargs, opts})
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: @worker_name)
  end

  # callbacks

  def init(args) do
    {:ok, %{}}
  end

  def handle_call({:register_client, relay_name, opts}, _from, state) do
    {:reply, :ok, state}
  end

  def handle_call({:save_module, relay_name, module, opts}, _from, state) do
    {:reply, :ok, state}
  end

  def handle_call({:exec_func, relay_name, mfargs, opts}, _from, state) do
    {:reply, :ok, state}
  end

  def handle_call({:exec_func_async, relay_name, mfargs, opts}, _from, state) do
    {:reply, :ok, state}
  end
end
