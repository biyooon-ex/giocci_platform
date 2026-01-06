defmodule GiocciRelay.EngineInquiryHandler do
  use GenServer

  require Logger

  alias GiocciRelay.Utils

  @worker_name __MODULE__

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: @worker_name)
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
       session_id: session_id,
       inquiry_engine_key: inquiry_engine_key,
       inquiry_engine_queryable_id: inquiry_engine_queryable_id
     }}
  end

  def handle_info(
        %Zenohex.Query{key_expr: inquiry_engine_key, payload: binary, zenoh_query: zenoh_query},
        %{inquiry_engine_key: inquiry_engine_key} = state
      ) do
    result =
      with {:ok, recv_term} <- Utils.decode(binary),
           {:ok, {mfargs, client_name}} <- extract(recv_term),
           :ok <- GiocciRelay.ClientRegistrar.ensure_registered(client_name),
           {:ok, engine_name} <- GiocciRelay.EngineRegistrar.select_engine() do
        Logger.debug(
          "#{inspect(engine_name)} is selected for #{inspect(client_name)}'s #{inspect(mfargs)}."
        )

        {:ok, %{engine_name: engine_name}}
      else
        error ->
          Logger.error("Inquiry engine failed, #{inspect(error)}.")
          error
      end

    {:ok, binary} = Utils.encode(result)
    :ok = Zenohex.Query.reply(zenoh_query, inquiry_engine_key, binary)

    {:noreply, state}
  end

  defp extract(term) do
    %{
      mfargs: mfargs,
      client_name: client_name
    } = term

    {:ok, {mfargs, client_name}}
  rescue
    MatchError -> {:error, :term_not_expected}
  end
end
