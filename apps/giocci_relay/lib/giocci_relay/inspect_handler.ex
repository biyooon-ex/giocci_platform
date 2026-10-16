defmodule GiocciRelay.InspectHandler do
  @moduledoc false

  use GenServer

  alias GiocciRelay.Utils

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    relay_name = Keyword.fetch!(args, :relay_name)
    key_prefix = Keyword.get(args, :key_prefix, "")
    key = Path.join(key_prefix, "giocci/inspect/relay/#{relay_name}")
    session_id = GiocciRelay.SessionManager.session_id()
    {:ok, queryable_id} = Zenohex.Session.declare_queryable(session_id, key)

    {:ok,
     %{
       name: relay_name,
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

  defp inspect_request(%{operation: :client_registered?, client_name: client_name}, _state)
       when is_binary(client_name) do
    {:ok, GiocciRelay.ClientRegistrar.registered?(client_name)}
  end

  defp inspect_request(%{operation: :list_engines}, _state) do
    {:ok, GiocciRelay.EngineRegistrar.registered_engines() |> Enum.uniq() |> Enum.sort()}
  end

  defp inspect_request(%{operation: :list_modules, client_name: client_name}, _state)
       when is_binary(client_name) do
    with {:ok, modules} <- GiocciRelay.ModuleStore.list(client_name) do
      {:ok, Enum.map(modules, &Atom.to_string/1)}
    end
  end

  defp inspect_request(
         %{operation: :list_functions, client_name: client_name, module: module},
         _state
       )
       when is_binary(client_name) and is_atom(module) and not is_nil(module) do
    with {:ok, {{^module, beam, _filename}, _saved_at}} <-
           GiocciRelay.ModuleStore.fetch(client_name, module) do
      case :beam_lib.chunks(beam, [:exports]) do
        {:ok, {^module, [exports: exports]}} ->
          functions =
            exports
            |> Enum.reject(&generated_export?/1)
            |> Enum.uniq()
            |> Enum.sort()
            |> Enum.map(fn {name, arity} -> {Atom.to_string(name), arity} end)

          {:ok, functions}

        _ ->
          {:error, "invalid_beam"}
      end
    end
  end

  defp inspect_request(
         %{operation: :module_info, client_name: client_name, module: module},
         _state
       )
       when is_binary(client_name) and is_atom(module) and not is_nil(module) do
    with {:ok, {{^module, beam, _filename}, saved_at}} <-
           GiocciRelay.ModuleStore.fetch(client_name, module) do
      case :beam_lib.chunks(beam, [:exports]) do
        {:ok, {^module, _chunks}} ->
          {:ok,
           %{
             "module" => Atom.to_string(module),
             "beam_sha256" => :crypto.hash(:sha256, beam) |> Base.encode16(case: :lower),
             "beam_size_bytes" => byte_size(beam),
             "saved_at" => DateTime.to_iso8601(saved_at)
           }}

        _ ->
          {:error, "invalid_beam"}
      end
    end
  end

  defp inspect_request(%{operation: :relay_info}, state) do
    {:ok,
     %{
       "name" => state.name,
       "giocci_version" => :giocci_relay |> Application.spec(:vsn) |> to_string(),
       "elixir_version" => System.version(),
       "otp_release" => System.otp_release(),
       "system_architecture" => :erlang.system_info(:system_architecture) |> to_string(),
       "uptime_ms" => System.monotonic_time(:millisecond) - state.started_at_ms,
       "schedulers_online" => System.schedulers_online()
     }}
  end

  defp inspect_request(%{operation: :ping}, _state), do: {:ok, :pong}
  defp inspect_request(_request, _state), do: {:error, "term_not_expected"}

  defp generated_export?({name, arity}) do
    {name, arity} in [
      {:module_info, 0},
      {:module_info, 1},
      {:__info__, 1},
      {:__struct__, 0},
      {:__struct__, 1}
    ] or String.starts_with?(Atom.to_string(name), "MACRO-")
  end
end
