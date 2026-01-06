defmodule GiocciRelay.Worker do
  use GenServer

  require Logger

  @worker_name __MODULE__

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: @worker_name)
  end

  def init(args) do
    zenoh_config =
      case Keyword.get(args, :zenoh_config_file_path) do
        nil ->
          Zenohex.Config.default()
          |> Zenohex.Config.update_in(["mode"], fn _ -> "client" end)

        zenoh_config_file_path ->
          zenoh_config_file_path
          |> File.read!()
      end

    relay_name = Keyword.fetch!(args, :relay_name)
    key_prefix = Keyword.get(args, :key_prefix, "")

    {:ok, session_id} = Zenohex.Session.open(zenoh_config)

    register_engine_key = Path.join(key_prefix, "giocci/register/engine/#{relay_name}")

    {:ok, register_engine_queryable_id} =
      Zenohex.Session.declare_queryable(session_id, register_engine_key)

    register_client_key = Path.join(key_prefix, "giocci/register/client/#{relay_name}")

    {:ok, register_client_queryable_id} =
      Zenohex.Session.declare_queryable(session_id, register_client_key)

    save_module_key = Path.join(key_prefix, "giocci/save_module/client/#{relay_name}")

    {:ok, save_module_queryable_id} =
      Zenohex.Session.declare_queryable(session_id, save_module_key)

    inquiry_engine_key = Path.join(key_prefix, "giocci/inquiry_engine/client/#{relay_name}")

    {:ok, inquiry_engine_queryable_id} =
      Zenohex.Session.declare_queryable(session_id, inquiry_engine_key)

    Logger.info("#{inspect(relay_name)} started.")

    {:ok,
     %{
       relay_name: relay_name,
       session_id: session_id,
       key_prefix: key_prefix,
       register_engine_queryable_id: register_engine_queryable_id,
       register_engine_key: register_engine_key,
       register_client_queryable_id: register_client_queryable_id,
       register_client_key: register_client_key,
       save_module_queryable_id: save_module_queryable_id,
       save_module_key: save_module_key,
       inquiry_engine_queryable_id: inquiry_engine_queryable_id,
       inquiry_engine_key: inquiry_engine_key,
       registered_engines: [],
       registered_clients: []
     }}
  end

  # for GiocciEngine.register_engine/2
  def handle_info(
        %Zenohex.Query{key_expr: register_engine_key, payload: binary, zenoh_query: zenoh_query},
        %{register_engine_key: register_engine_key} = state
      ) do
    session_id = state.session_id
    key_prefix = state.key_prefix
    relay_name = state.relay_name
    registered_engines = state.registered_engines

    {result, state} =
      with {:ok, %{engine_name: engine_name}} <- decode(binary),
           key <- Path.join(key_prefix, "giocci/save_module/relay/#{engine_name}"),
           {:ok, client_modules_map} <- GiocciRelay.ModuleStore.get(),
           {:ok, binary} <-
             encode(%{relay_name: relay_name, client_modules_map: client_modules_map}),
           {:ok, binary} <- zenohex_get(session_id, key, _timeout = 5000, binary),
           {:ok, recv_term} <- decode(binary),
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

    {:ok, binary} = encode(result)
    :ok = Zenohex.Query.reply(zenoh_query, register_engine_key, binary)

    {:noreply, state}
  end

  # for GiocciClient.register_client/2
  def handle_info(
        %Zenohex.Query{key_expr: register_client_key, payload: binary, zenoh_query: zenoh_query},
        %{register_client_key: register_client_key} = state
      ) do
    registered_clients = state.registered_clients

    {result, state} =
      with {:ok, %{client_name: client_name}} <- decode(binary) do
        Logger.debug("#{inspect(client_name)} registration completed successfully.")
        registered_clients = [client_name | registered_clients] |> Enum.uniq()
        {:ok, %{state | registered_clients: registered_clients}}
      else
        error ->
          Logger.error("Client registration failed by #{inspect(error)}.")
          {error, state}
      end

    {:ok, binary} = encode(result)
    :ok = Zenohex.Query.reply(zenoh_query, register_client_key, binary)

    {:noreply, state}
  end

  # for GiocciClient.save_module/3
  def handle_info(
        %Zenohex.Query{key_expr: save_module_key, payload: binary, zenoh_query: zenoh_query},
        %{save_module_key: save_module_key} = state
      ) do
    relay_name = state.relay_name
    session_id = state.session_id
    key_prefix = state.key_prefix
    registered_engines = state.registered_engines
    registered_clients = state.registered_clients

    result =
      with {:ok, recv_term} <- decode(binary),
           {:ok, {module_object_code, timeout, client_name}} <- extract_save_module(recv_term),
           :ok <- ensure_client_registered(client_name, registered_clients),
           :ok <- GiocciRelay.ModuleStore.put(client_name, module_object_code) do
        send_term = %{
          relay_name: relay_name,
          client_modules_map: %{client_name => [module_object_code]}
        }

        for engine_name <- registered_engines do
          with key <- Path.join(key_prefix, "giocci/save_module/relay/#{engine_name}"),
               {:ok, binary} <- encode(send_term),
               {:ok, binary} <- zenohex_get(session_id, key, timeout, binary),
               {:ok, recv_term} <- decode(binary) do
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

    {:ok, binary} = encode(result)
    :ok = Zenohex.Query.reply(zenoh_query, save_module_key, binary)

    {:noreply, state}
  end

  # for GiocciClient.exec_func/3 step1
  def handle_info(
        %Zenohex.Query{key_expr: inquiry_engine_key, payload: binary, zenoh_query: zenoh_query},
        %{inquiry_engine_key: inquiry_engine_key} = state
      ) do
    registered_engines = state.registered_engines
    registered_clients = state.registered_clients

    result =
      with {:ok, recv_term} <- decode(binary),
           {:ok, {mfargs, client_name}} <- extract_exec_func(recv_term),
           :ok <- ensure_client_registered(client_name, registered_clients),
           {:ok, engine_name} <- select_engine(registered_engines) do
        Logger.debug(
          "#{inspect(engine_name)} is selected for #{inspect(client_name)}'s #{inspect(mfargs)}."
        )

        {:ok, %{engine_name: engine_name}}
      else
        error ->
          Logger.error("Inquiry engine failed, #{inspect(error)}.")
          error
      end

    {:ok, binary} = encode(result)
    :ok = Zenohex.Query.reply(zenoh_query, inquiry_engine_key, binary)

    {:noreply, state}
  end

  defp zenohex_get(session_id, key, timeout, payload) do
    case Zenohex.Session.get(session_id, key, timeout, payload: payload) do
      {:ok, [%Zenohex.Sample{payload: payload}]} ->
        {:ok, payload}

      {:error, :timeout} ->
        {:error, :timeout}

      {:error, reason} ->
        {:error, "Zenohex.Session.get/4 error: #{inspect(reason)}"}
    end
  end

  defp encode(term) do
    {:ok, :erlang.term_to_binary(term)}
  end

  defp decode(payload) do
    {:ok, :erlang.binary_to_term(payload)}
  rescue
    ArgumentError -> {:error, :decode_failed}
  end

  defp extract_save_module(term) do
    %{
      module_object_code: module_object_code,
      timeout: timeout,
      client_name: client_name
    } = term

    {:ok, {module_object_code, timeout, client_name}}
  rescue
    MatchError -> {:error, :term_not_expected}
  end

  defp extract_exec_func(term) do
    %{
      mfargs: mfargs,
      client_name: client_name
    } = term

    {:ok, {mfargs, client_name}}
  rescue
    MatchError -> {:error, :term_not_expected}
  end

  defp ensure_client_registered(client_name, registered_clients) do
    if client_name in registered_clients do
      :ok
    else
      {:error, :client_not_registered}
    end
  end

  defp select_engine(registered_engines) do
    if Enum.empty?(registered_engines) do
      {:error, :engine_not_registered}
    else
      # IMPREMENT ME, select engine logic
      {:ok, List.first(registered_engines)}
    end
  end
end
