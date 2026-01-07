defmodule GiocciRelay.ClientRegistrar do
  @moduledoc false

  use GenServer

  require Logger

  alias GiocciRelay.Utils

  @worker_name __MODULE__

  def ensure_registered(client_name) do
    GenServer.call(@worker_name, {:ensure_registered, client_name})
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: @worker_name)
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
    registered_clients = state.registered_clients

    {result, state} =
      with {:ok, %{client_name: client_name}} <- Utils.decode(binary) do
        Logger.debug("#{inspect(client_name)} registration completed successfully.")
        registered_clients = [client_name | registered_clients] |> Enum.uniq()
        {:ok, %{state | registered_clients: registered_clients}}
      else
        error ->
          Logger.error("Client registration failed by #{inspect(error)}.")
          {error, state}
      end

    {:ok, binary} = Utils.encode(result)
    :ok = Zenohex.Query.reply(zenoh_query, register_client_key, binary)

    {:noreply, state}
  end

  def handle_call({:ensure_registered, client_name}, _from, state) do
    result =
      if client_name in state.registered_clients do
        :ok
      else
        {:error, :client_not_registered}
      end

    {:reply, result, state}
  end
end
