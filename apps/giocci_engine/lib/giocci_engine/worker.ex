defmodule GiocciEngine.Worker do
  use GenServer

  require Logger

  @worker_name __MODULE__

  # API

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

    engine_name = Keyword.fetch!(args, :engine_name)
    key_prefix = Keyword.get(args, :key_prefix, "")
    relay_name = Keyword.fetch!(args, :relay_name)

    {:ok, session_id} = Zenohex.Session.open(zenoh_config)

    save_module_key = Path.join(key_prefix, "giocci/save_module/relay/#{engine_name}")

    {:ok, save_module_queryable_id} =
      Zenohex.Session.declare_queryable(session_id, save_module_key)

    exec_func_key = Path.join(key_prefix, "giocci/exec_func/client/#{engine_name}")

    {:ok, exec_func_queryable_id} =
      Zenohex.Session.declare_queryable(session_id, exec_func_key)

    exec_func_async_key = Path.join(key_prefix, "giocci/exec_func_async/client/#{engine_name}")

    {:ok, exec_func_async_subscriber_id} =
      Zenohex.Session.declare_subscriber(session_id, exec_func_async_key)

    send_term = %{engine_name: engine_name}

    # Register this Engine to the specified Relay when starts
    :ok =
      with key <- Path.join(key_prefix, "giocci/register/engine/#{relay_name}"),
           {:ok, binary} <- encode(send_term),
           {:ok, binary} <- zenohex_get(session_id, key, _timeout = 5000, binary),
           {:ok, recv_term} <- decode(binary) do
        recv_term
      end

    Logger.info("#{inspect(engine_name)} started.")

    {:ok,
     %{
       engine_name: engine_name,
       session_id: session_id,
       key_prefix: key_prefix,
       relay_name: relay_name,
       save_module_key: save_module_key,
       save_module_queryable_id: save_module_queryable_id,
       exec_func_key: exec_func_key,
       exec_func_queryable_id: exec_func_queryable_id,
       exec_func_async_key: exec_func_async_key,
       exec_func_async_subscriber_id: exec_func_async_subscriber_id
     }}
  end

  # for GiocciRelay.save_module/3
  def handle_info(
        %Zenohex.Query{key_expr: save_module_key, payload: binary, zenoh_query: zenoh_query},
        %{save_module_key: save_module_key} = state
      ) do
    relay_name = state.relay_name

    result =
      with {:ok, recv_term} <- decode(binary),
           {:ok, {received_relay_name, client_modules_map}} <- extract_save_module(recv_term),
           :ok <- verify_relay_name(relay_name, received_relay_name),
           :ok <- save_module(client_modules_map) do
        Logger.debug("Module saved successfully.")
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

  # for GiocciClient.exec_func/3
  def handle_info(
        %Zenohex.Query{key_expr: exec_func_key, payload: binary, zenoh_query: zenoh_query},
        %{exec_func_key: exec_func_key} = state
      ) do
    result =
      with {:ok, recv_term} <- decode(binary),
           {:ok, {{m, _f, _args} = mfargs, _client_name}} <- extract_exec_func(recv_term),
           :ok <- ensure_module_saved(m),
           {:ok, result} <- exec_func(mfargs) do
        Logger.debug("Exec func successfully, #{inspect(mfargs)}.")
        result
      else
        error ->
          Logger.error("Exec func failed, #{inspect(error)}.")
          error
      end

    {:ok, binary} = encode(result)
    :ok = Zenohex.Query.reply(zenoh_query, exec_func_key, binary)

    {:noreply, state}
  end

  # for GiocciClient.exec_func_async/4
  def handle_info(
        %Zenohex.Sample{key_expr: exec_func_async_key, payload: binary},
        %{exec_func_async_key: exec_func_async_key} = state
      ) do
    session_id = state.session_id
    key_prefix = state.key_prefix

    with {:ok, recv_term} <- decode(binary),
         {:ok, {{m, _f, _args} = mfargs, exec_id, client_name}} <-
           extract_exec_func_async(recv_term),
         :ok <- ensure_module_saved(m),
         {:ok, result} <- exec_func(mfargs),
         key <- Path.join(key_prefix, "giocci/exec_func_async/engine/#{client_name}") do
      Logger.debug("Exec func async successfully, #{inspect(mfargs)}.")

      result =
        {:ok,
         %{
           mfargs: mfargs,
           exec_id: exec_id,
           client_name: client_name,
           result: result
         }}

      {:ok, binary} = encode(result)
      :ok = Zenohex.Session.put(session_id, key, binary)
    else
      error ->
        Logger.error("Exec func async failed, #{inspect(error)}.")
        error
    end

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

  defp exec_func({m, f, args} = mfargs) do
    {:ok, apply(m, f, args)}
  rescue
    UndefinedFunctionError ->
      {:error, "#{inspect(mfargs)} not defined"}

    unexpected_error ->
      {:error, "An unexpected error has occured, #{inspect(unexpected_error)}"}
  end

  defp ensure_module_saved(module) do
    if Code.ensure_loaded?(module) do
      :ok
    else
      {:error, :module_not_saved}
    end
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

  defp extract_exec_func_async(term) do
    %{
      mfargs: mfargs,
      exec_id: exec_id,
      client_name: client_name
    } = term

    {:ok, {mfargs, exec_id, client_name}}
  rescue
    MatchError -> {:error, :term_not_expected}
  end
end
