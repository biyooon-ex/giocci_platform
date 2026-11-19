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
        flash_offset: 0x290000
      ],
      aliases: [
        # Without --no-start, running mix test from the umbrella root starts all
        # umbrella apps.
        test: ["test --no-start"],
        flash: [
          "atomvm.packbeam",
          "atomvm.esp32.flash --port /dev/ttyACM0 --baud 921600"
        ]
      ],
      description: description(),
      package: package(),
      docs: docs()
    ]
  end

  def cli do
    [default_target: :avm_esp32]
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
      {:atomvm, "~> 0.7.0-beta.0", optional: true, runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false, warn_if_outdated: true},
      {:exatomvm, github: "atomvm/exatomvm", only: :dev, runtime: false, override: true},
      {:pythonx, "~> 0.4.0"},
      {:zenohex_pico, "== 0.1.0-alpha.3"}
    ]
  end

  defp description do
    "Client library for GiocciPlatform (resource-permeating computing platform for wide-area distributed systems)"
  end

  defp package do
    [
      # These are the default files included in the package
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*),
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/biyooon-ex/giocci_platform"}
    ]
  end

  defp docs do
    [
      extras: ["README.md"],
      main: "readme"
    ]
  end
end
