defmodule Giocci do
  @moduledoc """
  Client API for Giocci.
  """

  @doc """
  Register this client to a relay.

  Options:
    - `:timeout` - Client call timeout in milliseconds.
    - `:measure_to` - When set to a pid, sends measurement timestamps as `{:giocci_measurements, timestamps}` to that process.
  """
  @spec register_client(String.t(), keyword()) :: :ok | {:error, reason :: term()}
  defdelegate register_client(relay_name, opts \\ []), to: Giocci.Worker

  @doc """
  Unregister this client's name from a relay without deleting saved modules.

  An already unregistered name is treated as success. A failed request does
  not remove the relay from this client's local registration list; retrying
  is safe even if the relay processed the request before the reply was lost.
  Other clients using the same name are also affected by unregistration.
  Running executions are not cancelled or waited for.

  Options:
    - `:timeout` - Client call timeout in milliseconds.
    - `:measure_to` - When set to a pid, sends measurement timestamps as `{:giocci_measurements, timestamps}` to that process.
  """
  @spec unregister_client(String.t(), keyword()) :: :ok | {:error, reason :: term()}
  defdelegate unregister_client(relay_name, opts \\ []), to: Giocci.Worker

  @doc """
  Save a module to the relay.

  For modules compiled without a BEAM file, use `Giocci.DynamicModule` inside
  the module definition. Redefinitions must use it again; otherwise this
  function returns `{:error, "dynamic_module_stale"}` instead of sending the
  previously retained BEAM.

  Options:
    - `:timeout` - Client call timeout in milliseconds.
    - `:measure_to` - When set to a pid, sends measurement timestamps as `{:giocci_measurements, timestamps}` to that process.
  """
  @spec save_module(String.t(), module(), keyword()) :: :ok | {:error, reason :: term()}
  defdelegate save_module(relay_name, module, opts \\ []), to: Giocci.Worker

  @doc """
  Execute a function on an engine via the relay.

  Options:
    - `:timeout` - Client call timeout in milliseconds.
    - `:measure_to` - When set to a pid, sends measurement timestamps as `{:giocci_measurements, timestamps}` to that process.
  """
  @spec exec_func(String.t(), tuple(), keyword()) :: result :: term()
  defdelegate exec_func(relay_name, mfargs, opts \\ []), to: Giocci.Worker

  @doc """
  Execute a function asynchronously and send the result to `server`.

  The result is delivered to `server` as `{:giocci, result}`.

  Options:
    - `:timeout` - Client call timeout in milliseconds.
    - `:measure_to` - When set to a pid, sends measurement timestamps as `{:giocci_measurements, timestamps}` to that process.
  """
  @spec exec_func_async(String.t(), tuple(), GenServer.server(), keyword()) ::
          :ok | {:error, reason :: term()}
  defdelegate exec_func_async(relay_name, mfargs, server, opts \\ []), to: Giocci.Worker
end
