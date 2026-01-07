defmodule Giocci.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        giocci_client: [
          include_executables_for: [:unix],
          applications: [giocci_client: :permanent],
          config_providers: [
            {Config.Reader, {:system, "RELEASE_ROOT", "/giocci_client.exs"}}
          ]
        ],
        giocci_relay: [
          include_executables_for: [:unix],
          applications: [giocci_relay: :permanent],
          config_providers: [
            {Config.Reader, {:system, "RELEASE_ROOT", "/giocci_relay.exs"}}
          ]
        ],
        giocci_engine: [
          include_executables_for: [:unix],
          applications: [giocci_engine: :permanent],
          config_providers: [
            {Config.Reader, {:system, "RELEASE_ROOT", "/giocci_engine.exs"}}
          ]
        ]
      ]
    ]
  end

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
