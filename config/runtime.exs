import Config

config :logger, :default_formatter,
  colors: [enabled: false],
  format: "\n$date $time $metadata[$level] $message\n"

config :logger, :default_handler,
  config: [
    file: ~c"log/giocci.log",
    filesync_repeat_interval: 5000,
    file_check: 5000,
    max_no_bytes: 10_000_000,
    max_no_files: 5,
    compress_on_rotate: true
  ]
