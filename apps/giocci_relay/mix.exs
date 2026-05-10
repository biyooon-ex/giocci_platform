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

  defp version do
    versions_path = Path.join([__DIR__, "../..", "VERSIONS"])

    if File.exists?(versions_path) do
      versions_path
      |> File.read!()
      |> String.split("\n")
      |> Enum.find_value(fn
        "PROJECT_VERSION=" <> version -> String.trim(version)
        _ -> false
      end) || raise("PROJECT_VERSION not found in VERSIONS")
    else
      if allow_missing_versions?() do
        fallback_version = "0.0.0"

        IO.warn(
          "VERSIONS file not found at #{versions_path}; using fallback version #{fallback_version}"
        )

        fallback_version
      else
        raise("VERSIONS file not found at #{versions_path}")
      end
    end
  end

  defp allow_missing_versions? do
    System.get_env("MIX_ALLOW_MISSING_VERSIONS") == "true" ||
      System.get_env("DEPENDABOT") == "true" ||
      (System.get_env("GITHUB_ACTIONS") == "true" &&
         System.get_env("GITHUB_ACTOR") == "dependabot[bot]")
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
      {:zenohex, "== 0.9.0"}
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
end
