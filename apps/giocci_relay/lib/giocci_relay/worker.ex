defmodule GiocciRelay.Worker do
  use GenServer

  @worker_name __MODULE__

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: @worker_name)
  end

  def init(args) do
    relay_name = Keyword.fetch!(args, :relay_name)
    key_prefix = Keyword.get(args, :key_prefix, "")

    {:ok, session_id} =
      Zenohex.Config.default()
      |> Zenohex.Config.update_in(["mode"], fn _ -> "client" end)
      |> Zenohex.Session.open()

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
       inquiry_engine_key: inquiry_engine_key
     }}
  end

  # for GiocciEngine.register_engine/2
  def handle_info(
        %Zenohex.Query{key_expr: register_engine_key, payload: payload, zenoh_query: zenoh_query},
        %{register_engine_key: register_engine_key} = state
      ) do
    result =
      case :erlang.binary_to_term(payload) do
        %{engine_name: _engine_name} ->
          # IMPLEMENT ME
          :ok

        _ ->
          {:error, :invalid_payload}
      end

    :ok = Zenohex.Query.reply(zenoh_query, register_engine_key, :erlang.term_to_binary(result))
    {:noreply, state}
  rescue
    ArgumentError ->
      result = {:error, :invalid_erlang_binary}
      :ok = Zenohex.Query.reply(zenoh_query, register_engine_key, :erlang.term_to_binary(result))
      {:noreply, state}
  end

  # for GiocciClient.register_client/2
  def handle_info(
        %Zenohex.Query{key_expr: register_client_key, payload: payload, zenoh_query: zenoh_query},
        %{register_client_key: register_client_key} = state
      ) do
    result =
      case :erlang.binary_to_term(payload) do
        %{client_name: _client_name} ->
          # IMPLEMENT ME
          :ok

        _ ->
          {:error, :invalid_payload}
      end

    :ok = Zenohex.Query.reply(zenoh_query, register_client_key, :erlang.term_to_binary(result))
    {:noreply, state}
  rescue
    ArgumentError ->
      result = {:error, :invalid_erlang_binary}
      :ok = Zenohex.Query.reply(zenoh_query, register_client_key, :erlang.term_to_binary(result))
      {:noreply, state}
  end

  # for GiocciClient.save_module/3
  def handle_info(
        %Zenohex.Query{key_expr: save_module_key, payload: payload, zenoh_query: zenoh_query},
        %{save_module_key: save_module_key} = state
      ) do
    session_id = state.session_id
    key_prefix = state.key_prefix
    engine_name = "giocci_engine"

    key = Path.join(key_prefix, "giocci/save_module/relay/#{engine_name}")

    result =
      case :erlang.binary_to_term(payload) do
        %{timeout: timeout} ->
          case Zenohex.Session.get(session_id, key, timeout, payload: payload) do
            {:ok, [%Zenohex.Sample{payload: payload}]} ->
              case :erlang.binary_to_term(payload) do
                :ok -> :ok
                _ -> {:error, "GiocciEngine returned invalid payload"}
              end

            {:error, :timeout} ->
              {:error, :timeout}

            {:error, reason} ->
              {:error, "Zenohex unexpected error: #{inspect(reason)}"}

            error ->
              {:error, "Unexpected error: #{inspect(error)}"}
          end

        _ ->
          {:error, "GiocciClient.save_module/3 invalid payload"}
      end

    :ok = Zenohex.Query.reply(zenoh_query, save_module_key, :erlang.term_to_binary(result))

    {:noreply, state}
  end

  # for GiocciClient.exec_func/3 step1
  def handle_info(
        %Zenohex.Query{key_expr: inquiry_engine_key, payload: payload, zenoh_query: zenoh_query},
        %{inquiry_engine_key: inquiry_engine_key} = state
      ) do
    result =
      case :erlang.binary_to_term(payload) do
        %{mfargs: _mfargs} ->
          # IMPLEMENT ME
          engine_name = "giocci_engine"
          {:ok, %{engine_name: engine_name}}

        _ ->
          {:error, "GiocciClient.exec_func/3 step1 invalid payload"}
      end

    :ok = Zenohex.Query.reply(zenoh_query, inquiry_engine_key, :erlang.term_to_binary(result))

    {:noreply, state}
  end
end
