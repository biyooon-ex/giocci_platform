defmodule GiocciEngine.SessionManager do
  @moduledoc false

  use GenServer

  require Logger

  @name __MODULE__

  # API

  def session_id() do
    GenServer.call(__MODULE__, :session_id)
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: @name)
  end

  def init(args) do
    zenoh_config =
      case Keyword.get(args, :zenoh_config_file_path) do
        nil ->
          Zenohex.Config.default()
          |> insert_json5!("mode", "client")

        zenoh_config_file_path ->
          Zenohex.Config.from_file(zenoh_config_file_path)
      end

    zenoh_config =
      case System.get_env("ZENOHD_CONNECT_ENDPOINTS") do
        nil ->
          zenoh_config

        endpoints_str ->
          endpoints =
            endpoints_str
            |> String.split(",")
            |> Enum.map(&String.trim/1)
            |> Enum.reject(&(&1 == ""))

          case endpoints do
            [] ->
              zenoh_config

            # In zenohex v0.9.0, `value` is restricted to `binary` only and does not accept arrays directly.
            # This issue is being addressed in PR below and is scheduled to be included in the next release.
            # https://github.com/biyooon-ex/zenohex/pull/181
            # After that, we can remove encoding endpoints procedure and directly pass the list.
            _ ->
              zenoh_config
              |> insert_json5!(
                "connect/endpoints",
                endpoints |> :json.encode() |> IO.iodata_to_binary()
              )
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

  defp insert_json5!(config, key, value) do
    case Zenohex.Config.insert_json5(config, key, value) do
      {:ok, updated_config} -> updated_config
      {:error, reason} -> raise "Failed to update Zenoh config (#{key}): #{inspect(reason)}"
    end
  end
end
