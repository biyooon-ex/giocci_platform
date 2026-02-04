defmodule GiocciEngine.MixProject do
  use Mix.Project

  def project do
    [
      app: :giocci_engine,
      version: "0.3.0",
      build_path: "./_build",
      config_path: "./config/config.exs",
      deps_path: "./deps",
      lockfile: "./mix.lock",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      releases: releases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {GiocciEngine.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:zenohex, "== 0.7.2"}
    ]
  end

  defp aliases do
    [
      test: ["test --no-start"]
    ]
  end

  defp releases do
    [
      giocci_engine: [
        include_executables_for: [:unix],
        applications: [giocci_engine: :permanent],
        config_providers: [
          {Config.Reader, {:system, "RELEASE_ROOT", "/giocci_engine.exs"}}
        ]
      ]
    ]
  end
end
