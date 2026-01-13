import Config

config :logger, :default_formatter,
  colors: [enabled: false],
  format: "\n$date $time $metadata[$level] $message\n"
