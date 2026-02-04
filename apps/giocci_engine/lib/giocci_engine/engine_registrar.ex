defmodule GiocciEngine.EngineRegistrar do
  @moduledoc false

  use GenServer

  require Logger

  alias GiocciEngine.Utils

  @name __MODULE__

  # API

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: @name)
  end

  def init(args) do
    engine_name = Keyword.fetch!(args, :engine_name)
    key_prefix = Keyword.get(args, :key_prefix, "")
    relay_name = Keyword.fetch!(args, :relay_name)

    session_id = GiocciEngine.SessionManager.session_id()

    # Register this Engine to the specified Relay when starts
    :ok =
      with key <- Path.join(key_prefix, "giocci/register/engine/#{relay_name}"),
           {:ok, binary} <- Utils.encode(%{engine_name: engine_name}),
           {:ok, binary} <- Utils.zenohex_get(session_id, key, _timeout = 5000, binary),
           {:ok, recv_term} <- Utils.decode(binary) do
        recv_term
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
