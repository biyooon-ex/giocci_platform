defmodule GiocciPico.MixProject do
  use Mix.Project

  def project do
    [
      app: :giocci_pico,
      version: "0.1.0",
      build_path: "./_build",
      config_path: "./config/config.exs",
      deps_path: "./deps",
      lockfile: "./mix.lock",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      atomvm: [
        start: GiocciPico.Sample.Test,
        flash_offset: 0x250000
      ],
      aliases: [
        flash: [
          "atomvm.packbeam",
          "atomvm.esp32.flash --port /dev/ttyACM0 --baud 921600"
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:exatomvm,
       git: "https://github.com/atomvm/exatomvm.git",
       ref: "a99323a1054adda1ec00e9997bc41bc7317a3826"},
      {:zenohex_pico,
       git: "git@github.com:biyooon-ex/zenohex_pico.git",
       ref: "a758ed29af87413e5d320ac6a7776fab8778e5a0"}
    ]
  end
end
