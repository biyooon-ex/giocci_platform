# This config is an example for Giocci Engine Docker image
import Config

config :logger, :default_formatter,
  colors: [enabled: false],
  format: "\n$date $time $metadata[$level] $message\n"

config :giocci_engine, zenoh_config_file_path: "/app/zenoh.json"
config :giocci_engine, engine_name: "giocci_engine"
config :giocci_engine, relay_name: "giocci_relay"
