defmodule Giocci.Worker do
  @moduledoc false

  use GenServer

  alias Giocci.ExecFuncAsyncStore
  alias Giocci.Utils

  @name __MODULE__
  @default_timeout 5000

  # API

  def register_client(relay_name, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    opts = Keyword.put(opts, :timeout, timeout)

    GenServer.call(@name, {:register_client, relay_name, opts}, :infinity)
  end

  def save_module(relay_name, module, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    opts = Keyword.put(opts, :timeout, timeout)

    GenServer.call(@name, {:save_module, relay_name, module, opts}, :infinity)
  end

  def exec_func(relay_name, mfargs, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    opts = Keyword.put(opts, :timeout, timeout)

    GenServer.call(@name, {:exec_func, relay_name, mfargs, opts}, :infinity)
  end

  def exec_func_async(relay_name, mfargs, server, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    opts = Keyword.put(opts, :timeout, timeout)

    GenServer.call(@name, {:exec_func_async, relay_name, mfargs, server, opts}, :infinity)
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: @name)
  end

  # callbacks

  def init(args) do
    client_name = Keyword.fetch!(args, :client_name)
    key_prefix = Keyword.get(args, :key_prefix, "")

    {:ok,
     %{
       client_name: client_name,
       key_prefix: key_prefix,
       registered_relays: []
     }}
  end

  def handle_call({:register_client, relay_name, opts}, _from, state) do
    client_name = state.client_name
    key_prefix = state.key_prefix
    registered_relays = state.registered_relays

    session_id = Giocci.SessionManager.session_id()

    timeout = Keyword.fetch!(opts, :timeout)

    send_term = %{client_name: client_name}

    {result, state} =
      with key <- Path.join(key_prefix, "giocci/register/client/#{relay_name}"),
           {:ok, binary} <- Utils.encode(send_term),
           {:ok, binary} <- Utils.zenohex_get(session_id, key, timeout, binary),
           {:ok, recv_term} <- Utils.decode(binary),
           :ok <- recv_term do
        registered_relays = [relay_name | registered_relays] |> Enum.uniq()
        {:ok, %{state | registered_relays: registered_relays}}
      else
        error -> {error, state}
      end

    {:reply, result, state}
  end

  def handle_call({:save_module, relay_name, module, opts}, _from, state) do
    client_name = state.client_name
    key_prefix = state.key_prefix
    registered_relays = state.registered_relays

    session_id = Giocci.SessionManager.session_id()

    timeout = Keyword.fetch!(opts, :timeout)

    send_term =
      %{
        module_object_code: :code.get_object_code(module),
        timeout: timeout,
        client_name: client_name
      }

    result =
      with :ok <- validate_relay_registered(relay_name, registered_relays),
           :ok <- validate_module_found(module),
           key <- Path.join(key_prefix, "giocci/save_module/client/#{relay_name}"),
           {:ok, binary} <- Utils.encode(send_term),
           {:ok, binary} <- Utils.zenohex_get(session_id, key, timeout, binary),
           {:ok, recv_term} <- Utils.decode(binary) do
        recv_term
      end

    {:reply, result, state}
  end

  def handle_call({:exec_func, relay_name, mfargs, opts}, _from, state) do
    client_name = state.client_name
    key_prefix = state.key_prefix
    registered_relays = state.registered_relays

    session_id = Giocci.SessionManager.session_id()

    timeout = Keyword.fetch!(opts, :timeout)

    send_term =
      %{
        mfargs: mfargs,
        client_name: client_name
      }

    result =
      with :ok <- validate_relay_registered(relay_name, registered_relays),
           key <- Path.join(key_prefix, "giocci/inquiry_engine/client/#{relay_name}"),
           {:ok, binary} <- Utils.encode(send_term),
           {:ok, binary} <- Utils.zenohex_get(session_id, key, timeout, binary),
           {:ok, recv_term} <- Utils.decode(binary),
           {:ok, %{engine_name: engine_name}} <- recv_term,
           key <- Path.join(key_prefix, "giocci/exec_func/client/#{engine_name}"),
           {:ok, binary} <- Utils.encode(send_term),
           {:ok, binary} <- Utils.zenohex_get(session_id, key, timeout, binary),
           {:ok, recv_term} <- Utils.decode(binary) do
        recv_term
      end

    {:reply, result, state}
  end

  def handle_call({:exec_func_async, relay_name, mfargs, server, opts}, _from, state) do
    client_name = state.client_name
    key_prefix = state.key_prefix
    registered_relays = state.registered_relays

    session_id = Giocci.SessionManager.session_id()

    timeout = Keyword.fetch!(opts, :timeout)

    exec_id = make_ref()

    send_term =
      %{
        mfargs: mfargs,
        exec_id: exec_id,
        client_name: client_name
      }

    result =
      with :ok <- validate_relay_registered(relay_name, registered_relays),
           key <- Path.join(key_prefix, "giocci/inquiry_engine/client/#{relay_name}"),
           {:ok, send_binary} <- Utils.encode(send_term),
           {:ok, recv_binary} <- Utils.zenohex_get(session_id, key, timeout, send_binary),
           {:ok, recv_term} <- Utils.decode(recv_binary),
           {:ok, %{engine_name: engine_name}} <- recv_term,
           key <- Path.join(key_prefix, "giocci/exec_func_async/engine/#{client_name}"),
           {:ok, subscriber_id} <- Zenohex.Session.declare_subscriber(session_id, key),
           key <- Path.join(key_prefix, "giocci/exec_func_async/client/#{engine_name}"),
           :ok <- Zenohex.Session.put(session_id, key, send_binary) do
        ExecFuncAsyncStore.put(exec_id, %{
          server: server,
          subscriber_id: subscriber_id,
          timeout: timeout,
          put_time: System.monotonic_time(:millisecond)
        })
      end

    {:reply, result, state}
  end

  def handle_info(%Zenohex.Sample{payload: binary}, state) do
    with {:ok, recv_term} <- Utils.decode(binary),
         {:ok, %{exec_id: exec_id, result: result}} <- recv_term,
         %{server: server, subscriber_id: subscriber_id} <- ExecFuncAsyncStore.get(exec_id) do
      send(server, {:giocci, result})
      :ok = ExecFuncAsyncStore.delete(exec_id)
      :ok = Zenohex.Subscriber.undeclare(subscriber_id)
    end

    {:noreply, state}
  end

  defp validate_module_found(module) do
    if Code.ensure_loaded?(module) do
      :ok
    else
      {:error, "module_not_found"}
    end
  end

  defp validate_relay_registered(relay_name, registered_relays) do
    if relay_name in registered_relays do
      :ok
    else
      {:error, "relay_not_registered"}
    end
  end
end
