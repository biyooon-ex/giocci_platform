defmodule GiocciRelay.ModuleSaver do
  @moduledoc false

  use GenServer

  require Logger

  alias GiocciRelay.Utils

  @name __MODULE__

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: @name)
  end

  def init(args) do
    relay_name = Keyword.fetch!(args, :relay_name)
    key_prefix = Keyword.get(args, :key_prefix, "")

    session_id = GiocciRelay.SessionManager.session_id()

    save_module_key = Path.join(key_prefix, "giocci/save_module/client/#{relay_name}")

    {:ok, save_module_queryable_id} =
      Zenohex.Session.declare_queryable(session_id, save_module_key)

    {:ok,
     %{
       relay_name: relay_name,
       key_prefix: key_prefix,
       save_module_key: save_module_key,
       save_module_queryable_id: save_module_queryable_id
     }}
  end

  def handle_info(
        %Zenohex.Query{key_expr: save_module_key, payload: binary, zenoh_query: zenoh_query},
        %{save_module_key: save_module_key} = state
      ) do
    relay_recv_timestamp_from_client = System.system_time(:millisecond)
    relay_name = state.relay_name
    key_prefix = state.key_prefix

    session_id = GiocciRelay.SessionManager.session_id()

    result =
      with {:ok, term_from_client} <- Utils.decode(binary),
           {:ok, {module_object_code, timeout, client_name}} <- extract(term_from_client.data),
           :ok <- GiocciRelay.ClientRegistrar.validate_registered(client_name),
           :ok <- GiocciRelay.ModuleStore.put(client_name, module_object_code) do
        term_to_engine = %{
          data: %{
            relay_name: relay_name,
            client_modules_map: %{client_name => [module_object_code]}
          },
          measurements: term_from_client.measurements
        }

        term_from_engine_list =
          for engine_name <- GiocciRelay.EngineRegistrar.registered_engines() do
            with key <- Path.join(key_prefix, "giocci/save_module/relay/#{engine_name}"),
                 {:ok, term_from_engine} <-
                   Utils.zenohex_get(session_id, key, timeout, term_to_engine) do
              term_from_engine
            end
          end

        {module, _binary, _filename} = module_object_code
        Logger.debug("#{inspect(module)} saved successfully, from #{inspect(client_name)}.")
        {:ok, term_from_engine_list}
      else
        error ->
          Logger.error("Module save failed, #{inspect(error)}.")
          error
      end

    result = maybe_add_measurements(result, relay_recv_timestamp_from_client)
    :ok = Utils.zenohex_reply(zenoh_query, save_module_key, result)

    {:noreply, state}
  end

  defp extract(term) do
    %{
      module_object_code: module_object_code,
      timeout: timeout,
      client_name: client_name
    } = term

    {:ok, {module_object_code, timeout, client_name}}
  rescue
    MatchError -> {:error, "term_not_expected"}
  end

  defp maybe_add_measurements(result, relay_recv_timestamp_from_client) do
    case result do
      {:ok, term_from_engine_list} ->
        term_from_engine_list =
          Enum.map(term_from_engine_list, fn
            {:ok, %{data: data, measurements: measurements}} ->
              measurements =
                Map.merge(measurements, %{
                  relay_recv_timestamp_from_client: relay_recv_timestamp_from_client,
                  relay_send_timestamp_to_client: System.system_time(:millisecond)
                })

              {:ok, %{data: data, measurements: measurements}}

            error ->
              error
          end)

        {:ok, term_from_engine_list}

      result ->
        result
    end
  end
end
