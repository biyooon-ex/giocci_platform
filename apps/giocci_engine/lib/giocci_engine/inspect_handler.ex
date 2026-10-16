defmodule GiocciEngine.InspectHandler do
  @moduledoc false

  use GenServer

  alias GiocciEngine.Utils

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    engine_name = Keyword.fetch!(args, :engine_name)
    key_prefix = Keyword.get(args, :key_prefix, "")
    key = Path.join(key_prefix, "giocci/inspect/engine/#{engine_name}")
    session_id = GiocciEngine.SessionManager.session_id()
    {:ok, queryable_id} = Zenohex.Session.declare_queryable(session_id, key)

    {:ok,
     %{
       name: engine_name,
       key: key,
       queryable_id: queryable_id,
       started_at_ms: Keyword.fetch!(args, :started_at_ms)
     }}
  end

  def handle_info(
        %Zenohex.Query{key_expr: key, payload: payload, zenoh_query: zenoh_query},
        %{key: key} = state
      ) do
    result =
      with {:ok, %{data: request}} <- Utils.decode(payload) do
        inspect_request(request, state)
      else
        {:ok, _} -> {:error, "term_not_expected"}
        error -> error
      end

    reply =
      case result do
        {:ok, value} -> {:ok, %{data: value, measurements: %{}}}
        error -> error
      end

    :ok = Utils.zenohex_reply(zenoh_query, key, reply)
    {:noreply, state}
  end

  defp inspect_request(%{operation: :engine_info}, state) do
    {:ok,
     %{
       "name" => state.name,
       "giocci_version" => :giocci_engine |> Application.spec(:vsn) |> to_string(),
       "elixir_version" => System.version(),
       "otp_release" => System.otp_release(),
       "system_architecture" => :erlang.system_info(:system_architecture) |> to_string(),
       "uptime_ms" => System.monotonic_time(:millisecond) - state.started_at_ms,
       "schedulers_online" => System.schedulers_online()
     }}
  end

  defp inspect_request(%{operation: :ping}, _state), do: {:ok, :pong}
  defp inspect_request(_request, _state), do: {:error, "term_not_expected"}
end
