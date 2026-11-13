# For developers

## AtomVM がサポートしていない Elixir の機能について

AtomVM では以下の Elixir の機能がサポートされていないため、GiocciPico では代替実装をしています。

- `String` モジュール
- `Enum` の `uniq`、`reverse` 関数

これらの機能は、今後の AtomVM の更新でサポートされる可能性があります。
サポートされた場合は、GiocciPico の実装を Giocci と同等の実装に書き直してください。
