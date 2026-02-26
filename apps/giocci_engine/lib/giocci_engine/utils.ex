defmodule GiocciEngine.Utils do
  @moduledoc false

  def zenohex_get(session_id, key, timeout, send_term) do
    {:ok, payload} = encode(add_send_measurements(key, send_term))

    case Zenohex.Session.get(session_id, key, timeout, payload: payload) do
      {:ok, [%Zenohex.Sample{payload: payload}]} ->
        {:ok, recv_term} = decode(payload)
        {:ok, add_recv_measurements(key, recv_term)}

      {:error, :timeout} ->
        operation = extract_operation_description(key)
        {:error, "timeout: #{operation} timed out after #{timeout}ms"}

      {:error, reason} ->
        target_info = extract_target_info(key)

        {:error,
         "connection_failed: #{target_info}. Please ensure the target component is running. (Details: #{inspect(reason)})"}
    end
  end

  def zenohex_reply(zenoh_query, key, term) do
    {:ok, payload} = encode(term)
    Zenohex.Query.reply(zenoh_query, key, payload)
  end

  def zenohex_put(session_id, key, term) do
    {:ok, payload} = encode(term)
    Zenohex.Session.put(session_id, key, payload)
  end

  defp extract_operation_description(key) do
    cond do
      String.contains?(key, "/register/engine/") ->
        relay_name = extract_target_name(key)
        "Registering engine to relay '#{relay_name}'"

      true ->
        "Operation on '#{key}'"
    end
  end

  defp extract_target_info(key) do
    cond do
      String.contains?(key, "/register/engine/") ->
        relay_name = extract_target_name(key)
        "Relay '#{relay_name}' may not be running"

      true ->
        "Target component may not be running"
    end
  end

  defp extract_target_name(key) do
    key
    |> String.split("/")
    |> List.last()
  end

  def encode(term) do
    {:ok, :erlang.term_to_binary(term)}
  end

  def decode(payload) when is_binary(payload) do
    # We cannot pass the `safe` option because it causes an ArgumentError
    # when the binary contains module object code.
    {:ok, :erlang.binary_to_term(payload)}
  rescue
    ArgumentError -> {:error, "decode_failed"}
  end

  def exec_func({m, f, args} = mfargs) do
    {:ok, apply(m, f, args)}
  rescue
    UndefinedFunctionError ->
      {:error, "function_not_defined: #{inspect(mfargs)}"}

    unexpected_error ->
      {:error, "execution_failed: #{inspect(unexpected_error)}"}
  end

  def validate_module_saved(module) do
    if Code.ensure_loaded?(module) do
      :ok
    else
      {:error, "module_not_saved"}
    end
  end

  defp add_send_measurements(key, %{measurements: measurements} = send_term) do
    key =
      if String.contains?(key, "/register/engine/") do
        :engine_send_timestamp_to_relay
      else
        raise "Unexpected condition reached"
      end

    measurements = Map.put(measurements, key, System.system_time(:millisecond))
    {:ok, %{send_term | measurements: measurements}}
  end

  defp add_recv_measurements(key, recv_term) do
    key =
      if String.contains?(key, "/register/engine/") do
        :engine_recv_timestamp_from_relay
      else
        raise "Unexpected condition reached"
      end

    case recv_term do
      {:ok, %{data: data, measurements: measurements}} ->
        measurements = Map.put(measurements, key, System.system_time(:millisecond))
        {:ok, %{data: data, measurements: measurements}}

      error ->
        error
    end
  end
end
