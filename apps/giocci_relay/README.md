# GiocciRelay

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `giocci_relay` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:giocci_relay, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/giocci_relay>.

## How to build/push docker image

```bash
docker compose build giocci_relay
docker compose push giocci_relay
```

## How to run docker container

```bash
docker compose run --rm giocci_relay
```
