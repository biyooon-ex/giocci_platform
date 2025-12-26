defmodule GiocciRelay.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    relay_name = Application.fetch_env!(:giocci_relay, :relay_name)
    key_prefix = Application.get_env(:giocci_relay, :key_prefix, "")

    children = [
      {GiocciRelay.ModuleStore, []},
      {GiocciRelay.Worker, [relay_name: relay_name, key_prefix: key_prefix]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GiocciRelay.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
