defmodule GiocciRelay.SessionManager do
  @moduledoc false

  use GenServer

  require Logger

  @name __MODULE__

  def session_id() do
    GenServer.call(@name, :session_id)
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: @name)
  end

  def init(args) do
    zenoh_config =
      case Keyword.get(args, :zenoh_config_file_path) do
        nil ->
          Zenohex.Config.default()
          |> Zenohex.Config.update_in(["mode"], fn _ -> "client" end)

        zenoh_config_file_path ->
          zenoh_config_file_path
          |> File.read!()
      end

    {:ok, session_id} = Zenohex.Session.open(zenoh_config)

    {:ok,
     %{
       session_id: session_id
     }}
  end

  def handle_call(:session_id, _from, state) do
    {:reply, state.session_id, state}
  end
end
