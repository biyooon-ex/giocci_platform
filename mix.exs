defmodule GiocciPlatform.MixProject do
  use Mix.Project

  @versions_path Path.join(__DIR__, "VERSIONS")
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
