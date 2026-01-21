defmodule GiocciClient.MixProject do
  use Mix.Project

  def project do
    [
      app: :giocci_client,
      version: "0.3.0",
      build_path: "./_build",
      config_path: "./config/config.exs",
      deps_path: "./deps",
      lockfile: "./mix.lock",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      releases: releases(),
      description: description(),
      package: package(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {GiocciClient.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:zenohex, "== 0.7.2"},
      {:mock, "~> 0.3.0", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp description() do
    "Client library for GiocciPlatform (computational resource permeating wide-area distributed system towards the B5G era)"
  end

  defp package() do
    [
      # These are the default files included in the package
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*),
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/biyooon-ex/giocci_platform"}
    ]
  end

  defp docs() do
    [
      extras: ["README.md"],
      main: "readme"
    ]
  end

  defp aliases do
    [
      test: ["test --no-start"]
    ]
  end

  def releases do
    [
      giocci_client: [
        include_executables_for: [:unix],
        applications: [giocci_client: :permanent],
        config_providers: [
          {Config.Reader, {:system, "RELEASE_ROOT", "/giocci_client.exs"}}
        ]
      ]
    ]
  end
end
