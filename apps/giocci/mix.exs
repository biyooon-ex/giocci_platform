defmodule Giocci.MixProject do
  use Mix.Project

  @versions_path Path.join([__DIR__, "../..", "VERSIONS"])
  @versions (if File.exists?(@versions_path) do
               @versions_path
               |> File.read!()
               |> String.split("\n", trim: true)
               |> Enum.reject(&String.starts_with?(&1, "#"))
               |> Enum.reduce(%{}, fn line, acc ->
                 case String.split(line, "=", parts: 2) do
                   [k, v] -> Map.put(acc, String.trim(k), String.trim(v))
                   _ -> acc
                 end
               end)
             else
               case System.get_env("DEPENDABOT") do
                 "true" ->
                   # Fallback to dummy versions for Dependabot compatibility
                   IO.warn(
                     "VERSIONS file not found at #{@versions_path}; using dummy versions for Dependabot environment"
                   )

                   %{
                     "PROJECT_VERSION" => "0.1.0-dependabot",
                     "ZENOHEX_VERSION" => "0.0.0-dependabot"
                   }

                 _ ->
                   raise("VERSIONS file not found at #{@versions_path}")
               end
             end)
  @version @versions["PROJECT_VERSION"] ||
             raise("PROJECT_VERSION not found in #{@versions_path}")
  @zenohex_version @versions["ZENOHEX_VERSION"] ||
                     raise("ZENOHEX_VERSION not found in #{@versions_path}")

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
