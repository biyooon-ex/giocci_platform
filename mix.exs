defmodule Giocci.MixProject do
  use Mix.Project

  @description """
  Client Library for Giocci (computational resource permeating wide-area distributed platform towards the B5G era)
  """

  @version "0.3.0-rc2"
  @source_url "https://github.com/b5g-ex/giocci"

  def project do
    [
      app: :giocci,
      version: @version,
      description: @description,
      package: package(),
      name: "Giocci",
      docs: docs(),
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      {:dotenvy, "~> 1.1.0"},
      {:zenohex, "~>0.3.2"}
    ]
  end

  defp package do
    %{
      name: "giocci",
      files: [
        "lib",
        "mix.exs",
        "README.md",
        "LICENSE"
      ],
      licenses: ["Apache-2.0"],
      links: %{"Github" => @source_url}
    }
  end

  defp docs do
    [
      extras: ["README.md"],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
