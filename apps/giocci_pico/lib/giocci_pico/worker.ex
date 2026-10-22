defmodule GiocciPico.Worker do
  @moduledoc false

  use GenServer

  alias GiocciPico.Utils
  alias GiocciPico.SessionManager

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

    module_object_code = :code.get_object_code(module)

    if module_object_code == :error do
      {:error, "get_object_code_failed"}
    else
      GenServer.call(@name, {:save_module, relay_name, module_object_code, opts}, :infinity)
    end
  end

  def exec_func(relay_name, mfargs, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    opts = Keyword.put(opts, :timeout, timeout)

    GenServer.call(@name, {:exec_func, relay_name, mfargs, opts}, :infinity)
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

    session = SessionManager.session()

    timeout = Keyword.fetch!(opts, :timeout)
    measure_to = Keyword.get(opts, :measure_to)

    term_to_relay = %{
      data: %{client_name: client_name},
      measurements: %{}
    }

    {result, state} =
      with key <- join(key_prefix, "giocci/register/client/#{relay_name}"),
           {:ok, term_from_relay} <- Utils.zenohex_get(session, key, timeout, term_to_relay) do
        registered_relays = [relay_name | registered_relays] |> uniq()
        state = %{state | registered_relays: registered_relays}
        {term_from_relay, state}
      else
        error -> {error, state}
      end

    result = maybe_send_measurements(result, measure_to)

    {:reply, result, state}
  end

  def handle_call({:save_module, relay_name, module_object_code, opts}, _from, state) do
    client_name = state.client_name
    key_prefix = state.key_prefix
    registered_relays = state.registered_relays

    session = SessionManager.session()

    timeout = Keyword.fetch!(opts, :timeout)
    measure_to = Keyword.get(opts, :measure_to)

    term_to_relay =
      %{
        data: %{
          module_object_code: module_object_code,
          timeout: timeout,
          client_name: client_name
        },
        measurements: %{}
      }

    result =
      with :ok <- validate_relay_registered(relay_name, registered_relays),
           :ok <- validate_module_found(module_object_code),
           key <- join(key_prefix, "giocci/save_module/client/#{relay_name}"),
           {:ok, term_from_relay} <- Utils.zenohex_get(session, key, timeout, term_to_relay) do
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

    session = SessionManager.session()

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
           key <- join(key_prefix, "giocci/inquiry_engine/client/#{relay_name}"),
           {:ok, term_from_relay} <- Utils.zenohex_get(session, key, timeout, term_to_relay),
           {:ok, %{data: data, measurements: measurements}} <- term_from_relay,
           key <- join(key_prefix, "giocci/exec_func/client/#{data.engine_name}"),
           term_to_engine <- %{term_to_relay | measurements: measurements},
           {:ok, term_from_engine} <- Utils.zenohex_get(session, key, timeout, term_to_engine) do
        term_from_engine
      end

    result = maybe_send_measurements(result, measure_to)

    {:reply, result, state}
  end

  defp validate_module_found({module, _binary, _filename}) do
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
      {:ok, %{data: data, measurements: measurements}} ->
        if is_pid(measure_to) do
          measurements = add_calculated_measurements(measurements)
          send(measure_to, {:giocci_measurements, measurements})
        end

        if is_nil(data), do: :ok, else: data

      result ->
        result
    end
  end

  defp add_calculated_measurements(measurements) do
    measurements
    |> add_client_to_relay()
    |> add_relay_to_client()
    |> add_client_to_engine()
    |> add_engine_to_client()
    |> add_relay_to_engine()
    |> add_engine_to_relay()
  end

  defp add_client_to_relay(measurements) do
    case measurements do
      %{
        client_send_timestamp_to_relay: client_send,
        relay_recv_timestamp_from_client: relay_recv
      } ->
        client_to_relay = ((relay_recv - client_send) / 1000) |> Float.round(3)
        Map.put(measurements, :client_to_relay, client_to_relay)

      _ ->
        measurements
    end
  end

  defp add_relay_to_client(measurements) do
    case measurements do
      %{
        relay_send_timestamp_to_client: relay_send,
        client_recv_timestamp_from_relay: client_recv
      } ->
        relay_to_client = ((client_recv - relay_send) / 1000) |> Float.round(3)
        Map.put(measurements, :relay_to_client, relay_to_client)

      _ ->
        measurements
    end
  end

  defp add_client_to_engine(measurements) do
    case measurements do
      %{
        client_send_timestamp_to_engine: client_send,
        engine_recv_timestamp_from_client: engine_recv
      } ->
        client_to_engine = ((engine_recv - client_send) / 1000) |> Float.round(3)
        Map.put(measurements, :client_to_engine, client_to_engine)

      _ ->
        measurements
    end
  end

  defp add_engine_to_client(measurements) do
    case measurements do
      %{
        engine_send_timestamp_to_client: engine_send,
        client_recv_timestamp_from_engine: client_recv
      } ->
        engine_to_client = ((client_recv - engine_send) / 1000) |> Float.round(3)
        Map.put(measurements, :engine_to_client, engine_to_client)

      _ ->
        measurements
    end
  end

  defp add_relay_to_engine(measurements) do
    case measurements do
      %{
        relay_send_timestamp_to_engine: relay_send,
        engine_recv_timestamp_from_relay: engine_recv
      } ->
        relay_to_engine = ((engine_recv - relay_send) / 1000) |> Float.round(3)
        Map.put(measurements, :relay_to_engine, relay_to_engine)

      _ ->
        measurements
    end
  end

  defp add_engine_to_relay(measurements) do
    case measurements do
      %{
        engine_send_timestamp_to_relay: engine_send,
        relay_recv_timestamp_from_engine: relay_recv
      } ->
        engine_to_relay = ((relay_recv - engine_send) / 1000) |> Float.round(3)
        Map.put(measurements, :engine_to_relay, engine_to_relay)

      _ ->
        measurements
    end
  end

  def join(_key_prefix = "", key), do: key
  def join(key_prefix, key), do: "#{key_prefix}/#{key}"

  def uniq(enumerable) do
    Enum.reduce(enumerable, [], fn elem, acc ->
      if elem in acc, do: acc, else: [elem | acc]
    end)
    |> Enum.reverse()
  end
end
