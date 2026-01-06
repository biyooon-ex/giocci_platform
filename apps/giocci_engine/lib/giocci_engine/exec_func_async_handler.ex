defmodule GiocciEngine.ExecFuncAsyncHandler do
  use GenServer

  require Logger

  alias GiocciEngine.Utils

  @worker_name __MODULE__

  # API

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: @worker_name)
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
       session_id: session_id,
       exec_func_async_key: exec_func_async_key,
       exec_func_async_subscriber_id: exec_func_async_subscriber_id
     }}
  end

  def handle_info(
        %Zenohex.Sample{key_expr: exec_func_async_key, payload: binary},
        %{exec_func_async_key: exec_func_async_key} = state
      ) do
    session_id = state.session_id
    key_prefix = state.key_prefix

    fun = fn ->
      with {:ok, recv_term} <- Utils.decode(binary),
           {:ok, {{m, _f, _args} = mfargs, exec_id, client_name}} <- extract(recv_term),
           :ok <- Utils.ensure_module_saved(m),
           {:ok, result} <- Utils.exec_func(mfargs),
           key <- Path.join(key_prefix, "giocci/exec_func_async/engine/#{client_name}") do
        Logger.debug("Exec func async successfully, #{inspect(mfargs)}.")

        result =
          {:ok,
           %{
             mfargs: mfargs,
             exec_id: exec_id,
             client_name: client_name,
             result: result
           }}

        {:ok, binary} = Utils.encode(result)
        :ok = Zenohex.Session.put(session_id, key, binary)
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
    MatchError -> {:error, :term_not_expected}
  end
end
