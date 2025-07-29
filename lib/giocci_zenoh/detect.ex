defmodule GiocciZenoh.Detect do
  alias Zenohex.Session
  alias Zenohex.Config
  alias Zenohex.Publisher
  alias Zenohex.Subscriber
  alias Zenohex.Sample

  def detect(session, relay, engine, magic_number, payload, receive_timeout) do
    pub_key_prefix = Application.fetch_env!(:giocci, :pub_key_prefix)
    relay_name = Atom.to_string(relay)
    pub_key = pub_key_prefix <> relay_name <> "/" <> Integer.to_string(magic_number)
    {:ok, publisher} = Session.declare_publisher(session, pub_key)

    sub_key_prefix = Application.fetch_env!(:giocci, :sub_key_prefix)
    engine_name = Atom.to_string(engine)

    sub_key =
      sub_key_prefix <> engine_name <> "/detected_data/" <> Integer.to_string(magic_number)

    {:ok, subscriber} = Session.declare_subscriber(session, sub_key)

    Publisher.put(publisher, payload)
    Publisher.undeclare(publisher)

    receive do
      %Sample{key_expr: ^sub_key} = sample ->
        Subscriber.undeclare(subscriber)
        {:ok, :erlang.binary_to_term(sample.payload)}
    after
      receive_timeout -> {:error, "Zenoh Timeout"}
    end
  end

  def open_zenoh_session(relays_ip) do
    config =
      Config.default()
      |> Config.update_in(["connect", "endpoints"], fn [] ->
        Enum.map(relays_ip, fn ip -> "tcp/#{ip}:7447" end)
      end)

    Session.open(config)
  end

  def close_zenoh_session(session) do
    case Session.close(session) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
