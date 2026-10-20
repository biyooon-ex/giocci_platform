defmodule GiocciRelay.EngineRegistrar do
  @moduledoc false

  use GenServer

  require Logger

  alias GiocciRelay.Utils

  @name __MODULE__

  def registered_engines() do
    GenServer.call(@name, :registered_engines)
  end

  def select_engine(request) do
    GenServer.call(@name, {:select_engine, request})
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: @name)
  end

  def init(args) do
    relay_name = Keyword.fetch!(args, :relay_name)
    key_prefix = Keyword.get(args, :key_prefix, "")

    policy =
      Keyword.get(args, :engine_selection_policy, GiocciRelay.EngineSelectionPolicy.RoundRobin)

    policy_opts = Keyword.get(args, :engine_selection_policy_opts, [])

    unless is_atom(policy) and Code.ensure_loaded?(policy) and
             Enum.all?([init: 1, candidates_changed: 3, select: 3], fn {name, arity} ->
               function_exported?(policy, name, arity)
             end) do
      raise ArgumentError, "invalid engine selection policy: #{inspect(policy)}"
    end

    policy_state =
      case policy.init(policy_opts) do
        {:ok, policy_state} ->
          policy_state

        {:error, reason} ->
          raise ArgumentError, "invalid engine selection policy options: #{inspect(reason)}"
      end

    session_id = GiocciRelay.SessionManager.session_id()

    register_engine_key = Path.join(key_prefix, "giocci/register/engine/#{relay_name}")

    {:ok, register_engine_queryable_id} =
      Zenohex.Session.declare_queryable(session_id, register_engine_key)

    unregister_engine_key = Path.join(key_prefix, "giocci/unregister/engine/#{relay_name}")

    {:ok, unregister_engine_queryable_id} =
      Zenohex.Session.declare_queryable(session_id, unregister_engine_key)

    {:ok,
     %{
       relay_name: relay_name,
       key_prefix: key_prefix,
       register_engine_key: register_engine_key,
       register_engine_queryable_id: register_engine_queryable_id,
       unregister_engine_key: unregister_engine_key,
       unregister_engine_queryable_id: unregister_engine_queryable_id,
       registered_engines: [],
       engine_selection_policy: policy,
       engine_selection_policy_state: policy_state
     }}
  end

  def handle_info(
        %Zenohex.Query{
          key_expr: unregister_engine_key,
          payload: binary,
          zenoh_query: zenoh_query
        },
        %{unregister_engine_key: unregister_engine_key} = state
      ) do
    {result, state} =
      with {:ok, term_from_engine} <- Utils.decode(binary),
           {:ok, {engine_name, measurements}} <- extract_unregister(term_from_engine) do
        Logger.debug("#{inspect(engine_name)} unregistered.")

        {{:ok, %{data: nil, measurements: measurements}},
         update_candidates(state, List.delete(state.registered_engines, engine_name))}
      else
        error ->
          Logger.error("Engine unregistration failed by #{inspect(error)}.")
          {error, state}
      end

    :ok = Utils.zenohex_reply(zenoh_query, unregister_engine_key, result)
    {:noreply, state}
  end

  def handle_info(
        %Zenohex.Query{key_expr: register_engine_key, payload: binary, zenoh_query: zenoh_query},
        %{register_engine_key: register_engine_key} = state
      ) do
    relay_recv_timestamp_from_engine = System.os_time(:microsecond)
    relay_name = state.relay_name
    key_prefix = state.key_prefix

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

        registered_engines =
          if engine_name in state.registered_engines do
            state.registered_engines
          else
            state.registered_engines ++ [engine_name]
          end

        state = update_candidates(state, registered_engines)

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

  def handle_call({:select_engine, request}, _from, state) do
    registered_engines = state.registered_engines

    if registered_engines == [] do
      {:reply, {:error, "engine_not_registered"}, state}
    else
      case state.engine_selection_policy.select(
             registered_engines,
             request,
             state.engine_selection_policy_state
           ) do
        {:ok, engine_name, policy_state} ->
          if engine_name in registered_engines do
            {:reply, {:ok, engine_name}, %{state | engine_selection_policy_state: policy_state}}
          else
            Logger.error(
              "Selection policy returned an unregistered Engine: #{inspect(engine_name)}."
            )

            {:reply, {:error, "invalid_engine_selection"}, state}
          end

        {:error, _reason} = error ->
          {:reply, error, state}
      end
    end
  end

  defp update_candidates(state, registered_engines) do
    if registered_engines == state.registered_engines do
      state
    else
      policy_state =
        state.engine_selection_policy.candidates_changed(
          state.registered_engines,
          registered_engines,
          state.engine_selection_policy_state
        )

      %{
        state
        | registered_engines: registered_engines,
          engine_selection_policy_state: policy_state
      }
    end
  end

  defp extract(term) do
    %{
      engine_name: engine_name
    } = term

    {:ok, engine_name}
  rescue
    MatchError -> {:error, "term_not_expected"}
  end

  defp extract_unregister(%{data: %{engine_name: engine_name}, measurements: measurements})
       when is_binary(engine_name) and is_map(measurements) do
    {:ok, {engine_name, measurements}}
  end

  defp extract_unregister(_), do: {:error, "term_not_expected"}

  defp maybe_add_measurements(result, relay_recv_timestamp_from_engine) do
    case result do
      {:ok, %{data: data, measurements: measurements}} ->
        measurements =
          Map.merge(measurements, %{
            relay_recv_timestamp_from_engine: relay_recv_timestamp_from_engine,
            relay_send_timestamp_to_engine: System.os_time(:microsecond)
          })

        {:ok, %{data: data, measurements: measurements}}

      result ->
        result
    end
  end
end
