# GiocciRelay

GiocciRelay is a relay component for the GiocciPlatform that forwards messages between Zenoh networks.

## Prerequisites

- Docker and Docker Compose installed on your server
- Access to a Zenoh daemon (zenohd) endpoint

## How to run giocci_relay on your server

1. Download `./config` and `./docker-compose.yml` to your working directory

2. Edit `config/zenoh.json5` to configure Zenoh connection:
   - This file is copied from [the official Zenoh repository](https://github.com/eclipse-zenoh/zenoh/blob/main/DEFAULT_CONFIG.json5) and modifiled for Giocci (check `MODIFIED_FOR_GIOCCI` label in the file).
   - Set `connect.endpoints` to your Zenohd server address (e.g., `["tcp/192.168.1.100:7447"]`)
   - Alternatively, set the `ZENOHD_CONNECT_ENDPOINTS` environment variable (e.g., `ZENOHD_CONNECT_ENDPOINTS=tcp/192.168.1.100:7447`) to avoid storing the IP address in the config file

3. Edit `config/giocci_relay.exs` to configure the relay:
   - Set `relay_name` to identify this relay instance (e.g., `"my_relay"`)
   - Set `zenoh_config_file_path` if you changed the config file location

4. Start the relay:
   ```bash
   docker compose up -d giocci_relay
   ```

5. Check logs:
   ```bash
   docker compose logs -f giocci_relay
   ```

## Managing the relay

Stop the relay:
```bash
docker compose down giocci_relay
```

Restart the relay:
```bash
docker compose restart giocci_relay
```

Update to the latest version:
```bash
docker compose pull giocci_relay
docker compose up -d giocci_relay
```

## Configuration

### config/giocci_relay.exs

- `zenoh_config_file_path`: Path to the Zenoh configuration file (default: `"/app/zenoh.json5"`)
  - **Important**: This path must match the volume mount destination in `docker-compose.yml`
  - If you change this path, update the corresponding volume mount in `docker-compose.yml`
- `relay_name`: Unique identifier for this relay instance

### config/zenoh.json5

See Zenoh [DEFAULT_CONFIG.json5](https://github.com/eclipse-zenoh/zenoh/blob/1.9.0/DEFAULT_CONFIG.json5) for detailed options.

### Environment Variables

- `ZENOHD_CONNECT_ENDPOINTS` (optional): Comma-separated list of Zenoh endpoints to connect to (e.g., `"tcp/192.168.1.100:7447"` or `"tcp/192.168.1.100:7447,tcp/192.168.1.101:7447"`). When set, this overrides the `connect.endpoints` value in `zenoh.json5` (note that a setting consisting solely of spaces or commas will be ignored since Giocci Relay requires zenohd's endpoints setting to operate). This is useful when managing your configuration with version control, as it avoids storing IP addresses in tracked files.
