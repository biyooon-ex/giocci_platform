defmodule GiocciEngine.Utils do
  @moduledoc false

  def zenohex_get(session_id, key, timeout, payload) do
    case Zenohex.Session.get(session_id, key, timeout, payload: payload) do
      {:ok, [%Zenohex.Sample{payload: payload}]} ->
        {:ok, payload}

      {:error, :timeout} ->
        {:error, "timeout"}

      {:error, reason} ->
        {:error, "zenohex_error: #{inspect(reason)}"}
    end
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
end
