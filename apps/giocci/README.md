# Giocci

Giocci is an Elixir library for interacting with the GiocciPlatform. It allows you to save Elixir modules to remote engines and execute their functions across the network.

## Installation

Add `giocci` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:giocci, "~> 0.3.0"}
  ]
end
```

## Configuration

Configure Giocci in your `config/config.exs`:

```elixir
config :giocci,
  zenoh_config_file_path: "path/to/zenoh.json5",  # Path to Zenoh configuration
  client_name: "my_client",                       # Unique client identifier
  key_prefix: ""                                  # Optional key prefix for Zenoh keys
```

### Configuration Options

- `zenoh_config_file_path` (required): Path to the Zenoh configuration file
- `client_name` (required): Unique name to identify this client instance
- `key_prefix` (optional): Prefix prepended to all Zenoh key expressions (default: `""`)

## Usage

### 1. Register Client

Register your client with a relay:

```elixir
:ok = Giocci.register_client("my_relay")
```

### 2. Save Module

Save an Elixir module to the relay (which distributes it to engines):

```elixir
defmodule MyModule do
  def add(a, b), do: a + b
  def multiply(a, b), do: a * b
end

:ok = Giocci.save_module("my_relay", MyModule)
```

### 3. Execute Function (Synchronous)

Execute a function on a remote engine:

```elixir
# Execute MyModule.add(1, 2)
result = Giocci.exec_func("my_relay", {MyModule, :add, [1, 2]})
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
    :ok = Giocci.exec_func_async("my_relay", {MyModule, :multiply, [3, 4]}, self())
    {:ok, %{}}
  end

  def handle_info({:giocci, result}, state) do
    IO.puts("Received result: #{result}")
    # => "Received result: 12"
    {:noreply, state}
  end
end
```

### Options

All functions accept an optional `opts` keyword list:

- `:timeout` - Request timeout in milliseconds (default: 5000)

Example:

```elixir
Giocci.exec_func("my_relay", {MyModule, :add, [1, 2]}, timeout: 10_000)
```

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

## API Reference

See the [HexDocs](https://hexdocs.pm/giocci) for detailed API documentation.

## Architecture

For information about the overall GiocciPlatform architecture and communication flows, see the [main README](https://github.com/biyooon-ex/giocci_platform/blob/main/README.md).
