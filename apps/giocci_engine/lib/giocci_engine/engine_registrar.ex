defmodule GiocciEngine.EngineRegistrar do
  @moduledoc false

  use GenServer

  require Logger

  alias GiocciEngine.Utils

  @name __MODULE__
  @unregister_timeout 5_000

  # API

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: @name)
  end

  def unregister do
    engine_name = Application.fetch_env!(:giocci_engine, :engine_name)
    relay_name = Application.fetch_env!(:giocci_engine, :relay_name)
    key_prefix = Application.get_env(:giocci_engine, :key_prefix, "")
    session_id = GiocciEngine.SessionManager.session_id()
    key = Path.join(key_prefix, "giocci/unregister/engine/#{relay_name}")
    term_to_relay = %{data: %{engine_name: engine_name}, measurements: %{}}

    case Utils.zenohex_get(session_id, key, @unregister_timeout, term_to_relay) do
      {:ok, {:ok, %{data: nil}}} ->
        Logger.info("#{inspect(engine_name)} unregistered.")

      error ->
        Logger.warning("Engine unregistration failed by #{inspect(error)}.")
    end
  end

  def init(args) do
    engine_name = Keyword.fetch!(args, :engine_name)
    key_prefix = Keyword.get(args, :key_prefix, "")
    relay_name = Keyword.fetch!(args, :relay_name)

    session_id = GiocciEngine.SessionManager.session_id()

    term_to_relay = %{data: %{engine_name: engine_name}, measurements: %{}}

    # Register this Engine to the specified Relay when starts
    {:ok, %{data: nil, measurements: _measurements}} =
      with key <- Path.join(key_prefix, "giocci/register/engine/#{relay_name}"),
           {:ok, term_from_relay} <-
             Utils.zenohex_get(session_id, key, _timeout = 5000, term_to_relay) do
        term_from_relay
      end

    Logger.info("#{inspect(engine_name)} started.")

    {:ok,
     %{
       engine_name: engine_name,
       key_prefix: key_prefix,
       relay_name: relay_name
     }}
  end
end
