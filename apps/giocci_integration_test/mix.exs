defmodule GiocciIntegrationTest.MixProject do
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

  def project do
    [
      app: :giocci_integration_test,
      version: @version,
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
      {:giocci, in_umbrella: true}
    ]
  end

  defp aliases do
    [
      test: &test/1
    ]
  end

  defp test(args) do
    cond do
      # Check if running inside Docker container
      not is_nil(System.get_env("GIOCCI_ZENOH_HOME")) ->
        Mix.shell().info("""
        Running inside Docker container (GIOCCI_ZENOH_HOME: #{System.get_env("GIOCCI_ZENOH_HOME")}) - executing tests directly
        """)

        with host_arch <- System.get_env("HOST_ARCH"),
             true <- not is_nil(host_arch),
             true <- String.starts_with?(host_arch, "aarch64-apple-darwin") do
          Mix.shell().info("Detected Apple Silicon host - refetching zenohex for arm64 linux")
          Mix.Task.run("deps.clean", ["zenohex"])
          Mix.Task.run("deps.get", ["zenohex"])
        end

        # Start zenohd in background
        spawn(fn -> Mix.shell().cmd("zenohd") end)

        Mix.Task.run("test", ["--no-start" | args])

      # Check if docker command exists
      not is_nil(System.find_executable("docker")) ->
        Mix.shell().info("""
        Docker found - running tests in container\n
        """)

        exit_code =
          Mix.shell().cmd({
            "docker",
            ~w"compose run --rm --workdir /app/apps/giocci_integration_test --env HOST_ARCH=#{:erlang.system_info(:system_architecture)} zenohd" ++
              ~w"mix test" ++ args
          })

        System.halt(exit_code)

      # No docker, show error
      true ->
        Mix.shell().error("""
        Docker not found - please install Docker to run tests
        Visit https://docs.docker.com/get-docker/ for installation instructions
        """)

        System.halt(1)
    end
  end
end
