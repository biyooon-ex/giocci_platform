defmodule GiocciPlatform.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: version(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  defp version do
    versions_path = Path.join(__DIR__, "VERSIONS")

    if File.exists?(versions_path) do
      versions_path
      |> File.read!()
      |> String.split("\n")
      |> Enum.find_value(fn
        "PROJECT_VERSION=" <> version -> String.trim(version)
        _ -> false
      end) || raise("PROJECT_VERSION not found in VERSIONS")
    else
      if allow_missing_versions?() do
        fallback_version = "0.0.0-dev"

        IO.warn(
          "VERSIONS file not found at #{versions_path}; using fallback version #{fallback_version}"
        )

        fallback_version
      else
        raise("VERSIONS file not found at #{versions_path}")
      end
    end
  end

  defp allow_missing_versions? do
    System.get_env("MIX_ALLOW_MISSING_VERSIONS") == "true" ||
      System.get_env("DEPENDABOT") == "true" ||
      (System.get_env("GITHUB_ACTIONS") == "true" &&
         System.get_env("GITHUB_ACTOR") == "dependabot[bot]")
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
