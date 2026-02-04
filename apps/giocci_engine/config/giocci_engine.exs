# This config is an example for GiocciEngine Docker image
import Config

config :logger, :default_formatter,
  colors: [enabled: false],
  format: "\n$date $time $metadata[$level] $message\n"

# Path to Zenoh configuration in docker image
# Important: This must match the volume mount destination in docker-compose.yml
config :giocci_engine, zenoh_config_file_path: "/app/zenoh.json5"

# Unique engine identifier
config :giocci_engine, engine_name: "giocci_engine"

# Optional key prefix for Zenoh keys
# Important: This must match the key_prefix in client and relay configurations
# config :giocci_engine, key_prefix: ""

# Name of the relay to connect to
# Important: This must match the relay_name in the relay configuration
config :giocci_engine, relay_name: "giocci_relay"
