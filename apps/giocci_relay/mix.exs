defmodule GiocciRelay.MixProject do
  use Mix.Project

  @versions_path Path.join([__DIR__, "../..", "VERSIONS"])
  @version (if File.exists?(@versions_path) do
              @versions_path
              |> File.read!()
              |> String.split("\n")
              |> Enum.find_value(fn
                "PROJECT_VERSION=" <> version -> String.trim(version)
                _ -> false
              end) || raise("PROJECT_VERSION not found in VERSIONS")
            else
              case System.get_env("DEPENDABOT") do
                "true" ->
                  # Fallback to dummy version for Dependabot compatibility
                  IO.warn(
                    "VERSIONS file not found at #{@versions_path}; using dummy project version for Dependabot environment"
                  )

                  "0.1.0-dependabot"

                _ ->
                  raise("VERSIONS file not found at #{@versions_path}")
              end
            end)
  @zenohex_version (if File.exists?(@versions_path) do
                      @versions_path
                      |> File.read!()
                      |> String.split("\n")
                      |> Enum.find_value(fn
                        "ZENOHEX_VERSION=" <> version -> String.trim(version)
                        _ -> false
                      end) || raise("ZENOHEX_VERSION not found in VERSIONS")
                    else
                      case System.get_env("DEPENDABOT") do
                        "true" ->
                          # Fallback to dummy version for Dependabot compatibility
                          IO.warn(
                            "VERSIONS file not found at #{@versions_path}; using dummy zenohex version for Dependabot environment"
                          )

                          "0.0.0-dependabot"

                        _ ->
                          raise("VERSIONS file not found at #{@versions_path}")
                      end
                    end)

  def project do
    [
      app: :giocci_relay,
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
      mod: {GiocciRelay.Application, []}
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
