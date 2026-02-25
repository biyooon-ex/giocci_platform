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
    measure_to = Keyword.get(opts, :measure_to)

    term_to_relay = %{
      data: %{client_name: client_name},
      measurements: %{}
    }

    {result, state} =
      with key <- Path.join(key_prefix, "giocci/register/client/#{relay_name}"),
           {:ok, term_from_relay} <- Utils.zenohex_get(session_id, key, timeout, term_to_relay) do
        registered_relays = [relay_name | registered_relays] |> Enum.uniq()
        state = %{state | registered_relays: registered_relays}
        {term_from_relay, state}
      else
        error -> {error, state}
      end

    result = maybe_send_measurements(result, measure_to)

    {:reply, result, state}
  end

  def handle_call({:save_module, relay_name, module, opts}, _from, state) do
    client_name = state.client_name
    key_prefix = state.key_prefix
    registered_relays = state.registered_relays

    session_id = Giocci.SessionManager.session_id()

    timeout = Keyword.fetch!(opts, :timeout)
    measure_to = Keyword.get(opts, :measure_to)

    term_to_relay =
      %{
        data: %{
          module_object_code: :code.get_object_code(module),
          timeout: timeout,
          client_name: client_name
        },
        measurements: %{}
      }

    result =
      with :ok <- validate_relay_registered(relay_name, registered_relays),
           :ok <- validate_module_found(module),
           key <- Path.join(key_prefix, "giocci/save_module/client/#{relay_name}"),
           {:ok, term_from_relay} <- Utils.zenohex_get(session_id, key, timeout, term_to_relay) do
        # NOTE: term_from_relay is a list of {:ok, _} or {:error, _} tuples.
        term_from_relay
      end

    result = maybe_send_measurements(result, measure_to)

    {:reply, result, state}
  end

  def handle_call({:exec_func, relay_name, mfargs, opts}, _from, state) do
    client_name = state.client_name
    key_prefix = state.key_prefix
    registered_relays = state.registered_relays

    session_id = Giocci.SessionManager.session_id()

    timeout = Keyword.fetch!(opts, :timeout)
    measure_to = Keyword.get(opts, :measure_to)

    term_to_relay =
      %{
        data: %{
          mfargs: mfargs,
          client_name: client_name
        },
        measurements: %{}
      }

    result =
      with :ok <- validate_relay_registered(relay_name, registered_relays),
           key <- Path.join(key_prefix, "giocci/inquiry_engine/client/#{relay_name}"),
           {:ok, term_from_relay} <- Utils.zenohex_get(session_id, key, timeout, term_to_relay),
           {:ok, %{data: data, measurements: measurements}} <- term_from_relay,
           key <- Path.join(key_prefix, "giocci/exec_func/client/#{data.engine_name}"),
           term_to_engine <- %{term_to_relay | measurements: measurements},
           {:ok, term_from_engine} <- Utils.zenohex_get(session_id, key, timeout, term_to_engine) do
        term_from_engine
      end

    result = maybe_send_measurements(result, measure_to)

    {:reply, result, state}
  end

  def handle_call({:exec_func_async, relay_name, mfargs, server, opts}, _from, state) do
    client_name = state.client_name
    key_prefix = state.key_prefix
    registered_relays = state.registered_relays

    session_id = Giocci.SessionManager.session_id()

    timeout = Keyword.fetch!(opts, :timeout)

    exec_id = make_ref()

    term_to_relay =
      %{
        data: %{
          mfargs: mfargs,
          exec_id: exec_id,
          client_name: client_name
        },
        measurements: %{}
      }

    result =
      with :ok <- validate_relay_registered(relay_name, registered_relays),
           key <- Path.join(key_prefix, "giocci/inquiry_engine/client/#{relay_name}"),
           {:ok, term_from_relay} <- Utils.zenohex_get(session_id, key, timeout, term_to_relay),
           {:ok, %{data: data, measurements: measurements}} <- term_from_relay,
           key <- Path.join(key_prefix, "giocci/exec_func_async/engine/#{client_name}"),
           {:ok, subscriber_id} <- Zenohex.Session.declare_subscriber(session_id, key),
           key <- Path.join(key_prefix, "giocci/exec_func_async/client/#{data.engine_name}"),
           term_to_engine <- %{term_to_relay | measurements: measurements},
           :ok <- Utils.zenohex_put(session_id, key, term_to_engine) do
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
    with {:ok, term_from_engine} <- Utils.decode(binary),
         {:ok, %{data: %{exec_id: exec_id, result: result}}} <- term_from_engine,
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

  # for save_module result
  defp maybe_send_measurements(result, measure_to) when is_list(result) do
    Enum.each(result, &maybe_send_measurements(&1, measure_to))
  end

  defp maybe_send_measurements(result, measure_to) do
    case result do
      {:ok, recv_term} ->
        if is_pid(measure_to) do
          send(measure_to, {:giocci_measurements, recv_term.measurements})
        end

        recv_term.data

      result ->
        result
    end
  end
end
