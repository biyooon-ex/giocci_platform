defmodule GiocciEngine.ExecFuncHandler do
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

    exec_func_key = Path.join(key_prefix, "giocci/exec_func/client/#{engine_name}")

    {:ok, exec_func_queryable_id} =
      Zenohex.Session.declare_queryable(session_id, exec_func_key)

    {:ok,
     %{
       engine_name: engine_name,
       key_prefix: key_prefix,
       relay_name: relay_name,
       exec_func_key: exec_func_key,
       exec_func_queryable_id: exec_func_queryable_id
     }}
  end

  def handle_info(
        %Zenohex.Query{key_expr: exec_func_key, payload: binary, zenoh_query: zenoh_query},
        %{exec_func_key: exec_func_key} = state
      ) do
    engine_recv_timestamp_from_client = System.system_time(:millisecond)

    fun = fn ->
      result =
        with {:ok, recv_term} <- Utils.decode(binary),
             {:ok, {{m, _f, _args} = mfargs, _client_name}} <- extract(recv_term),
             :ok <- Utils.validate_module_saved(m),
             {:ok, result} <- Utils.exec_func(mfargs) do
          Logger.debug("Exec func successfully, #{inspect(mfargs)}.")
          {:ok, Map.put(recv_term, :result, result)}
        else
          error ->
            Logger.error("Exec func failed, #{inspect(error)}.")
            error
        end

      result = maybe_squash(result, engine_recv_timestamp_from_client)
      :ok = Utils.zenohex_reply(zenoh_query, exec_func_key, result)
    end

    {:ok, _pid} =
      Task.Supervisor.start_child(
        {:via, PartitionSupervisor, {GiocciEngine.TaskSupervisors, make_ref()}},
        fun
      )

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

  defp maybe_squash(result, engine_recv_timestamp_from_client) do
    case result do
      {:ok, map} ->
        map =
          map
          |> Map.take([
            :engine_name,
            :result,
            :client_send_timestamp_to_relay,
            :relay_recv_timestamp_from_client,
            :relay_send_timestamp_to_client,
            :client_recv_timestamp_from_relay,
            :client_send_timestamp_to_engine
          ])
          |> Map.merge(%{
            engine_recv_timestamp_from_client: engine_recv_timestamp_from_client,
            engine_send_timestamp_to_client: System.system_time(:millisecond)
          })

        {:ok, map}

      result ->
        result
    end
  end
end
