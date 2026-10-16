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

  def list(client_name) do
    GenServer.call(__MODULE__, {:list, client_name})
  end

  def fetch(client_name, module) do
    GenServer.call(__MODULE__, {:fetch, client_name, module})
  end

  def start_link(args) do
    name = Keyword.get(args, :name, __MODULE__)
    GenServer.start_link(__MODULE__, args, name: name)
  end

  def init(_args) do
    {:ok, %{modules: %{}, saved_at: %{}}}
  end

  def handle_call({:put, client_name, module_object_code}, _from, state) do
    {new_module, _, _} = module_object_code

    values =
      Map.get(state.modules, client_name, [])
      |> Enum.reject(fn {old_module, _, _} -> old_module == new_module end)

    state = %{
      state
      | modules: Map.put(state.modules, client_name, [module_object_code | values]),
        saved_at: Map.put(state.saved_at, {client_name, new_module}, DateTime.utc_now())
    }

    {:reply, :ok, state}
  end

  def handle_call(:get, _from, state) do
    {:reply, {:ok, state.modules}, state}
  end

  def handle_call({:list, client_name}, _from, state) do
    modules =
      state.modules
      |> Map.get(client_name, [])
      |> Enum.map(fn {module, _, _} -> module end)
      |> Enum.uniq()
      |> Enum.sort()

    {:reply, {:ok, modules}, state}
  end

  def handle_call({:fetch, client_name, module}, _from, state) do
    result =
      case Enum.find(Map.get(state.modules, client_name, []), fn {name, _, _} ->
             name == module
           end) do
        nil ->
          {:error, "module_not_found"}

        object_code ->
          {:ok, {object_code, Map.fetch!(state.saved_at, {client_name, module})}}
      end

    {:reply, result, state}
  end
end
