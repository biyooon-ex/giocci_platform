defmodule GiocciZenoh.Detect do
  alias Zenohex.Session
  alias Zenohex.Publisher

  def detect(session, relay, engine, magic_number, payload, receive_timeout) do
    pub_key_prefix = Application.fetch_env!(:giocci, :pub_key_prefix)
    relay_name = Atom.to_string(relay)
    pub_key = pub_key_prefix <> relay_name <> "/" <> Integer.to_string(magic_number)
    {:ok, publisher} = Session.declare_publisher(session, pub_key)

    sub_key_prefix = Application.fetch_env!(:giocci, :sub_key_prefix)
    engine_name = Atom.to_string(engine)

    sub_key =
      sub_key_prefix <> engine_name <> "/detected_data/" <> Integer.to_string(magic_number)

    {:ok, _subscriber} = Session.declare_subscriber(session, sub_key)

    Publisher.put(publisher, payload)

    receive do
      %Zenohex.Sample{key_expr: ^sub_key} = sample ->
        {:ok, :erlang.binary_to_term(sample.payload)}
    after
      receive_timeout -> {:error, "Zenoh Timeout"}
    end
  end

  def create_zenoh_session() do
    # Open session
    {:ok, session} = Session.open()
    %{:session => session}
  end
end
