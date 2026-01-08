defmodule GiocciClient do
  @moduledoc """
  Client API for Giocci.
  """

  @doc """
  Register this client to a relay.

  Options:
    - `:timeout` - Client call timeout in milliseconds.
  """
  @spec register_client(String.t(), keyword()) :: :ok | {:error, reason :: term()}
  defdelegate register_client(relay_name, opts \\ []), to: GiocciClient.Worker

  @doc """
  Save a module to the relay.

  Options:
    - `:timeout` - Client call timeout in milliseconds.
  """
  @spec save_module(String.t(), module(), keyword()) :: :ok | {:error, reason :: term()}
  defdelegate save_module(relay_name, module, opts \\ []), to: GiocciClient.Worker

  @doc """
  Execute a function on an engine via the relay.

  Options:
    - `:timeout` - Client call timeout in milliseconds.
  """
  @spec exec_func(String.t(), tuple(), keyword()) :: result :: term()
  defdelegate exec_func(relay_name, mfargs, opts \\ []), to: GiocciClient.Worker

  @doc """
  Execute a function asynchronously and send the result to `server`.

  The result is delivered to `server` as `{:giocci_client, result}`.

  Options:
    - `:timeout` - Client call timeout in milliseconds.
  """
  @spec exec_func_async(String.t(), tuple(), GenServer.server(), keyword()) ::
          :ok | {:error, reason :: term()}
  defdelegate exec_func_async(relay_name, mfargs, server, opts \\ []), to: GiocciClient.Worker
end
