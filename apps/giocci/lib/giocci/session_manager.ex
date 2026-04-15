defmodule Giocci.SessionManager do
  @moduledoc false

  use GenServer

  @name __MODULE__

  # API

  def session_id() do
    GenServer.call(@name, :session_id)
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: @name)
  end

  # callbacks

  def init(args) do
    zenoh_config =
      case Keyword.get(args, :zenoh_config_file_path) do
        nil ->
          Zenohex.Config.default()
          |> insert_json5!("mode", "client")

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
