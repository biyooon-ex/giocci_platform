defmodule Giocci.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    zenoh_config_file_path = Application.get_env(:giocci, :zenoh_config_file_path)
    client_name = Application.fetch_env!(:giocci, :client_name)
    key_prefix = Application.get_env(:giocci, :key_prefix, "")

    children = [
      {Giocci.ExecFuncAsyncStore, []},
      {Giocci.SessionManager, [zenoh_config_file_path: zenoh_config_file_path]},
      {Giocci.Worker,
       [
         client_name: client_name,
         key_prefix: key_prefix
       ]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Giocci.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
