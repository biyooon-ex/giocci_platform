defmodule GiocciEngine.ExecFuncAsyncHandler do
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

    exec_func_async_key = Path.join(key_prefix, "giocci/exec_func_async/client/#{engine_name}")

    {:ok, exec_func_async_subscriber_id} =
      Zenohex.Session.declare_subscriber(session_id, exec_func_async_key)

    {:ok,
     %{
       engine_name: engine_name,
       key_prefix: key_prefix,
       relay_name: relay_name,
       exec_func_async_key: exec_func_async_key,
       exec_func_async_subscriber_id: exec_func_async_subscriber_id
     }}
  end

  def handle_info(
        %Zenohex.Sample{key_expr: exec_func_async_key, payload: binary},
        %{exec_func_async_key: exec_func_async_key} = state
      ) do
    key_prefix = state.key_prefix

    fun = fn ->
      with {:ok, term_from_client} <- Utils.decode(binary),
           {:ok, {mfargs, exec_id, client_name}} <- extract(term_from_client.data),
           :ok <- Utils.validate_module_saved(elem(mfargs, 0)),
           {:ok, result} <- Utils.exec_func(mfargs),
           key <- Path.join(key_prefix, "giocci/exec_func_async/engine/#{client_name}") do
        Logger.debug("Exec func async successfully, #{inspect(mfargs)}.")

        term_to_client =
          {:ok,
           %{
             data: %{
               mfargs: mfargs,
               exec_id: exec_id,
               client_name: client_name,
               result: result
             },
             measurements: term_from_client.measurements
           }}

        session_id = GiocciEngine.SessionManager.session_id()
        :ok = Utils.zenohex_put(session_id, key, term_to_client)
      else
        error ->
          Logger.error("Exec func async failed, #{inspect(error)}.")
          error
      end
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
      exec_id: exec_id,
      client_name: client_name
    } = term

    {:ok, {mfargs, exec_id, client_name}}
  rescue
    MatchError -> {:error, "term_not_expected"}
  end
end
