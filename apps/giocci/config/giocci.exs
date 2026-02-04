# This config is an example for Giocci Docker image
import Config

config :logger, :default_formatter,
  colors: [enabled: false],
  format: "\n$date $time $metadata[$level] $message\n"

# Path to Zenoh configuration in docker image
# Important: This must match the volume mount destination in docker-compose.yml
config :giocci, zenoh_config_file_path: "/app/zenoh.json5"

# Unique client identifier
config :giocci, client_name: "giocci"

# Optional key prefix for Zenoh keys
# Important: This must match the key_prefix in relay and engine configurations
config :giocci, key_prefix: ""
