defmodule GiocciPico.Supervisor do
  @moduledoc false

  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    zenohex_pico_config = Keyword.fetch!(args, :zenohex_pico_config)
    client_name = Keyword.fetch!(args, :client_name)
    key_prefix = Keyword.get(args, :key_prefix, "")

    children = [
      {GiocciPico.SessionManager, [zenohex_pico_config: zenohex_pico_config]},
      {GiocciPico.Worker,
       [
         client_name: client_name,
         key_prefix: key_prefix
       ]}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
