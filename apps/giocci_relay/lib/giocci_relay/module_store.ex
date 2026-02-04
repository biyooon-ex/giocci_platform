defmodule GiocciRelay.ModuleStore do
  @moduledoc false

  use GenServer

  @type module_object_code() :: {module(), binary(), :file.filename()}

  @spec put(String.t(), module_object_code()) :: :ok
  def put(client_name, module_object_code) do
    GenServer.call(__MODULE__, {:put, client_name, module_object_code})
  end

  @spec get() :: {:ok, %{} | %{String.t() => [module_object_code()]}}
  def get() do
    GenServer.call(__MODULE__, :get)
  end

  def start_link(args) do
    name = Keyword.get(args, :name, __MODULE__)
    GenServer.start_link(__MODULE__, args, name: name)
  end

  def init(_args) do
    {:ok, %{}}
  end

  def handle_call({:put, client_name, module_object_code}, _from, state) do
    {new_module, _, _} = module_object_code

    values =
      Map.get(state, client_name, [])
      |> Enum.reject(fn {old_module, _, _} -> old_module == new_module end)

    state = Map.put(state, client_name, [module_object_code | values])

    {:reply, :ok, state}
  end

  def handle_call(:get, _from, state) do
    {:reply, {:ok, state}, state}
  end
end
