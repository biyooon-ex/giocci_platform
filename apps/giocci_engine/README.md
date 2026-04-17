# GiocciEngine

GiocciEngine is the execution engine component of the GiocciPlatform that receives modules from Giocci (via GiocciRelay) and executes their functions on demand. It loads modules dynamically and processes both synchronous and asynchronous function execution requests from clients.

## Prerequisites

- Docker and Docker Compose installed on your server
- Access to a Zenoh daemon (zenohd) endpoint
- A running GiocciRelay instance

## How to run giocci_engine on your server

1. Download `giocci_engine.zip` from the [GiocciPlatform Releases page](https://github.com/biyooon-ex/giocci_platform/releases) and extract it in your working directory (`v0.5.1` and later)
   - The zip contains `./config/` and `./docker-compose.yml`
   - For stable operation, we recommend using the same release version across API and containers.

2. Edit `config/zenoh.json5` to configure Zenoh connection:
   - This file is copied from [the official Zenoh repository](https://github.com/eclipse-zenoh/zenoh/blob/main/DEFAULT_CONFIG.json5) and modified for Giocci (check `MODIFIED_FOR_GIOCCI` label in the file).
   - Set `connect.endpoints` to your Zenohd server address (e.g., `["tcp/192.168.1.100:7447"]`)
   - Alternatively, set the `ZENOHD_CONNECT_ENDPOINTS` environment variable (e.g., `ZENOHD_CONNECT_ENDPOINTS=tcp/192.168.1.100:7447`) to avoid storing the IP address in the config file

3. Edit `config/giocci_engine.exs` to configure the engine:
   - Set `engine_name` to identify this engine instance (e.g., `"my_engine"`)
   - Set `relay_name` to match your GiocciRelay instance name
   - Set `zenoh_config_file_path` if you changed the config file location

4. Start the engine:
   ```bash
   docker compose up -d giocci_engine
   ```

5. Check logs:
   ```bash
   docker compose logs -f giocci_engine
   ```

## Managing the engine

Stop the engine:
```bash
docker compose down giocci_engine
```

Restart the engine:
```bash
docker compose restart giocci_engine
```

Update to the latest version:
```bash
docker compose pull giocci_engine
docker compose up -d giocci_engine
```

## Configuration

### config/giocci_engine.exs

- `zenoh_config_file_path`: Path to the Zenoh configuration file (default: `"/app/zenoh.json5"`)
  - **Important**: This path must match the volume mount destination in `docker-compose.yml`
  - If you change this path, update the corresponding volume mount in `docker-compose.yml`
- `engine_name`: Unique identifier for this engine instance
- `relay_name`: Name of the GiocciRelay instance to connect to

### config/zenoh.json5

See Zenoh [DEFAULT_CONFIG.json5](https://github.com/eclipse-zenoh/zenoh/blob/1.9.0/DEFAULT_CONFIG.json5) for detailed options.

### Environment Variables

- `ZENOHD_CONNECT_ENDPOINTS` (optional): Comma-separated list of Zenoh endpoints to connect to (e.g., `"tcp/192.168.1.100:7447"` or `"tcp/192.168.1.100:7447,tcp/192.168.1.101:7447"`). When set, this overrides the `connect.endpoints` value in `zenoh.json5` (note that a setting consisting solely of spaces or commas will be ignored since Giocci Engine requires zenohd's endpoints setting to operate). This is useful when managing your configuration with version control, as it avoids storing IP addresses in tracked files.
