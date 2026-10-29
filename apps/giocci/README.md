# Giocci

Giocci is an Elixir library for interacting with the GiocciPlatform. It allows you to save Elixir modules to remote engines and execute their functions across the network.

## Installation

Add `giocci` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:giocci, "~> 0.6.4"}
  ]
end
```

## Configuration

### config/config.exs

Configure Giocci in your `config/config.exs`:

```elixir
config :giocci,
  zenoh_config_file_path: "path/to/zenoh.json5",  # Path to Zenoh configuration
  client_name: "my_client",                       # Shared namespace for this client name
  key_prefix: ""                                  # Optional key prefix for Zenoh keys
```

### zenoh.json5

See Zenoh [DEFAULT_CONFIG.json5](https://github.com/eclipse-zenoh/zenoh/blob/1.10.2/DEFAULT_CONFIG.json5) for detailed options.

### Environment Variables

- `ZENOHD_CONNECT_ENDPOINTS` (optional): Comma-separated list of Zenoh endpoints to connect to (e.g., `"tcp/192.168.1.100:7447"` or `"tcp/192.168.1.100:7447,tcp/192.168.1.101:7447"`). When set, this overrides the `connect.endpoints` value in `zenoh.json5` (note that a setting consisting solely of spaces or commas will be ignored since Giocci Client requires zenohd's endpoints setting to operate). This is useful when managing your configuration with version control, as it avoids storing IP addresses in tracked files.

## Usage

### 1. Register Client

Register your client with a relay:

```elixir
:ok = Giocci.register_client("giocci_relay")
```

### 2. Save Module

Here, the following module is assumed to be in your Elixir project.

```elixir
defmodule MyModule do
  def add(a, b), do: a + b
  def multiply(a, b), do: a * b
end
```

Save an Elixir module to the relay (which distributes it to engines):

```elixir
:ok = Giocci.save_module("giocci_relay", MyModule)
```

On a shared Engine, saving another implementation with the same module name
can replace this code. See [Current behavior and limitations](#current-behavior-and-limitations).

If the relay loses the client registration (for example after a restart),
`save_module/3` returns `{:error, "client_not_registered"}` and logs a warning.
Call `Giocci.register_client("giocci_relay")` again before retrying; the
client does not re-register automatically.

### 3. Execute Function (Synchronous)

Execute a function on a remote engine:

```elixir
# Execute MyModule.add(1, 2)
result = Giocci.exec_func("giocci_relay", {MyModule, :add, [1, 2]})
# => 3
```

### 4. Execute Function (Asynchronous)

Execute a function asynchronously and receive the result as a message:

```elixir
defmodule MyServer do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    # Execute async function
    :ok = Giocci.exec_func_async("giocci_relay", {MyModule, :multiply, [3, 4]}, self())
    {:ok, %{}}
  end

  def handle_info({:giocci, result}, state) do
    IO.puts("Received result: #{result}")
    # => "Received result: 12"
    {:noreply, state}
  end
end
```

### 5. Unregister Client

Unregister this client name from a relay explicitly when it is no longer
needed:

```elixir
:ok = Giocci.unregister_client("giocci_relay")
```

Unregistration is explicit and safe to repeat. It does not delete saved
modules or unload them from engines. Register again with the same client name
to resume saving and execution without re-saving modules; relay storage is in
memory and does not survive a restart.

Unregistering a name shared by multiple client instances affects all of them.
See `Giocci.unregister_client/2` for failure and in-flight request behavior.

### Options

All functions accept an optional `opts` keyword list:

- `:timeout` - Request timeout in milliseconds (default: 5000)
- `:measure_to` - PID to receive measurement timestamps as `{:giocci_measurements, timestamps}`

Example:

```elixir
Giocci.exec_func("giocci_relay", {MyModule, :add, [1, 2]}, timeout: 10_000)
```

## Additional Features

### Saving dynamically defined modules

For a module defined interactively in IEx or Livebook, or compiled with
`Code.compile_string/2` without writing a BEAM file, opt in to retaining its
compiled BEAM:

```elixir
defmodule MyDynamicModule do
  use Giocci.DynamicModule

  def add(a, b), do: a + b
end

:ok = Giocci.save_module("giocci_relay", MyDynamicModule)
```

Include `use Giocci.DynamicModule` each time the module is redefined. If it
is omitted on redefinition, `save_module` returns
`{:error, "dynamic_module_stale"}` rather than sending the previous BEAM.
Without the opt-in or a BEAM file, it returns
`{:error, "get_object_code_failed"}`. One BEAM per opted-in module is retained
until the VM exits; redefining that module replaces the retained BEAM. Regular
Mix modules need no opt-in.

### Inspecting the platform

Use `Giocci.Inspect` to check this client's Zenoh connection, relay and engine
registrations, saved modules, runtime information, and ping responses.

```elixir
Giocci.Inspect.connection_info()
Giocci.Inspect.list_relays()
Giocci.Inspect.list_modules("giocci_relay")
Giocci.Inspect.ping_engine("giocci_engine")
```

`list_relays/1` can return partial results with `:warn`. See the
`Giocci.Inspect` API documentation for return values and query options.

## Running with Docker (for Testing)

The Docker environment is provided for troubleshooting network connectivity issues between Giocci, GiocciRelay, and GiocciEngine.

### Prerequisites

- Docker and Docker Compose installed
- A running Zenoh daemon (zenohd)
- A running GiocciRelay instance
- A running GiocciEngine instance

### Setup and Testing

1. Navigate to the giocci directory:
   ```bash
   cd apps/giocci
   ```

2. Edit `config/zenoh.json5` to configure Zenoh connection:
   - This file is copied from [the official Zenoh repository](https://github.com/eclipse-zenoh/zenoh/blob/main/DEFAULT_CONFIG.json5) and modifiled for Giocci (check `MODIFIED_FOR_GIOCCI` label in the file).
   - Set `connect.endpoints` to your Zenohd server address (e.g., `["tcp/192.168.1.100:7447"]`)
   - Alternatively, set the `ZENOHD_CONNECT_ENDPOINTS` environment variable (e.g., `ZENOHD_CONNECT_ENDPOINTS=tcp/192.168.1.100:7447`) to avoid storing the IP address in the config file

3. Edit `config/giocci.exs` to configure the client:
   - Set `client_name` to identify this client instance
   - Ensure `relay_name` in the config matches your running GiocciRelay instance

4. Start the client with IEx shell:
   ```bash
   docker compose run --rm giocci
   ```

5. In the IEx shell, run the test:
   ```elixir
   iex(giocci@hostname)> Giocci.Sample.Test.exec("giocci_relay")
   ```

   Expected output:
   ```
   2026-01-14 05:33:10.528 [info] register_client/1 success!
   2026-01-14 05:33:10.537 [info] save_module/2 success!
   2026-01-14 05:33:10.555 [info] exec_func/2 success!
   2026-01-14 05:33:10.556 [info] exec_func_async/3 success!
   :ok
   ```

This test verifies:
- Client registration with the relay
- Module saving and distribution to engines
- Synchronous function execution
- Asynchronous function execution and result delivery

### Troubleshooting

If the test fails or times out, check the logs of your running services:

```bash
# Check GiocciRelay logs
docker compose logs -f giocci_relay

# Check GiocciEngine logs
docker compose logs -f giocci_engine

# Check Zenohd logs
docker compose logs -f zenohd
```

Common issues:
- **Connection timeout**: Verify `connect.endpoints` in `config/zenoh.json5` is correct
- **Relay not found**: Ensure the relay name matches between client config and running relay
- **Key prefix mismatch**: Verify `key_prefix` is the same across client, relay, and engine configurations
- **Module not loaded**: Check engine logs for module loading errors

## Current behavior and limitations

- Relay stores modules by client name, but Engines load them into a shared
  BEAM VM under their original module names. Different client names do not
  isolate code or runtime state: saving a different implementation with the
  same module name can replace the code used by another client on that Engine.
- Execution checks whether the module is loaded on the selected Engine, not
  whether this client saved it. A registered client may execute a module
  loaded by another client; client names are not access control. Clients
  using the same name also share saved modules and registration state.
- By default, a relay selects Engines round-robin. Consecutive calls from
  the same client may run on different Engines, whose runtime state is not
  shared.
- `save_module/3` stores the BEAM at the relay before distributing it.
  Returning `:ok` does not guarantee that every Engine loaded it; a timeout
  may also occur after the relay stored it.
- `exec_func_async/4` returning `:ok` does not guarantee a result. If
  execution fails or the result times out, no error message is sent to the
  result receiver.

## API Reference

See the [HexDocs](https://hexdocs.pm/giocci/api-reference.html) for detailed API documentation.

## Architecture

For information about the overall GiocciPlatform architecture and communication flows, see the [main README](https://github.com/biyooon-ex/giocci_platform/blob/main/README.md).
