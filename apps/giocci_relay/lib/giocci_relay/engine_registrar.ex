defmodule GiocciRelay.EngineRegistrar do
  @moduledoc false

  use GenServer

  require Logger

  alias GiocciRelay.Utils

  @name __MODULE__

  def registered_engines() do
    GenServer.call(@name, :registered_engines)
  end

  def select_engine() do
    GenServer.call(@name, :select_engine)
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: @name)
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
       register_engine_key: register_engine_key,
       register_engine_queryable_id: register_engine_queryable_id,
       registered_engines: []
     }}
  end

  def handle_info(
        %Zenohex.Query{key_expr: register_engine_key, payload: binary, zenoh_query: zenoh_query},
        %{register_engine_key: register_engine_key} = state
      ) do
    relay_recv_timestamp_from_engine = System.system_time(:millisecond)
    relay_name = state.relay_name
    key_prefix = state.key_prefix
    registered_engines = state.registered_engines

    session_id = GiocciRelay.SessionManager.session_id()
    timeout = 5000

    {result, state} =
      with {:ok, term_from_engine} <- Utils.decode(binary),
           {:ok, engine_name} <- extract(term_from_engine.data),
           key <- Path.join(key_prefix, "giocci/save_module/relay/#{engine_name}"),
           {:ok, client_modules_map} <- GiocciRelay.ModuleStore.get(),
           term_to_engine <- %{
             data: %{relay_name: relay_name, client_modules_map: client_modules_map},
             measurements: term_from_engine.measurements
           },
           {:ok, term_from_engine} <- Utils.zenohex_get(session_id, key, timeout, term_to_engine),
           {:ok, %{data: _data, measurements: measurements}} <- term_from_engine do
        Logger.debug("#{inspect(engine_name)} registration completed successfully.")
        registered_engines = [engine_name | registered_engines] |> Enum.uniq()
        state = %{state | registered_engines: registered_engines}

        term_to_engine = %{
          data: nil,
          measurements: measurements
        }

        {{:ok, term_to_engine}, state}
      else
        error ->
          Logger.error("Engine registration failed by #{inspect(error)}.")
          {error, state}
      end

    result = maybe_add_measurements(result, relay_recv_timestamp_from_engine)
    :ok = Utils.zenohex_reply(zenoh_query, register_engine_key, result)

    {:noreply, state}
  end

  def handle_call(:registered_engines, _from, state) do
    {:reply, state.registered_engines, state}
  end

  def handle_call(:select_engine, _from, state) do
    registered_engines = state.registered_engines

    result =
      if Enum.empty?(registered_engines) do
        {:error, "engine_not_registered"}
      else
        # IMPREMENT ME, select engine logic
        {:ok, List.first(registered_engines)}
      end

    {:reply, result, state}
  end

  defp extract(term) do
    %{
      engine_name: engine_name
    } = term

    {:ok, engine_name}
  rescue
    MatchError -> {:error, "term_not_expected"}
  end

  defp maybe_add_measurements(result, relay_recv_timestamp_from_engine) do
    case result do
      {:ok, %{data: data, measurements: measurements}} ->
        measurements =
          Map.merge(measurements, %{
            relay_recv_timestamp_from_engine: relay_recv_timestamp_from_engine,
            relay_send_timestamp_to_engine: System.system_time(:millisecond)
          })

        {:ok, %{data: data, measurements: measurements}}

      result ->
        result
    end
  end
end
