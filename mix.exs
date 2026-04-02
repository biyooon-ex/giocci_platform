defmodule GiocciPlatform.MixProject do
  use Mix.Project

  @versions_path Path.join(__DIR__, "VERSIONS")
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

                   %{"PROJECT_VERSION" => "0.1.0-dependabot"}

                 _ ->
                   raise("VERSIONS file not found at #{@versions_path}")
               end
             end)
  @version @versions["PROJECT_VERSION"] ||
             raise("PROJECT_VERSION not found in #{@versions_path}")

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
