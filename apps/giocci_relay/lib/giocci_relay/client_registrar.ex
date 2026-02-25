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
      with {:ok, term_from_client} <- Utils.decode(binary),
           %{client_name: client_name} <- term_from_client.data do
        Logger.debug("#{inspect(client_name)} registration completed successfully.")
        registered_clients = [client_name | registered_clients] |> Enum.uniq()

        {{:ok, term_from_client}, %{state | registered_clients: registered_clients}}
      else
        error ->
          Logger.error("Client registration failed by #{inspect(error)}.")
          {error, state}
      end

    result = maybe_squash(result, relay_recv_timestamp_from_client)
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

  defp maybe_squash(result, relay_recv_timestamp_from_client) do
    case result do
      {:ok, %{measurements: measurements}} ->
        term_to_client = %{
          data: :ok,
          measurements:
            Map.merge(measurements, %{
              relay_recv_timestamp_from_client: relay_recv_timestamp_from_client,
              relay_send_timestamp_to_client: System.system_time(:millisecond)
            })
        }

        {:ok, term_to_client}

      result ->
        result
    end
  end
end
