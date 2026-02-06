defmodule GiocciIntegrationTest.MixProject do
  use Mix.Project

  def project do
    [
      app: :giocci_integration_test,
      version: "0.3.1-rc.0",
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

  defp test(_) do
    cond do
      # Check if running inside Docker container
      not is_nil(System.get_env("GIOCCI_ZENOH_HOME")) ->
        Mix.shell().info("""
        Running inside Docker container (GIOCCI_ZENOH_HOME: #{System.get_env("GIOCCI_ZENOH_HOME")}) - executing tests directly
        """)

        # Start zenohd in background
        spawn(fn -> Mix.shell().cmd("zenohd") end)

        Mix.Task.run("test", ~w"--no-start")

      # Check if docker command exists
      System.find_executable("docker") ->
        Mix.shell().info("""
        Docker found - running tests in container\n
        """)

        exit_code =
          Mix.shell().cmd(
            "docker compose run --rm --workdir /app/apps/giocci_integration_test zenohd mix test"
          )

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
