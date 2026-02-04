defmodule Giocci.Utils do
  @moduledoc false

  def zenohex_get(session_id, key, timeout, payload) do
    case Zenohex.Session.get(session_id, key, timeout, payload: payload) do
      {:ok, [%Zenohex.Sample{payload: payload}]} ->
        {:ok, payload}

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
end
