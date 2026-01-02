defmodule Giocci.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        giocci_relay: [
          include_executables_for: [:unix],
          applications: [giocci_relay: :permanent],
          config_providers: [
            {Config.Reader, {:system, "RELEASE_ROOT", "/giocci_relay.exs"}}
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
    []
  end
end
