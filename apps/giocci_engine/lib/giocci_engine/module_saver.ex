defmodule GiocciEngine.ModuleSaver do
  @moduledoc false

  use GenServer

  require Logger

  alias GiocciEngine.Utils

  @worker_name __MODULE__

  # API

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: @worker_name)
  end

  def init(args) do
    engine_name = Keyword.fetch!(args, :engine_name)
    key_prefix = Keyword.get(args, :key_prefix, "")
    relay_name = Keyword.fetch!(args, :relay_name)

    session_id = GiocciEngine.SessionManager.session_id()

    save_module_key = Path.join(key_prefix, "giocci/save_module/relay/#{engine_name}")

    {:ok, save_module_queryable_id} =
      Zenohex.Session.declare_queryable(session_id, save_module_key)

    {:ok,
     %{
       engine_name: engine_name,
       key_prefix: key_prefix,
       relay_name: relay_name,
       save_module_key: save_module_key,
       save_module_queryable_id: save_module_queryable_id
     }}
  end

  def handle_info(
        %Zenohex.Query{key_expr: save_module_key, payload: binary, zenoh_query: zenoh_query},
        %{save_module_key: save_module_key} = state
      ) do
    relay_name = state.relay_name

    result =
      with {:ok, recv_term} <- Utils.decode(binary),
           {:ok, {received_relay_name, client_modules_map}} <- extract(recv_term),
           :ok <- verify_relay_name(relay_name, received_relay_name),
           :ok <- save_module(client_modules_map) do
        Logger.debug("Module saved successfully.")
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
      relay_name: relay_name,
      client_modules_map: client_modules_map
    } = term

    {:ok, {relay_name, client_modules_map}}
  rescue
    MatchError -> {:error, :term_not_expected}
  end

  defp verify_relay_name(registered, received) do
    if registered == received do
      :ok
    else
      {:error, :received_relay_name_is_invalid}
    end
  end

  defp save_module({module, binary, filename} = _module_object_code) do
    case :code.load_binary(module, filename, binary) do
      {:module, _module} -> :ok
      error -> error
    end
  end

  defp save_module(module_object_code_list) when is_list(module_object_code_list) do
    results =
      for module_object_code <- module_object_code_list do
        save_module(module_object_code)
      end

    if Enum.all?(results, &(&1 == :ok)) do
      :ok
    else
      {:error, :save_module_failed}
    end
  end

  defp save_module(client_modules_map) when is_map(client_modules_map) do
    client_modules_map
    |> Enum.reduce([], fn {_client, module_object_code_list}, acc ->
      [module_object_code_list | acc]
    end)
    |> save_module()
  end
end
