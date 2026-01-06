defmodule GiocciRelay.EngineRegistrar do
  use GenServer

  require Logger

  alias GiocciRelay.Utils

  @worker_name __MODULE__

  def registered_engines() do
    GenServer.call(@worker_name, :registered_engines)
  end

  def select_engine() do
    GenServer.call(@worker_name, :select_engine)
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: @worker_name)
  end

  def init(args) do
    relay_name = Keyword.fetch!(args, :relay_name)
    key_prefix = Keyword.get(args, :key_prefix, "")

    session_id = GiocciRelay.SessionManager.session_id()

    register_engine_key = Path.join(key_prefix, "giocci/register/engine/#{relay_name}")

    {:ok, register_engine_queryable_id} =
      Zenohex.Session.declare_queryable(session_id, register_engine_key)

    {:ok,
     %{
       relay_name: relay_name,
       key_prefix: key_prefix,
       session_id: session_id,
       register_engine_key: register_engine_key,
       register_engine_queryable_id: register_engine_queryable_id,
       registered_engines: []
     }}
  end

  def handle_info(
        %Zenohex.Query{key_expr: register_engine_key, payload: binary, zenoh_query: zenoh_query},
        %{register_engine_key: register_engine_key} = state
      ) do
    relay_name = state.relay_name
    key_prefix = state.key_prefix
    session_id = state.session_id
    registered_engines = state.registered_engines

    {result, state} =
      with {:ok, %{engine_name: engine_name}} <- Utils.decode(binary),
           key <- Path.join(key_prefix, "giocci/save_module/relay/#{engine_name}"),
           {:ok, client_modules_map} <- GiocciRelay.ModuleStore.get(),
           {:ok, binary} <-
             Utils.encode(%{relay_name: relay_name, client_modules_map: client_modules_map}),
           {:ok, binary} <- Utils.zenohex_get(session_id, key, _timeout = 5000, binary),
           {:ok, recv_term} <- Utils.decode(binary),
           :ok <- recv_term do
        Logger.debug("#{inspect(engine_name)} registration completed successfully.")
        registered_engines = [engine_name | registered_engines] |> Enum.uniq()
        state = %{state | registered_engines: registered_engines}
        {:ok, state}
      else
        error ->
          Logger.error("Engine registration failed by #{inspect(error)}.")
          {error, state}
      end

    {:ok, binary} = Utils.encode(result)
    :ok = Zenohex.Query.reply(zenoh_query, register_engine_key, binary)

    {:noreply, state}
  end

  def handle_call(:registered_engines, _from, state) do
    {:reply, state.registered_engines, state}
  end

  def handle_call(:select_engine, _from, state) do
    registered_engines = state.registered_engines

    result =
      if Enum.empty?(registered_engines) do
        {:error, :engine_not_registered}
      else
        # IMPREMENT ME, select engine logic
        {:ok, List.first(registered_engines)}
      end

    {:reply, result, state}
  end
end
