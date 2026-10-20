defmodule GiocciPico.SessionManager do
  @moduledoc false

  use GenServer

  @name __MODULE__

  # API

  def session() do
    GenServer.call(@name, :session)
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: @name)
  end

  # callbacks

  def init(args) do
    zenohex_pico_config = Keyword.fetch!(args, :zenohex_pico_config)

    case ZenohexPico.Session.open(zenohex_pico_config) do
      {:ok, session} ->
        {:ok, %{session: session}}

      {:error, reason} ->
        IO.inspect("Failed to open Zenoh session: #{inspect(reason)}")
        {:stop, {:zenoh_session_open_failed, reason}}
    end
  end

  def handle_call(:session, _from, state) do
    {:reply, state.session, state}
  end
end
