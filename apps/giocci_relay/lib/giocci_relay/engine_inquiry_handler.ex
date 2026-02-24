defmodule GiocciRelay.EngineInquiryHandler do
  @moduledoc false

  use GenServer

  require Logger

  alias GiocciRelay.Utils

  @name __MODULE__

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: @name)
  end

  def init(args) do
    relay_name = Keyword.fetch!(args, :relay_name)
    key_prefix = Keyword.get(args, :key_prefix, "")

    session_id = GiocciRelay.SessionManager.session_id()

    inquiry_engine_key = Path.join(key_prefix, "giocci/inquiry_engine/client/#{relay_name}")

    {:ok, inquiry_engine_queryable_id} =
      Zenohex.Session.declare_queryable(session_id, inquiry_engine_key)

    Logger.info("#{inspect(relay_name)} started.")

    {:ok,
     %{
       relay_name: relay_name,
       key_prefix: key_prefix,
       inquiry_engine_key: inquiry_engine_key,
       inquiry_engine_queryable_id: inquiry_engine_queryable_id
     }}
  end

  def handle_info(
        %Zenohex.Query{key_expr: inquiry_engine_key, payload: binary, zenoh_query: zenoh_query},
        %{inquiry_engine_key: inquiry_engine_key} = state
      ) do
    relay_recv_timestamp_from_client = System.system_time(:millisecond)

    result =
      with {:ok, recv_term} <- Utils.decode(binary),
           {:ok, {mfargs, client_name}} <- extract(recv_term),
           :ok <- GiocciRelay.ClientRegistrar.validate_registered(client_name),
           {:ok, engine_name} <- GiocciRelay.EngineRegistrar.select_engine() do
        Logger.debug(
          "#{inspect(engine_name)} is selected for #{inspect(client_name)}'s #{inspect(mfargs)}."
        )

        {:ok, Map.put(recv_term, :engine_name, engine_name)}
      else
        error ->
          Logger.error("Inquiry engine failed, #{inspect(error)}.")
          error
      end

    result = maybe_squash(result, relay_recv_timestamp_from_client)
    :ok = Utils.zenohex_reply(zenoh_query, inquiry_engine_key, result)

    {:noreply, state}
  end

  defp extract(term) do
    %{
      mfargs: mfargs,
      client_name: client_name
    } = term

    {:ok, {mfargs, client_name}}
  rescue
    MatchError -> {:error, "term_not_expected"}
  end

  defp maybe_squash(result, relay_recv_timestamp_from_client) do
    case result do
      {:ok, map} ->
        map =
          map
          |> Map.take([
            :engine_name,
            :client_send_timestamp_to_relay
          ])
          |> Map.merge(%{
            relay_recv_timestamp_from_client: relay_recv_timestamp_from_client,
            relay_send_timestamp_to_client: System.system_time(:millisecond)
          })

        {:ok, map}

      result ->
        result
    end
  end
end
