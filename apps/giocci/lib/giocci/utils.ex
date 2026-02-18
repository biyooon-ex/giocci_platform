defmodule Giocci.Utils do
  @moduledoc false

  def zenohex_get(session_id, key, timeout, send_term, measure?) do
    send_term = if measure?, do: send_measure(key, send_term), else: send_term

    {:ok, payload} = encode(send_term)

    case Zenohex.Session.get(session_id, key, timeout, payload: payload) do
      {:ok, [%Zenohex.Sample{payload: payload}]} ->
        {:ok, recv_term} = decode(payload)

        recv_term = if measure?, do: recv_measure(key, recv_term), else: recv_term

        {:ok, recv_term}

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
    cond do
      String.contains?(key, "/register/client/") ->
        relay_name = extract_target_name(key)
        "Registering client to relay '#{relay_name}'"

      String.contains?(key, "/save_module/client/") ->
        relay_name = extract_target_name(key)
        "Saving module via relay '#{relay_name}'"

      String.contains?(key, "/inquiry_engine/client/") ->
        relay_name = extract_target_name(key)
        "Inquiring engine from relay '#{relay_name}'"

      String.contains?(key, "/exec_func/client/") ->
        engine_name = extract_target_name(key)
        "Executing function on engine '#{engine_name}'"

      true ->
        "Operation on '#{key}'"
    end
  end

  defp extract_target_info(key) do
    cond do
      String.contains?(key, "/register/client/") ->
        relay_name = extract_target_name(key)
        "Relay '#{relay_name}' may not be running"

      String.contains?(key, "/save_module/client/") ->
        relay_name = extract_target_name(key)
        "Relay '#{relay_name}' may not be running"

      String.contains?(key, "/inquiry_engine/client/") ->
        relay_name = extract_target_name(key)
        "Relay '#{relay_name}' may not be running"

      String.contains?(key, "/exec_func/client/") ->
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
    # We pass the `safe` option to protect user's Erlang VM.
    {:ok, :erlang.binary_to_term(payload, [:safe])}
  rescue
    ArgumentError -> {:error, "decode_failed: payload may contain unknown atoms or unsafe terms"}
  end

  defp send_measure(key, send_term) do
    cond do
      String.contains?(key, "/register/client/") ->
        Map.put(send_term, :client_send_timestamp_to_relay, System.system_time(:millisecond))

      true ->
        send_term
    end
  end

  defp recv_measure(key, recv_term) do
    case recv_term do
      {:ok, map} ->
        map =
          cond do
            String.contains?(key, "/register/client/") ->
              Map.put(map, :client_recv_timestamp_from_relay, System.system_time(:millisecond))

            true ->
              map
          end

        {:ok, map}

      recv_term ->
        recv_term
    end
  end
end
