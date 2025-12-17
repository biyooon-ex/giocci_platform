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

    key = Path.join(key_prefix, "giocci/register/client/#{relay_name}")
    timeout = Keyword.get(opts, :timeout, 100)

    payload =
      %{client_name: client_name}
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

  def handle_call({:save_module, relay_name, module, opts}, _from, state) do
    session_id = state.session_id
    key_prefix = state.key_prefix

    key = Path.join(key_prefix, "giocci/save_module/client/#{relay_name}")
    timeout = Keyword.get(opts, :timeout, 100)

    payload =
      %{
        module_object_code: :code.get_object_code(module),
        timeout: timeout
      }
      |> :erlang.term_to_binary()

    result =
      case Zenohex.Session.get(session_id, key, timeout, payload: payload) do
        {:ok, [%Zenohex.Sample{payload: payload}]} ->
          case :erlang.binary_to_term(payload) do
            :ok -> :ok
            {:error, reason} -> {:error, reason}
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

  def handle_call({:exec_func, relay_name, mfargs, opts}, _from, state) do
    session_id = state.session_id
    key_prefix = state.key_prefix

    key = Path.join(key_prefix, "giocci/inquiry_engine/client/#{relay_name}")
    timeout = Keyword.get(opts, :timeout, 100)

    send_payload =
      %{mfargs: mfargs}
      |> :erlang.term_to_binary()

    result =
      case Zenohex.Session.get(session_id, key, timeout, payload: send_payload) do
        {:ok, [%Zenohex.Sample{payload: recv_payload}]} ->
          case :erlang.binary_to_term(recv_payload) do
            {:ok, %{engine_name: engine_name}} ->
              key = Path.join(key_prefix, "giocci/exec_func/client/#{engine_name}")

              case Zenohex.Session.get(session_id, key, timeout, payload: send_payload) do
                {:ok, [%Zenohex.Sample{payload: recv_payload}]} ->
                  case :erlang.binary_to_term(recv_payload) do
                    {:ok, result} -> result
                    {:error, reason} -> {:error, reason}
                  end

                {:error, :timeout} ->
                  {:error, :timeout}

                {:error, reason} ->
                  {:error, "Zenohex unexpected error: #{inspect(reason)}"}

                error ->
                  {:error, "Unexpected error: #{inspect(error)}"}
              end

            {:error, reason} ->
              {:error, "Giocci error: #{inspect(reason)}"}
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

  def handle_call({:exec_func_async, relay_name, mfargs, server, opts}, _from, state) do
    client_name = state.client_name
    session_id = state.session_id
    key_prefix = state.key_prefix

    key = Path.join(key_prefix, "giocci/inquiry_engine/client/#{relay_name}")
    timeout = Keyword.get(opts, :timeout, 100)

    exec_id = make_ref()

    send_payload =
      %{
        mfargs: mfargs,
        exec_id: exec_id,
        client_name: client_name
      }
      |> :erlang.term_to_binary()

    result =
      case Zenohex.Session.get(session_id, key, timeout, payload: send_payload) do
        {:ok, [%Zenohex.Sample{payload: recv_payload}]} ->
          case :erlang.binary_to_term(recv_payload) do
            {:ok, %{engine_name: engine_name}} ->
              recv_key = Path.join(key_prefix, "giocci/exec_func_async/engine/#{client_name}")
              send_key = Path.join(key_prefix, "giocci/exec_func_async/client/#{engine_name}")

              with {:ok, subscriber_id} <-
                     Zenohex.Session.declare_subscriber(session_id, recv_key),
                   :ok <- Zenohex.Session.put(session_id, send_key, send_payload) do
                GiocciClient.Store.put(exec_id, %{server: server, subscriber_id: subscriber_id})
                :ok
              else
                {:error, reason} ->
                  {:error, "Zenohex unexpected error: #{inspect(reason)}"}
              end

            {:error, reason} ->
              {:error, "Giocci error: #{inspect(reason)}"}
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

  def handle_info(%Zenohex.Sample{payload: payload}, state) do
    case :erlang.binary_to_term(payload) do
      {:ok, %{exec_id: exec_id, result: result}} ->
        with %{server: server, subscriber_id: subscriber_id} <- GiocciClient.Store.get(exec_id) do
          send(server, {:giocci_client, result})
          :ok = GiocciClient.Store.delete(exec_id)

          case Zenohex.Subscriber.undeclare(subscriber_id) do
            :ok -> :ok
            {:error, reason} -> nil
          end
        else
          nil -> nil
        end

      {:error, reason} ->
        nil
    end

    {:noreply, state}
  end
end
