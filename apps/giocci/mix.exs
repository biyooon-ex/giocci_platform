defmodule Giocci.MixProject do
  use Mix.Project

  Code.require_file("mix_helpers.exs", Path.join(__DIR__, "../../bin"))

  @versions_path Path.join([__DIR__, "../..", "VERSIONS"])
  @versions MixHelpers.load_versions!(@versions_path)
  @version @versions["PROJECT_VERSION"] || raise("PROJECT_VERSION not found in VERSIONS")
  @zenohex_version @versions["ZENOHEX_VERSION"] || raise("ZENOHEX_VERSION not found in VERSIONS")

  def project do
    [
      app: :giocci,
      version: @version,
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
      {:zenohex, "== #{@zenohex_version}"},
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
