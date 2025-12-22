defmodule GiocciClient.Worker do
  use GenServer

  @worker_name __MODULE__

  # API

  def register_client(relay_name, opts \\ []) do
    GenServer.call(@worker_name, {:register_client, relay_name, opts})
  end

  def save_module(relay_name, module, opts \\ []) do
    GenServer.call(@worker_name, {:save_module, relay_name, module, opts})
  end

  def exec_func(relay_name, mfargs, opts \\ []) do
    GenServer.call(@worker_name, {:exec_func, relay_name, mfargs, opts})
  end

  def exec_func_async(relay_name, mfargs, server, opts \\ []) do
    GenServer.call(@worker_name, {:exec_func_async, relay_name, mfargs, server, opts})
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: @worker_name)
  end

  # callbacks

  def init(args) do
    client_name = Keyword.fetch!(args, :client_name)
    key_prefix = Keyword.get(args, :key_prefix, "")

    {:ok, session_id} =
      Zenohex.Config.default()
      |> Zenohex.Config.update_in(["mode"], fn _ -> "client" end)
      |> Zenohex.Session.open()

    {:ok,
     %{
       client_name: client_name,
       session_id: session_id,
       key_prefix: key_prefix
     }}
  end

  def handle_call({:register_client, relay_name, opts}, _from, state) do
    client_name = state.client_name
    session_id = state.session_id
    key_prefix = state.key_prefix

    timeout = Keyword.get(opts, :timeout, 100)

    send_term = %{client_name: client_name}

    result =
      with key <- Path.join(key_prefix, "giocci/register/client/#{relay_name}"),
           {:ok, binary} <- encode(send_term),
           {:ok, binary} <- zenohex_get(session_id, key, timeout, binary),
           {:ok, recv_term} <- decode(binary) do
        :ok = recv_term
      end

    {:reply, result, state}
  end

  def handle_call({:save_module, relay_name, module, opts}, _from, state) do
    session_id = state.session_id
    key_prefix = state.key_prefix

    timeout = Keyword.get(opts, :timeout, 100)

    send_term =
      %{
        module_object_code: :code.get_object_code(module),
        timeout: timeout
      }

    result =
      with key <- Path.join(key_prefix, "giocci/save_module/client/#{relay_name}"),
           {:ok, binary} <- encode(send_term),
           {:ok, binary} <- zenohex_get(session_id, key, timeout, binary),
           {:ok, recv_term} <- decode(binary) do
        :ok = recv_term
      end

    {:reply, result, state}
  end

  def handle_call({:exec_func, relay_name, mfargs, opts}, _from, state) do
    session_id = state.session_id
    key_prefix = state.key_prefix

    timeout = Keyword.get(opts, :timeout, 100)

    send_term = %{mfargs: mfargs}

    result =
      with key <- Path.join(key_prefix, "giocci/inquiry_engine/client/#{relay_name}"),
           {:ok, binary} <- encode(send_term),
           {:ok, binary} <- zenohex_get(session_id, key, timeout, binary),
           {:ok, recv_term} <- decode(binary),
           {:ok, %{engine_name: engine_name}} <- recv_term,
           key <- Path.join(key_prefix, "giocci/exec_func/client/#{engine_name}"),
           {:ok, binary} <- encode(send_term),
           {:ok, binary} <- zenohex_get(session_id, key, timeout, binary),
           {:ok, recv_term} <- decode(binary) do
        recv_term
      end

    {:reply, result, state}
  end

  def handle_call({:exec_func_async, relay_name, mfargs, server, opts}, _from, state) do
    client_name = state.client_name
    session_id = state.session_id
    key_prefix = state.key_prefix

    timeout = Keyword.get(opts, :timeout, 100)

    exec_id = make_ref()

    send_term =
      %{
        mfargs: mfargs,
        exec_id: exec_id,
        client_name: client_name
      }

    result =
      with key <- Path.join(key_prefix, "giocci/inquiry_engine/client/#{relay_name}"),
           {:ok, send_binary} <- encode(send_term),
           {:ok, recv_binary} <- zenohex_get(session_id, key, timeout, send_binary),
           {:ok, recv_term} <- decode(recv_binary),
           {:ok, %{engine_name: engine_name}} <- recv_term,
           key <- Path.join(key_prefix, "giocci/exec_func_async/engine/#{client_name}"),
           {:ok, subscriber_id} <- Zenohex.Session.declare_subscriber(session_id, key),
           key <- Path.join(key_prefix, "giocci/exec_func_async/client/#{engine_name}"),
           :ok <- Zenohex.Session.put(session_id, key, send_binary),
           :ok = GiocciClient.Store.put(exec_id, %{server: server, subscriber_id: subscriber_id}) do
        :ok
      end

    {:reply, result, state}
  end

  def handle_info(%Zenohex.Sample{payload: binary}, state) do
    with {:ok, recv_term} <- decode(binary),
         {:ok, %{exec_id: exec_id, result: result}} <- recv_term,
         %{server: server, subscriber_id: subscriber_id} <- GiocciClient.Store.get(exec_id) do
      send(server, {:giocci_client, result})
      :ok = GiocciClient.Store.delete(exec_id)
      :ok = Zenohex.Subscriber.undeclare(subscriber_id)
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
end
