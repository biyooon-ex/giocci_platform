defmodule GiocciPico do
  @moduledoc """
  Client API for Giocci platform.
  """

  @type start_link_option ::
          {:zenohex_pico_config, ZenohexPico.Config.t()}
          | {:client_name, String.t()}
          | {:key_prefix, String.t()}

  @doc """
  Starts the client supervisor.

  AtomVM does not support starting GiocciPico as an OTP application, so call
  this function explicitly before using the client API.

  Options:
    - `:zenohex_pico_config` - required
    - `:client_name` - required
    - `:key_prefix` - optional, defaults to `""`
  """
  @spec start_link([start_link_option()]) :: Supervisor.on_start()
  defdelegate start_link(opts), to: GiocciPico.Supervisor

  @doc """
  Register this client to a relay.

  Options:
    - `:timeout` - Client call timeout in milliseconds.
    - `:measure_to` - When set to a pid, sends measurement timestamps as `{:giocci_measurements, timestamps}` to that process.
  """
  @spec register_client(String.t(), keyword()) :: :ok | {:error, reason :: term()}
  defdelegate register_client(relay_name, opts \\ []), to: GiocciPico.Worker

  @doc """
  Save a module to the relay.

  Options:
    - `:timeout` - Client call timeout in milliseconds.
    - `:measure_to` - When set to a pid, sends measurement timestamps as `{:giocci_measurements, timestamps}` to that process.
  """
  @spec save_module(String.t(), module(), keyword()) :: :ok | {:error, reason :: term()}
  defdelegate save_module(relay_name, module, opts \\ []), to: GiocciPico.Worker

  @doc """
  Execute a function on an engine via the relay.

  Options:
    - `:timeout` - Client call timeout in milliseconds.
    - `:measure_to` - When set to a pid, sends measurement timestamps as `{:giocci_measurements, timestamps}` to that process.
  """
  @spec exec_func(String.t(), tuple(), keyword()) :: result :: term()
  defdelegate exec_func(relay_name, mfargs, opts \\ []), to: GiocciPico.Worker
end
