defmodule GiocciIntegration.MixProject do
  use Mix.Project

  def project do
    [
      app: :giocci_integration,
      version: "0.3.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
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
      {:giocci_relay, in_umbrella: true},
      {:giocci_engine, in_umbrella: true},
      {:giocci_client, in_umbrella: true}
    ]
  end

  defp aliases do
    [
      test: ["test --no-start"]
    ]
  end
end
