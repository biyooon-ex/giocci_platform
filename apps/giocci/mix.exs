defmodule Giocci.MixProject do
  use Mix.Project

  def project do
    [
      app: :giocci,
      version: version(),
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
      mod: {Giocci.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:zenohex, "== 0.9.0"},
      {:mock, "~> 0.3.0", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp description() do
    "Client library for GiocciPlatform (resource-permeating computing platform for wide-area distributed systems)"
  end

  defp package() do
    [
      # These are the default files included in the package
      files: ~w(lib .formatter.exs mix.exs README* LICENSE* VERSIONS),
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

  defp version do
    local_versions = Path.join(__DIR__, "VERSIONS")
    parent_versions = Path.join([__DIR__, "../..", "VERSIONS"])

    read_version(local_versions) ||
      read_version(parent_versions) ||
      fallback_version(local_versions)
  end

  defp read_version(path) do
    if File.exists?(path) do
      path
      |> File.read!()
      |> String.split("\n")
      |> Enum.find_value(fn
        "PROJECT_VERSION=" <> version -> String.trim(version)
        _ -> nil
      end)
    end
  end

  defp fallback_version(versions_path) do
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

  defp allow_missing_versions? do
    System.get_env("MIX_ALLOW_MISSING_VERSIONS") == "true" ||
      System.get_env("DEPENDABOT") == "true" ||
      (System.get_env("GITHUB_ACTIONS") == "true" &&
         System.get_env("GITHUB_ACTOR") == "dependabot[bot]")
  end

  def releases do
    [
      giocci: [
        include_executables_for: [:unix],
        applications: [giocci: :permanent],
        config_providers: [
          {Config.Reader, {:system, "RELEASE_ROOT", "/giocci.exs"}}
        ]
      ]
    ]
  end
end
