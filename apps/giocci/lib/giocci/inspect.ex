defmodule Giocci.Inspect do
  @moduledoc """
  Read-only inspection of this client and Giocci relays and engines.

  Inspection does not register clients, save modules, or execute application
  functions. The client application and its Zenoh session must be running, but
  remote queries do not require a prior `Giocci.register_client/1` call.
  Module queries use this configured client name; it is not access control.

  Results are snapshots and registration lists do not guarantee reachability.
  Remote operations accept `timeout: milliseconds` (default: `5_000`).
  A responsive relay with no matching records returns `{:ok, []}`; a
  communication failure does not. Remote queries require a compatible
  relay or engine. Module queries describe saved relay BEAMs, not engine
  distribution or execution.

  `relay_info/2` and `engine_info/2` return `:name`, `:giocci_version`,
  `:elixir_version`, `:otp_release`, `:system_architecture`, `:uptime_ms`
  (since the target application started), and `:schedulers_online` (BEAM
  schedulers, not allocated vCPUs). Engine information and ping query the
  engine directly, without a relay name. Relay information and ping work
  without registered engines. Ping measures Giocci Query/Reply round-trip
  time using the client's monotonic clock; it includes waiting and response
  processing, not ICMP timing.
  """

  alias Giocci.Utils
  alias Giocci.Worker

  @default_timeout 5_000

  @doc """
  Returns this client's name and key prefix, its Zenoh ID, and the router and
  peer IDs known to its own session. It does not query a relay or describe
  the entire network; zero connected routers can be normal in a peer setup.

  Returns `{:ok, %{client_name: name, key_prefix: prefix, zenoh_id: id,
  router_ids: routers, peer_ids: peers}}` or `{:error, reason}`.
  """
  def connection_info do
    %{client_name: client_name, key_prefix: key_prefix} = Worker.inspection_info()

    with {:ok, info} <- Zenohex.Session.info(Giocci.SessionManager.session_id()) do
      {:ok,
       %{
         client_name: client_name,
         key_prefix: key_prefix,
         zenoh_id: info.zid,
         router_ids: info.routers_zid |> Enum.uniq() |> Enum.sort(),
         peer_ids: info.peers_zid |> Enum.uniq() |> Enum.sort()
       }}
    end
  end

  @doc """
  Compares relays this client has successfully registered with each relay's
  current record for this client's name. The result is sorted by relay name.

  Returns `{:ok, []}` if there is no local history, `{:ok, confirmed_relays}`
  if all candidates agree, `{:warn, confirmed_relays, issues}` if some
  agree, or `{:error, issues}` if none can be confirmed. Each issue has
  `%{relay: name, reason: reason}`; a relay that responds without this
  client's registration reports `"client_not_registered"`, while a relay
  without a response reports its timeout or connection error.

  `:timeout` applies separately to each candidate relay (default: 5_000 ms).
  """
  def list_relays(opts \\ []) do
    %{registered_relays: relays} = Worker.inspection_info()

    {confirmed, issues} =
      relays
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.reduce({[], []}, fn relay, {confirmed, issues} ->
        case request(:relay, relay, :client_registered?, nil, opts) do
          {:ok, true} -> {[relay | confirmed], issues}
          {:ok, false} -> {confirmed, [%{relay: relay, reason: "client_not_registered"} | issues]}
          {:ok, _} -> {confirmed, [%{relay: relay, reason: "unexpected_reply"} | issues]}
          {:error, reason} -> {confirmed, [%{relay: relay, reason: reason} | issues]}
        end
      end)

    confirmed = Enum.reverse(confirmed)
    issues = Enum.reverse(issues)

    case {confirmed, issues} do
      {[], []} -> {:ok, []}
      {[], _} -> {:error, issues}
      {_, []} -> {:ok, confirmed}
      {_, _} -> {:warn, confirmed, issues}
    end
  end

  @doc """
  Returns the sorted, distinct engine names recorded at the specified relay.
  Returns `{:ok, []}` if none are registered. Use `ping_engine/2` to check
  whether an engine responds.
  """
  def list_engines(relay, opts \\ []) do
    request(:relay, relay, :list_engines, nil, opts)
  end

  @doc """
  Returns the sorted, distinct module names as strings (for example,
  `"Elixir.MyModule"`) saved at a relay under this configured client name,
  or `{:ok, []}` if none are saved.

  The list is based on the relay's stored BEAMs, not the client's loaded
  code. Names can be passed directly to `list_functions/3` or
  `module_info/3`. Other connections using the same client name share
  the stored namespace.
  """
  def list_modules(relay, opts \\ []) do
    request(:relay, relay, :list_modules, nil, opts)
  end

  @doc """
  Returns the saved BEAM's public callable functions as sorted
  `{name, arity}` tuples with string names (for example, `{"hello", 0}`).
  The module can be specified as an atom or a name returned by
  `list_modules/2`. Default-argument arities and public callbacks are
  included; private functions, macros, `module_info/0,1`,
  `__info__/1`, and `__struct__/0,1` are excluded. Other `__`-prefixed
  public functions are not excluded just because of their names.

  The relay analyzes the stored BEAM without loading or running the module.
  Returns `{:error, "module_not_found"}` for a missing saved module or
  `{:error, "invalid_beam"}` if its BEAM cannot be analyzed.
  """
  def list_functions(relay, module, opts \\ []) do
    request(:relay, relay, :list_functions, module, opts)
  end

  @doc """
  Returns `%{module: name, beam_sha256: hash, beam_size_bytes: size,
  saved_at: date_time}` for this client's BEAM saved at the relay.
  `:module` is a string even when the module argument is an atom; the
  argument can also be a name returned by `list_modules/2`.

  `beam_sha256` is the lowercase hexadecimal SHA-256 of the entire BEAM,
  `beam_size_bytes` is its size in bytes, and `saved_at` is a UTC
  `DateTime` from the relay's clock. It records the last successful relay
  save, including identical re-saves; inspection and distribution to a
  later-registered engine do not update it. Engine distribution failures
  do not undo a successful relay save. Functions are available separately
  via `list_functions/3`.

  Returns `{:error, "module_not_found"}` if the module is not saved under
  this client name, or `{:error, "invalid_beam"}` for an invalid saved BEAM.
  """
  def module_info(relay, module, opts \\ []) do
    request(:relay, relay, :module_info, module, opts)
  end

  @doc "Queries the specified relay's runtime information."
  def relay_info(relay, opts \\ []) do
    request(:relay, relay, :relay_info, nil, opts)
  end

  @doc "Queries an engine's runtime information by engine name."
  def engine_info(engine, opts \\ []) do
    request(:engine, engine, :engine_info, nil, opts)
  end

  @doc """
  Queries a relay directly and returns `{:ok, %{rtt_ms: milliseconds}}`
  when it responds.
  """
  def ping_relay(relay, opts \\ []) do
    ping(:relay, relay, opts)
  end

  @doc """
  Queries an engine by name and returns `{:ok, %{rtt_ms: milliseconds}}`
  when it responds.
  """
  def ping_engine(engine, opts \\ []) do
    ping(:engine, engine, opts)
  end

  defp ping(kind, name, opts) do
    started_at = System.monotonic_time(:microsecond)

    with {:ok, :pong} <- request(kind, name, :ping, nil, opts) do
      {:ok, %{rtt_ms: (System.monotonic_time(:microsecond) - started_at) / 1_000}}
    end
  end

  defp request(kind, name, operation, module, opts) do
    %{client_name: client_name, key_prefix: key_prefix} = Worker.inspection_info()
    session_id = Giocci.SessionManager.session_id()
    key = Path.join(key_prefix, "giocci/inspect/#{kind}/#{name}")
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    term = %{
      data: %{operation: operation, client_name: client_name, module: module},
      measurements: %{}
    }

    case Utils.zenohex_get(session_id, key, timeout, term, record_measurements: false) do
      {:ok, {:ok, %{data: value, measurements: _measurements}}} ->
        decode_value(operation, value, module)

      {:ok, {:error, reason}} ->
        {:error, reason}

      {:ok, _} ->
        {:error, "unexpected_reply"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp decode_value(:client_registered?, registered?, _module) when is_boolean(registered?),
    do: {:ok, registered?}

  defp decode_value(:list_engines, engines, _module) when is_list(engines) do
    if Enum.all?(engines, &is_binary/1), do: {:ok, engines}, else: {:error, "unexpected_reply"}
  end

  defp decode_value(:list_modules, modules, _module) when is_list(modules) do
    if Enum.all?(modules, &is_binary/1), do: {:ok, modules}, else: {:error, "unexpected_reply"}
  end

  defp decode_value(:list_functions, functions, _module) when is_list(functions) do
    if Enum.all?(functions, fn
         {name, arity} -> is_binary(name) and is_integer(arity) and arity >= 0
         _ -> false
       end) do
      {:ok, functions}
    else
      {:error, "unexpected_reply"}
    end
  end

  defp decode_value(
         :module_info,
         %{
           "module" => name,
           "beam_sha256" => hash,
           "beam_size_bytes" => size,
           "saved_at" => saved_at
         },
         module
       )
       when is_binary(name) and is_binary(hash) and is_integer(size) and size >= 0 and
              is_binary(saved_at) and
              (is_binary(module) or (is_atom(module) and not is_nil(module))) do
    with true <- name == module_name(module),
         true <- String.match?(hash, ~r/\A[0-9a-f]{64}\z/),
         {:ok, date_time, 0} <- DateTime.from_iso8601(saved_at) do
      {:ok, %{module: name, beam_sha256: hash, beam_size_bytes: size, saved_at: date_time}}
    else
      _ -> {:error, "unexpected_reply"}
    end
  end

  defp decode_value(operation, info, _module)
       when operation in [:relay_info, :engine_info] do
    case info do
      %{
        "name" => name,
        "giocci_version" => version,
        "elixir_version" => elixir_version,
        "otp_release" => otp_release,
        "system_architecture" => architecture,
        "uptime_ms" => uptime_ms,
        "schedulers_online" => schedulers_online
      } ->
        if Enum.all?([name, version, elixir_version, otp_release, architecture], &is_binary/1) and
             is_integer(uptime_ms) and uptime_ms >= 0 and is_integer(schedulers_online) and
             schedulers_online > 0 do
          {:ok,
           %{
             name: name,
             giocci_version: version,
             elixir_version: elixir_version,
             otp_release: otp_release,
             system_architecture: architecture,
             uptime_ms: uptime_ms,
             schedulers_online: schedulers_online
           }}
        else
          {:error, "unexpected_reply"}
        end

      _ ->
        {:error, "unexpected_reply"}
    end
  end

  defp decode_value(:ping, :pong, _module), do: {:ok, :pong}
  defp decode_value(_operation, _value, _module), do: {:error, "unexpected_reply"}

  defp module_name(module) when is_atom(module), do: Atom.to_string(module)
  defp module_name(module) when is_binary(module), do: module
end
