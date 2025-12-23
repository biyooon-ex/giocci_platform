defmodule GiocciRelay.Worker do
  use GenServer

  require Logger

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
        %Zenohex.Query{key_expr: register_engine_key, payload: binary, zenoh_query: zenoh_query},
        %{register_engine_key: register_engine_key} = state
      ) do
    result =
      with {:ok, %{engine_name: _engine_name}} <- decode(binary) do
        # IMPLEMENT ME クライアントの登録
        :ok
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
    result =
      with {:ok, %{client_name: _client_name}} <- decode(binary) do
        # IMPLEMENT ME クライアントの登録
        :ok
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
    session_id = state.session_id
    key_prefix = state.key_prefix
    # IMPLEMENT ME 複数エンジンへの登録
    engine_name = "giocci_engine"

    # IMPLEMENT ME Client が登録済みチェックか、client に payload 内で送らせる必要あり
    # IMPLEMENT ME Relay に対するモジュール保存
    result =
      with key <- Path.join(key_prefix, "giocci/save_module/relay/#{engine_name}"),
           {:ok, %{timeout: timeout}} <- decode(binary),
           {:ok, binary} <- zenohex_get(session_id, key, timeout, binary),
           {:ok, :ok = _recv_term} <- decode(binary) do
        :ok
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
    # IMPREMENT ME, select engine logic
    result =
      with {:ok, %{mfargs: _mfargs}} <- decode(binary),
           {:ok, engine_name} <- {:ok, "giocci_engine"} do
        {:ok, %{engine_name: engine_name}}
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
end
