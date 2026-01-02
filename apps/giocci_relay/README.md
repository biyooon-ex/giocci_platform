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

## How to build docker image

```bash
docker build --file Dockerfile --tag ghcr.io/pojiro/giocci_relay:0.1.0 ../../
```

## How to run docker container

```bash
docker run --mount type=bind,src=$PWD/config/giocci_relay.exs,dst=/root/_build/prod/rel/giocci_relay/giocci_relay.exs --mount type=bind,src=$PWD/config/zenoh.json,dst=/root/_build/prod/rel/giocci_relay/zenoh.json --rm ghcr.io/pojiro/giocci_relay:0.1.0
```
