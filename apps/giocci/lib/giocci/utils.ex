defmodule Giocci.Utils do
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
  rescue
    ArgumentError -> {:error, "zenohex_error: badarg"}
  end

  def zenohex_put(session_id, key, send_term) do
    {:ok, payload} = encode(send_term)
    Zenohex.Session.put(session_id, key, payload)
  end

  defp extract_operation_description(key) do
    name = extract_target_name(key)

    cond do
      String.contains?(key, "/register/client/") -> "Registering client to relay '#{name}'"
      String.contains?(key, "/save_module/client/") -> "Saving module via relay '#{name}'"
      String.contains?(key, "/inquiry_engine/client/") -> "Inquiring engine from relay '#{name}'"
      String.contains?(key, "/exec_func/client/") -> "Executing function on engine '#{name}'"
      true -> "Operation on '#{key}'"
    end
  end

  defp extract_target_info(key) do
    name = extract_target_name(key)

    cond do
      String.contains?(key, "/register/client/") -> "Relay '#{name}' may not be running"
      String.contains?(key, "/save_module/client/") -> "Relay '#{name}' may not be running"
      String.contains?(key, "/inquiry_engine/client/") -> "Relay '#{name}' may not be running"
      String.contains?(key, "/exec_func/client/") -> "Engine '#{name}' may not be running"
      true -> "Target component may not be running"
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
    # We pass the `safe` option to protect user's Erlang VM.
    {:ok, :erlang.binary_to_term(payload, [:safe])}
  rescue
    ArgumentError -> {:error, "decode_failed: payload may contain unknown atoms or unsafe terms"}
  end

  defp add_send_measurements(key, %{measurements: measurements} = send_term) do
    key =
      cond do
        String.contains?(key, "/register/client/") -> :client_send_timestamp_to_relay
        String.contains?(key, "/save_module/client/") -> :client_send_timestamp_to_relay
        String.contains?(key, "/inquiry_engine/client/") -> :client_send_timestamp_to_relay
        String.contains?(key, "/exec_func/client/") -> :client_send_timestamp_to_engine
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
            String.contains?(key, "/register/client/") -> :client_recv_timestamp_from_relay
            String.contains?(key, "/inquiry_engine/client/") -> :client_recv_timestamp_from_relay
            String.contains?(key, "/exec_func/client/") -> :client_recv_timestamp_from_engine
            true -> raise "Unexpected condition reached"
          end

        measurements = Map.put(measurements, key, System.system_time(:millisecond))
        {:ok, %{data: data, measurements: measurements}}

      {:ok, list} when is_list(list) ->
        key =
          if String.contains?(key, "/save_module/client/") do
            :client_recv_timestamp_from_relay
          else
            raise "Unexpected condition reached"
          end

        Enum.map(list, fn
          {:ok, %{data: data, measurements: measurements}} ->
            measurements = Map.put(measurements, key, System.system_time(:millisecond))
            {:ok, %{data: data, measurements: measurements}}

          error ->
            error
        end)

      recv_term ->
        recv_term
    end
  end
end
