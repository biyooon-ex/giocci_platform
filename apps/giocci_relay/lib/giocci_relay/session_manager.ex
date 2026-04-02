defmodule GiocciRelay.SessionManager do
  @moduledoc false

  use GenServer

  require Logger

  @name __MODULE__

  def session_id() do
    GenServer.call(@name, :session_id)
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: @name)
  end

  def init(args) do
    zenoh_config =
      case Keyword.get(args, :zenoh_config_file_path) do
        nil ->
          Zenohex.Config.default()
          |> Zenohex.Config.update_in(["mode"], fn _ -> "client" end)

        zenoh_config_file_path ->
          zenoh_config_file_path
          |> File.read!()
          |> Zenohex.Config.from_json5()
          |> case do
            {:ok, clean_json} -> clean_json
            {:error, reason} -> raise "Failed to parse Zenoh config: #{inspect(reason)}"
          end
      end

    zenoh_config =
      case System.get_env("ZENOHD_CONNECT_ENDPOINTS") do
        val when val in [nil, ""] ->
          zenoh_config

        endpoints_str ->
          case endpoints_str |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == "")) do
            [] -> zenoh_config
            endpoints -> Zenohex.Config.update_in(zenoh_config, ["connect", "endpoints"], fn _ -> endpoints end)
          end
      end

    {:ok, session_id} = Zenohex.Session.open(zenoh_config)

    {:ok,
     %{
       session_id: session_id
     }}
  end

  def handle_call(:session_id, _from, state) do
    {:reply, state.session_id, state}
  end
end
