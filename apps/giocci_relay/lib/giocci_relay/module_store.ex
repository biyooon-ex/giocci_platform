defmodule GiocciRelay.ModuleStore do
  use GenServer

  @spec put({module(), binary(), :file.filename()}) :: :ok
  def put(module_object_code) do
    GenServer.call(__MODULE__, {:put, module_object_code})
  end

  @spec get() :: {:ok, list({module(), binary(), :file.filename()})}
  def get() do
    GenServer.call(__MODULE__, :get)
  end

  def start_link(args) do
    name = Keyword.get(args, :name, __MODULE__)
    GenServer.start_link(__MODULE__, args, name: name)
  end

  def init(_args) do
    {:ok, %{module_object_codes: []}}
  end

  def handle_call({:put, module_object_code}, _from, state) do
    state = %{state | module_object_codes: [module_object_code | state.module_object_codes]}
    {:reply, :ok, state}
  end

  def handle_call(:get, _from, state) do
    {:reply, {:ok, state.module_object_codes}, state}
  end
end
