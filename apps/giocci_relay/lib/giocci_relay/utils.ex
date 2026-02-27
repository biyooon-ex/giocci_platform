defmodule GiocciRelay.Utils do
  @moduledoc false

  def zenohex_get(session_id, key, timeout, send_term) do
    {:ok, payload} = encode(add_send_measurements(key, send_term))

    case Zenohex.Session.get(session_id, key, timeout, payload: payload) do
      {:ok, [%Zenohex.Sample{payload: payload}]} ->
        case decode(payload) do
          {:ok, recv_term} -> {:ok, add_recv_measurements(key, recv_term)}
          error -> error
        end

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

  defp extract_operation_description(key) do
    cond do
      String.contains?(key, "/save_module/relay/") ->
        engine_name = extract_target_name(key)
        "Saving module to engine '#{engine_name}'"

      true ->
        "Operation on '#{key}'"
    end
  end

  defp extract_target_info(key) do
    cond do
      String.contains?(key, "/save_module/relay/") ->
        engine_name = extract_target_name(key)
        "Engine '#{engine_name}' may not be running"

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

  def decode(payload) do
    # We cannot pass the `safe` option because it causes an ArgumentError
    # when the binary contains module object code.
    {:ok, :erlang.binary_to_term(payload)}
  rescue
    ArgumentError -> {:error, "decode_failed"}
  end

  defp add_send_measurements(key, %{measurements: measurements} = send_term) do
    key =
      cond do
        String.contains?(key, "/save_module/relay/") -> :relay_send_timestamp_to_engine
        true -> raise "Unexpected condition reached"
      end

    measurements = Map.put(measurements, key, System.system_time(:millisecond))
    %{send_term | measurements: measurements}
  end

  defp add_recv_measurements(key, recv_term) do
    case recv_term do
      {:ok, %{data: data, measurements: measurements}} ->
        key =
          cond do
            String.contains?(key, "/save_module/relay/") -> :relay_recv_timestamp_from_engine
            true -> raise "Unexpected condition reached"
          end

        measurements = Map.put(measurements, key, System.system_time(:millisecond))
        {:ok, %{data: data, measurements: measurements}}

      recv_term ->
        recv_term
    end
  end
end
