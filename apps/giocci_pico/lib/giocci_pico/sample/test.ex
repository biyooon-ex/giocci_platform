defmodule GiocciPico.Sample.Test do
  @compile {:no_warn_undefined, [:esp, :network]}
  @host_ipv4_address (
                       ipv4_address = ~S/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/
                       {route, 0} = System.cmd("ip", ["-4", "route", "get", "1.1.1.1"])
                       [_, host] = Regex.run(~r/\bsrc\s+(#{ipv4_address})\b/, route)
                       host
                     )
  def start do
    # Call these once to configure your Wi-Fi station.
    # :esp.nvs_put_binary(:atomvm, :sta_ssid, "SSID")
    # :esp.nvs_put_binary(:atomvm, :sta_psk, "Password")

    # Connect WiFi
    {:ok, ssid} = :esp.nvs_fetch_binary(:atomvm, :sta_ssid)
    {:ok, psk} = :esp.nvs_fetch_binary(:atomvm, :sta_psk)

    :ok = connect_wifi(ssid, psk)

    # Prepare ZenohexPico
    {:ok, config} = ZenohexPico.Config.default()
    {:ok, config} = ZenohexPico.Config.insert(config, :mode, "peer")

    {:ok, config} =
      ZenohexPico.Config.insert(config, :connect, "tcp/#{@host_ipv4_address}:7447")

    # Start GiocciPico.Supervisor
    {:ok, _pid} =
      GiocciPico.Supervisor.start_link(
        zenohex_pico_config: config,
        client_name: "giocci_pico",
        key_prefix: ""
      )

    # Offload calculation
    relay_name = "giocci_relay"
    :ok = GiocciPico.register_client(relay_name)
    :ok = GiocciPico.save_module(relay_name, GiocciPico.Sample.Module)
    3 = GiocciPico.exec_func(relay_name, {GiocciPico.Sample.Module, :add, [1, 2]})

    :ok
  end

  defp connect_wifi(ssid, psk, pid \\ self()) do
    {:ok, _} =
      :network.start_link(
        sta: [
          ssid: ssid,
          psk: psk,
          connected: fn -> IO.puts("WiFi connected!") end,
          got_ip: fn _info -> send(pid, :got_ip) end,
          disconnected: fn -> IO.puts("WiFi disconnected") end
        ]
      )

    IO.puts("Waiting for WiFi...")

    receive do
      :got_ip -> :ok
    end
  end
end
