Code.require_file("mix_helpers.exs", Path.join([__DIR__, "../..", "bin"]))

defmodule GiocciRelay.MixProject do
  use Mix.Project

  def project do
    [
      app: :giocci_relay,
      version: version(),
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
      mod: {GiocciRelay.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:zenohex, "== #{zenohex_version()}"}
    ]
  end

  defp aliases do
    [
      test: ["test --no-start"]
    ]
  end

  defp releases do
    [
      giocci_relay: [
        include_executables_for: [:unix],
        applications: [giocci_relay: :permanent],
        config_providers: [
          {Config.Reader, {:system, "RELEASE_ROOT", "/giocci_relay.exs"}}
        ]
      ]
    ]
  end

  defp versions do
    MixHelpers.load_versions!(Path.join([__DIR__, "../..", "VERSIONS"]))
  end

  defp version do
    versions()["PROJECT_VERSION"] || raise("PROJECT_VERSION not found in VERSIONS")
  end

  defp zenohex_version do
    versions()["ZENOHEX_VERSION"] || raise("ZENOHEX_VERSION not found in VERSIONS")
  end
end
