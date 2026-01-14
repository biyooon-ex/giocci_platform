# This config is an example for Giocci Client Docker image
import Config

config :logger, :default_formatter,
  colors: [enabled: false],
  format: "\n$date $time $metadata[$level] $message\n"

config :giocci_client, zenoh_config_file_path: "/app/zenoh.json"
config :giocci_client, client_name: "giocci_client"
