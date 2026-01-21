defmodule Giocci.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
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
      {:test, &test/1},
      {:"deps.get",
       [
         # at root
         "deps.get",
         # at under each apps
         "cmd mix deps.get"
       ]}
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
        # execute a command on each child app
        Mix.Task.run("cmd", ~w"mix test --no-start")

      # Check if docker command exists
      System.find_executable("docker") ->
        Mix.shell().info("""
        Docker found - running tests in container\n
        """)

        exit_code = Mix.shell().cmd("docker compose run --rm zenohd mix test")
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
