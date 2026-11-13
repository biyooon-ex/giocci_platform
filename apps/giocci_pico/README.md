# GiocciPico

GiocciPico is an Elixir library for interacting with the GiocciPlatform. It allows you to save Elixir modules to remote engines and execute their functions across the network.

## Giocci との違い

[Giocci](https://github.com/biyooon-ex/giocci_platform/blob/main/apps/giocci/README.md) が UNIX 上で動作するのに対し、
GiocciPico は [ZenohexPico](https://github.com/biyooon-ex/zenohex_pico) を利用し、
AtomVM 上で GiocciPlatform のクライアントとして動作します。

GiocciPico はクライアントの登録、モジュールの保存、関数の同期実行をサポートしています。
一方、Giocci の以下の関数には対応していません。

- `exec_func_async/4`（非同期実行）

## 前提条件

GiocciPico を使用するには、接続可能な Zenoh ルーター（zenohd）と、
GiocciRelay および GiocciEngine が必要です。各コンポーネントの導入方法は
[GiocciPlatform の README](https://github.com/biyooon-ex/giocci_platform/blob/main/README.md) を参照してください。

また、GiocciPico が利用する ZenohexPico には、zenoh-pico を組み込んだ AtomVM が必要です。
以下の手順で、アプリケーションと対象デバイスに対応する AtomVM を用意します。

1. AtomVM 用の Elixir プロジェクトを作成し、アプリケーションを実装する
2. zenoh-pico を組み込んだ AtomVM をデバイスに書き込む
3. アプリケーションをデバイスに書き込む

## セットアップ

### AtomVM 用の Elixir プロジェクトの作成と実装

TODO: GiocciPicoExample リポジトリを作り、そちらを参照させる

[GiocciPicoExample](https://github.com/biyooon-ex/giocci_pico_example) リポジトリでは、
Wi-Fi と zenohd への接続、GiocciPico の起動、クライアント登録、
モジュールの保存、関数の実行を行っています。
接続先やクライアント名などは利用環境に合わせて設定してください。

注意：AtomVM で使用できる Elixir の機能には制限があります。たとえば、`String` モジュールはサポートされていません。アプリケーションの実装時はこれらの制限に注意してください。詳細は [AtomVM のリポジトリ](https://github.com/atomvm/AtomVM) を参照してください。

`apps/giocci_pico` 自体は `avm_esp32` をデフォルトターゲットに設定していますが、
依存関係として利用する場合は、その設定は利用側のプロジェクトには引き継がれません。
利用側のプロジェクトでデフォルトターゲットを `avm_esp32` に設定していない場合は、
依存関係を取得する前に以下を実行し、以降の Mix コマンドでも同じ設定を使用してください。

```sh
export MIX_TARGET=avm_esp32
```

### zenoh-pico を組み込んだ AtomVM の書き込み

作成したプロジェクトで依存関係を取得した後、`mix.lock` で GiocciPico が利用する ZenohexPico のバージョンを確認し、
対応する [ZenohexPico のリリース](https://github.com/biyooon-ex/zenohex_pico/releases) から
対象デバイス向けの ZIP ファイルをダウンロードしてください。
対応デバイスはリリースによって異なるため、各リリースで確認してください。

ZIP ファイルを展開し、展開先に含まれる README に従って AtomVM をデバイスに書き込んでください。
展開先（※1）は、以降の手順でも使用します。

### アプリケーションの書き込み

展開先（※1）に含まれる `avm_deps` を、AtomVM 用の Elixir プロジェクトのルートディレクトリにコピーしてください。
既存の `avm_deps` がある場合は、必要なファイルをバックアップしてから、
展開先の AtomVM に対応する `avm_deps` に置き換えてください。

次に、ESP32 の場合はプロジェクトのルートディレクトリで以下のコマンドを実行し、
アプリケーションをパックしてデバイスに書き込みます。
`/dev/your.usbserial` はデバイスに対応するシリアルポートに置き換えてください。

```sh
mix atomvm.packbeam
mix atomvm.esp32.flash --port /dev/your.usbserial --baud 921600
```

Mix タスクの詳細は [ExAtomVM](https://github.com/atomvm/exatomvm) を参照してください。

書き込みを繰り返す場合は、プロジェクトの `mix.exs` の `project/0` に
以下のようなエイリアスを追加すると便利です。

```elixir
def project do
  [
    # 他の設定
    aliases: [
      flash: [
        "atomvm.packbeam",
        "atomvm.esp32.flash --port /dev/your.usbserial --baud 921600"
      ]
    ]
  ]
end
```

ポートを設定した後、`mix flash` でパックと書き込みを実行できます。

GiocciPico の使い方は以上です。楽しんでください！
