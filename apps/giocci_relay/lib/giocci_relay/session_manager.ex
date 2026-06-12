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
          Zenohex.ConfigMap.default()
          |> insert!("mode", "client")

        zenoh_config_file_path ->
          case Zenohex.ConfigMap.from_file(zenoh_config_file_path) do
            {:ok, config} ->
              config

            {:error, reason} ->
              raise "Failed to load Zenoh config file from (#{zenoh_config_file_path}): #{inspect(reason)}"
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
              |> insert!("connect/endpoints", endpoints)
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

  defp insert!(config, key, value) do
    case Zenohex.ConfigMap.insert(config, key, value) do
      {:ok, updated_config} -> updated_config
      {:error, reason} -> raise "Failed to update Zenoh config (#{key}): #{inspect(reason)}"
    end
  end
end
