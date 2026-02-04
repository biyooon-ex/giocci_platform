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
    relay_name = state.relay_name
    key_prefix = state.key_prefix

    session_id = GiocciRelay.SessionManager.session_id()

    result =
      with {:ok, recv_term} <- Utils.decode(binary),
           {:ok, {module_object_code, timeout, client_name}} <- extract(recv_term),
           :ok <- GiocciRelay.ClientRegistrar.validate_registered(client_name),
           :ok <- GiocciRelay.ModuleStore.put(client_name, module_object_code) do
        send_term = %{
          relay_name: relay_name,
          client_modules_map: %{client_name => [module_object_code]}
        }

        for engine_name <- GiocciRelay.EngineRegistrar.registered_engines() do
          with key <- Path.join(key_prefix, "giocci/save_module/relay/#{engine_name}"),
               {:ok, binary} <- Utils.encode(send_term),
               {:ok, binary} <- Utils.zenohex_get(session_id, key, timeout, binary),
               {:ok, recv_term} <- Utils.decode(binary) do
            :ok = recv_term
          end
        end

        {module, _binary, _filename} = module_object_code
        Logger.debug("#{inspect(module)} saved successfully, from #{inspect(client_name)}.")
        :ok
      else
        error ->
          Logger.error("Module save failed, #{inspect(error)}.")
          error
      end

    {:ok, binary} = Utils.encode(result)
    :ok = Zenohex.Query.reply(zenoh_query, save_module_key, binary)

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
end
