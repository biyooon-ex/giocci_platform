defmodule GiocciEngine.MixProject do
  use Mix.Project

  @versions_path Path.join([__DIR__, "..", "..", "VERSIONS"])
  @versions @versions_path
            |> File.read!()
            |> String.split("\n")
            |> Enum.reduce(%{}, fn line, acc ->
              line = String.trim(line)

              cond do
                line == "" -> acc
                String.starts_with?(line, "#") -> acc
                true ->
                  case String.split(line, "=", parts: 2) do
                    [k, v] -> Map.put(acc, String.trim(k), String.trim(v))
                    _ -> acc
                  end
              end
            end)
  @version Map.fetch!(@versions, "PROJECT_VERSION")
  @zenohex_version Map.fetch!(@versions, "ZENOHEX_VERSION")

  def project do
    [
      app: :giocci_engine,
      version: @version,
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
      {:zenohex, "== #{@zenohex_version}"}
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
