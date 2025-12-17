defmodule GiocciClient.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    client_name = Application.fetch_env!(:giocci_client, :client_name)
    key_prefix = Application.get_env(:giocci_client, :key_prefix, "")

    children = [
      {GiocciClient.Store, []},
      {GiocciClient.Worker, [client_name: client_name, key_prefix: key_prefix]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GiocciClient.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
