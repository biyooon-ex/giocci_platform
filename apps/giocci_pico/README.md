# GiocciPico

GiocciPico is an Elixir library for interacting with the GiocciPlatform. It allows you to save Elixir modules to remote engines and execute their functions across the network.

## Giocci との違い

Giocci が UNIX で動作するのと違い、
GiocciPico は ZenohexPico を使い AtomVM 上で GiocciPlatform のクライアントとして動作します。　

また、 以下の関数をサポートしていません。

- `exec_func_asyn/4`

## Installation

GiocciPico を使うには、zenoh-pico が組み込まれた AtomVM をターゲット機に焼き込む必要があります。　
理由は、GiocciPico が ZenohexPico を利用し、 ZenohexPico はzenoh-pico が静的リンクされた AtomVM を要求するからです。

よって、GiocciPicoをご利用いただくために以下の順に作業をする必要があります。

1. zenoh-pico が静的リンクされたAtomVMのビルドとフラッシュ
2. AtomVM用のプロジェクトの作成
3. GiocciPico を利用するアプリケーションの実装

各手順を以下で順に説明します。

### zenoh-pico が静的リンクされたAtomVMのフラッシュ

GiocciPico が利用するZenohexPicoのバージョンに対応する
release page にあるターゲット機向けの zip をダウンロードしてください。

そして、解凍し他ディレクトリ（artifact と呼びます）に含まれるREADME.mdに従ってください。


### Elixir AtomVM プロジェクトの作成と実装

see. GiocciPicoExample リポジトリを作り、そちらを参照させる

### GiocciPico を利用するアプリケーションのフラッシュ

Elixir AtomVM プロジェクトのルートディレクトリに artifact に含まれる avm_deps をコピーしてください。 

次に以下のコマンドでパックし、ターゲット機にフラッシュします。

```sh
mix atomvm.packbeam
mix atomvm.esp32.flash --port /dev/your.usbserial --baud 921600"
```

以下のような alias を用意することがあなたの助けになるかもしれません。

```elixir
def project do
  [
    ...,
    aliases: [
      flash: [
        "atomvm.packbeam",
        "atomvm.esp32.flash --port /dev/your.usbserial --baud 921600"
      ]
    ]
  ]
end
```

GiocciPico の使い方は以上です。楽しんでください！
