defmodule GiocciRelay.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    started_at_ms = System.monotonic_time(:millisecond)
    zenoh_config_file_path = Application.get_env(:giocci_relay, :zenoh_config_file_path)
    relay_name = Application.fetch_env!(:giocci_relay, :relay_name)
    key_prefix = Application.get_env(:giocci_relay, :key_prefix, "")

    engine_selection_policy =
      Application.get_env(
        :giocci_relay,
        :engine_selection_policy,
        GiocciRelay.EngineSelectionPolicy.RoundRobin
      )

    engine_selection_policy_opts =
      Application.get_env(:giocci_relay, :engine_selection_policy_opts, [])

    children = [
      {GiocciRelay.ModuleStore, []},
      {GiocciRelay.SessionManager, [zenoh_config_file_path: zenoh_config_file_path]},
      {GiocciRelay.ClientRegistrar,
       [
         relay_name: relay_name,
         key_prefix: key_prefix
       ]},
      {GiocciRelay.EngineRegistrar,
       [
         relay_name: relay_name,
         key_prefix: key_prefix,
         engine_selection_policy: engine_selection_policy,
         engine_selection_policy_opts: engine_selection_policy_opts
       ]},
      {GiocciRelay.ModuleSaver,
       [
         relay_name: relay_name,
         key_prefix: key_prefix
       ]},
      {GiocciRelay.EngineInquiryHandler,
       [
         relay_name: relay_name,
         key_prefix: key_prefix
       ]},
      {GiocciRelay.InspectHandler,
       [
         relay_name: relay_name,
         key_prefix: key_prefix,
         started_at_ms: started_at_ms
       ]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GiocciRelay.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
