defmodule GiocciEngine.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    zenoh_config_file_path = Application.get_env(:giocci_engine, :zenoh_config_file_path)
    engine_name = Application.fetch_env!(:giocci_engine, :engine_name)
    key_prefix = Application.get_env(:giocci_engine, :key_prefix, "")

    children = [
      {GiocciEngine.Worker,
       [
         zenoh_config_file_path: zenoh_config_file_path,
         engine_name: engine_name,
         key_prefix: key_prefix
       ]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GiocciEngine.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
