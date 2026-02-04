# GiocciEngine

GiocciEngine is the execution engine component of the GiocciPlatform that receives modules from Giocci (via GiocciRelay) and executes their functions on demand. It loads modules dynamically and processes both synchronous and asynchronous function execution requests from clients.

## Prerequisites

- Docker and Docker Compose installed on your server
- Access to a Zenoh daemon (zenohd) endpoint
- A running GiocciRelay instance

## How to run giocci_engine on your server

1. Download `./config` and `./docker-compose.yml` to your working directory

2. Edit `config/zenoh.json5` to configure Zenoh connection:
   - This file is copied from [the official Zenoh repository](https://github.com/eclipse-zenoh/zenoh/blob/main/DEFAULT_CONFIG.json5) and modifiled for Giocci (check `MODIFIED_FOR_GIOCCI` label in the file).
   - Set `connect.endpoints` to your Zenohd server address (e.g., `["tcp/192.168.1.100:7447"]`)

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

See Zenoh [DEFAULT_CONFIG.json5](https://github.com/eclipse-zenoh/zenoh/blob/1.7.1/DEFAULT_CONFIG.json5) for detailed options.
