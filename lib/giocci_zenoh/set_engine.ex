defmodule GiocciZenoh.SetEngine do
  use GenServer

  alias Zenohex.Session
  alias Zenohex.Publisher

  def put(name \\ __MODULE__, payload) do
    GenServer.call(name, {:put, payload})
  end

  def start_link(relays_ip) do
    GenServer.start_link(__MODULE__, relays_ip, name: __MODULE__)
  end

  def init(relays_ip) do
    pub_key_prefix = Application.fetch_env!(:giocci, :pub_key_prefix)

    # Create a publisher to send Engine name to GiocciRelay
    {:ok, session} = GiocciZenoh.Detect.open_zenoh_session(relays_ip)
    key_expr_to_engine = pub_key_prefix <> "to_engine"
    {:ok, pub_to_engine} = Session.declare_publisher(session, key_expr_to_engine)

    state = %{pub_to_engine: pub_to_engine}
    {:ok, state}
  end

  # Publish Engine name to GiocciRelay
  def handle_call({:put, payload}, _from, state) do
    reply = Publisher.put(state.pub_to_engine, payload)

    {:reply, reply, state}
  end
end
