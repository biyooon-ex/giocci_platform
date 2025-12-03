defmodule GiocciClient.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    client_name = Application.fetch_env!(:giocci_client, :client_name)

    children = [
      {GiocciClient.Worker, [client_name: client_name]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GiocciClient.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
