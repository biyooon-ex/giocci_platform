# This config is an example for GiocciRealy Docker image
import Config

config :logger, :default_formatter,
  colors: [enabled: false],
  format: "\n$date $time $metadata[$level] $message\n"

# Path to Zenoh configuration in docker image
# Important: This must match the volume mount destination in docker-compose.yml
config :giocci_relay, zenoh_config_file_path: "/app/zenoh.json5"

# Unique relay identifier
config :giocci_relay, relay_name: "giocci_relay"

# Optional key prefix for Zenoh keys
# Important: This must match the key_prefix in client and engine configurations
# config :giocci_relay, key_prefix: ""
