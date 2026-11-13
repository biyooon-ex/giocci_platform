# For developers

## Elixir features not supported by AtomVM

GiocciPico provides alternative implementations because AtomVM does not support the following Elixir features:

- The `String` module
- The `uniq` and `reverse` functions in `Enum`

These features may be supported in a future AtomVM update.
If they are supported, rewrite GiocciPico's implementation to match Giocci's.
