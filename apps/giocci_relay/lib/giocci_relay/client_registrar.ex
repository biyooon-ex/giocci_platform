defmodule GiocciRelay.ClientRegistrar do
  @moduledoc false

  use GenServer

  require Logger

  alias GiocciRelay.Utils

  @name __MODULE__

  def validate_registered(client_name) do
    GenServer.call(@name, {:validate_registered, client_name})
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: @name)
  end

  def init(args) do
    relay_name = Keyword.fetch!(args, :relay_name)
    key_prefix = Keyword.get(args, :key_prefix, "")

    session_id = GiocciRelay.SessionManager.session_id()

    register_client_key = Path.join(key_prefix, "giocci/register/client/#{relay_name}")

    {:ok, register_client_queryable_id} =
      Zenohex.Session.declare_queryable(session_id, register_client_key)

    {:ok,
     %{
       relay_name: relay_name,
       key_prefix: key_prefix,
       register_client_key: register_client_key,
       register_client_queryable_id: register_client_queryable_id,
       registered_clients: []
     }}
  end

  def handle_info(
        %Zenohex.Query{key_expr: register_client_key, payload: binary, zenoh_query: zenoh_query},
        %{register_client_key: register_client_key} = state
      ) do
    relay_recv_timestamp_from_client = System.system_time(:millisecond)
    registered_clients = state.registered_clients

    {result, state} =
      with {:ok, recv_term} <- Utils.decode(binary) do
        map = maybe_measure(recv_term, relay_recv_timestamp_from_client)

        Logger.debug("#{inspect(recv_term.client_name)} registration completed successfully.")
        registered_clients = [recv_term.client_name | registered_clients] |> Enum.uniq()

        map = maybe_measure(map)

        {{:ok, map}, %{state | registered_clients: registered_clients}}
      else
        error ->
          Logger.error("Client registration failed by #{inspect(error)}.")
          {error, state}
      end

    :ok = Utils.zenohex_reply(zenoh_query, register_client_key, result)

    {:noreply, state}
  end

  def handle_call({:validate_registered, client_name}, _from, state) do
    result =
      if client_name in state.registered_clients do
        :ok
      else
        {:error, "client_not_registered"}
      end

    {:reply, result, state}
  end

  defp maybe_measure(map = %{client_send_timestamp_to_relay: _}, relay_recv_timestamp_from_client) do
    Map.put(map, :relay_recv_timestamp_from_client, relay_recv_timestamp_from_client)
  end

  defp maybe_measure(map = %{}, _relay_recv_timestamp_from_client), do: map

  defp maybe_measure(map = %{client_send_timestamp_to_relay: _}) do
    Map.put(map, :relay_send_timestamp_to_client, System.system_time(:millisecond))
  end

  defp maybe_measure(map = %{}), do: map
end
