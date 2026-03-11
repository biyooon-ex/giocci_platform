defmodule GiocciPlatform.MixProject do
  use Mix.Project

  @version Path.join(__DIR__, "VERSIONS")
           |> File.read!()
           |> String.split("\n")
           |> Enum.find_value(fn
             "PROJECT_VERSION=" <> version -> String.trim(version)
             _ -> false
           end) || raise("PROJECT_VERSION not found in VERSIONS")

  def project do
    [
      apps_path: "apps",
      version: @version,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      {:"deps.get",
       [
         # at root
         "deps.get",
         # at under each apps
         "cmd mix deps.get"
       ]}
    ]
  end
end
