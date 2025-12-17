defmodule GiocciEngine.Worker do
  use GenServer

  require Logger

  @worker_name __MODULE__

  # API

  def register_engine(relay_name, opts \\ []) do
    GenServer.call(@worker_name, {:register_engine, relay_name, opts})
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: @worker_name)
  end

  def init(args) do
    engine_name = Keyword.fetch!(args, :engine_name)
    key_prefix = Keyword.get(args, :key_prefix, "")

    {:ok, session_id} =
      Zenohex.Config.default()
      |> Zenohex.Config.update_in(["mode"], fn _ -> "client" end)
      |> Zenohex.Session.open()

    save_module_key = Path.join(key_prefix, "giocci/save_module/relay/#{engine_name}")

    {:ok, save_module_queryable_id} =
      Zenohex.Session.declare_queryable(session_id, save_module_key)

    exec_func_key = Path.join(key_prefix, "giocci/exec_func/client/#{engine_name}")

    {:ok, exec_func_queryable_id} =
      Zenohex.Session.declare_queryable(session_id, exec_func_key)

    exec_func_async_key = Path.join(key_prefix, "giocci/exec_func_async/client/#{engine_name}")

    {:ok, exec_func_async_subscriber_id} =
      Zenohex.Session.declare_subscriber(session_id, exec_func_async_key)

    {:ok,
     %{
       engine_name: engine_name,
       session_id: session_id,
       key_prefix: key_prefix,
       save_module_key: save_module_key,
       save_module_queryable_id: save_module_queryable_id,
       exec_func_key: exec_func_key,
       exec_func_queryable_id: exec_func_queryable_id,
       exec_func_async_key: exec_func_async_key,
       exec_func_async_subscriber_id: exec_func_async_subscriber_id
     }}
  end

  def handle_call({:register_engine, relay_name, opts}, _from, state) do
    engine_name = state.engine_name
    session_id = state.session_id
    key_prefix = state.key_prefix

    key = Path.join(key_prefix, "giocci/register/engine/#{relay_name}")
    timeout = Keyword.get(opts, :timeout, 100)

    payload =
      %{engine_name: engine_name}
      |> :erlang.term_to_binary()

    result =
      case Zenohex.Session.get(session_id, key, timeout, payload: payload) do
        {:ok, [%Zenohex.Sample{payload: payload}]} ->
          case :erlang.binary_to_term(payload) do
            :ok -> :ok
          end

        {:error, :timeout} ->
          {:error, :timeout}

        {:error, reason} ->
          {:error, "Zenohex unexpected error: #{inspect(reason)}"}

        error ->
          {:error, "Unexpected error: #{inspect(error)}"}
      end

    {:reply, result, state}
  end

  # for GiocciRelay.save_module/3
  def handle_info(
        %Zenohex.Query{key_expr: save_module_key, payload: payload, zenoh_query: zenoh_query},
        %{save_module_key: save_module_key} = state
      ) do
    engine_name = state.engine_name

    result =
      case :erlang.binary_to_term(payload) do
        %{module_object_code: {module, binary, filename}} ->
          case :code.load_binary(module, filename, binary) do
            {:module, module} ->
              Logger.info("#{engine_name} loaded #{inspect(module)}.")
              :ok

            {:error, reason} ->
              {:error, reason}
          end

        invalid_term ->
          Logger.error("#{engine_name} received invalid term #{inspect(invalid_term)}.")
          {:error, "GiocciEngine received invalid term."}
      end

    :ok = Zenohex.Query.reply(zenoh_query, save_module_key, :erlang.term_to_binary(result))
    {:noreply, state}
  rescue
    ArgumentError ->
      result = {:error, :invalid_erlang_binary}
      Logger.error("#{state.engine_name} received invalid binary.")
      :ok = Zenohex.Query.reply(zenoh_query, save_module_key, :erlang.term_to_binary(result))
      {:noreply, state}
  end

  # for GiocciClient.exec_func/3
  def handle_info(
        %Zenohex.Query{key_expr: exec_func_key, payload: payload, zenoh_query: zenoh_query},
        %{exec_func_key: exec_func_key} = state
      ) do
    engine_name = state.engine_name

    result =
      case :erlang.binary_to_term(payload) do
        %{mfargs: {m, f, args}} ->
          {:ok, apply(m, f, args)}

        invalid_term ->
          Logger.error(
            "#{engine_name} received invalid term #{inspect(invalid_term)} for exec_func."
          )

          {:error, "GiocciEngine received invalid term #{inspect(invalid_term)} for exec_func."}
      end

    :ok = Zenohex.Query.reply(zenoh_query, exec_func_key, :erlang.term_to_binary(result))
    {:noreply, state}
  rescue
    UndefinedFunctionError ->
      mfargs = :erlang.binary_to_term(payload)
      result = {:error, "Cannot exec not saved func, #{inspect(mfargs)} "}
      Logger.error("#{state.engine_name} cannot exec #{inspect(mfargs)}.")

      :ok = Zenohex.Query.reply(zenoh_query, exec_func_key, :erlang.term_to_binary(result))
      {:noreply, state}
  end

  # for GiocciClient.exec_func_async/4
  def handle_info(
        %Zenohex.Sample{key_expr: exec_func_async_key, payload: payload},
        %{exec_func_async_key: exec_func_async_key} = state
      ) do
    engine_name = state.engine_name
    session_id = state.session_id
    key_prefix = state.key_prefix

    try do
      result =
        case :erlang.binary_to_term(payload) do
          %{mfargs: {m, f, args}, exec_id: exec_id, client_name: client_name} ->
            {:ok,
             %{
               mfargs: {m, f, args},
               exec_id: exec_id,
               client_name: client_name,
               result: apply(m, f, args)
             }}

          invalid_term ->
            Logger.error(
              "#{engine_name} received invalid term #{inspect(invalid_term)} for exec_func."
            )

            {:error, "GiocciEngine received invalid term #{inspect(invalid_term)} for exec_func."}
        end

      {:ok, %{client_name: client_name}} = result
      key = Path.join(key_prefix, "giocci/exec_func_async/engine/#{client_name}")
      :ok = Zenohex.Session.put(session_id, key, :erlang.term_to_binary(result))
      {:noreply, state}
    rescue
      UndefinedFunctionError ->
        mfargs = :erlang.binary_to_term(payload)
        result = {:error, "Cannot exec not saved func, #{inspect(mfargs)} "}
        Logger.error("#{state.engine_name} cannot exec #{inspect(mfargs)}.")

        :ok = Zenohex.Session.put(session_id, exec_func_async_key, :erlang.term_to_binary(result))
        {:noreply, state}
    end
  end
end
