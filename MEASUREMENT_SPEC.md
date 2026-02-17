# 計測機能仕様書

## 概要

Giocci プラットフォームに通信時間の計測機能を追加する。Client-Relay-Engine 間の通信時間を片道ずつ計測し、リアルタイムで結果を取得できるようにする。

## 対象機能

計測対象は以下の 2 つの関数：
- `register_client/2`
- `save_module/2`

## 計測範囲

### `register_client` の計測

- **Client ↔ Relay**: Client から Relay への通信時間と、Relay から Client への応答時間（別々に計測）
- **計測値**: `client_to_relay`, `relay_to_client`

### `save_module` の計測

- **Client ↔ Relay**: Client から Relay への通信時間と、Relay から Client への応答時間（別々に計測）
- **Relay ↔ Engine**: Relay から Engine への通信時間と、Engine から Relay への応答時間（別々に計測）
- **計測値**: `client_to_relay`, `relay_to_client`, `relay_to_engine`, `engine_to_relay`

**計測単位**: ミリ秒（milliseconds）

計測は片道ずつ実施し、複数のステップがある場合でも各ステップの結果を別々に返す。

## 計測オプション

計測機能はオプションとして動作し、デフォルトは無効状態。

### 有効化方法

関数呼び出し時に Zenohex に渡す直前に `measure: true` フラグを指定する。Client側で計測の有効化を判定し、Zenohex 呼び出し前後で時刻を記録する。

```elixir
# Client側
result = Giocci.register_client(relay_name, measure: true)
result = Giocci.save_module(relay_name, module, measure: true)
```

## 戻り値の形式

### 計測オプション有効かつ成功時

計測オプションが有効で、処理が成功した場合、戻り値は以下の構造となる：

```elixir
# register_client の場合（Relay とのみ通信）
{:ok, measurements} = Giocci.register_client(relay_name, measure: true)

measurements = %{
  "client_to_relay" => elapsed_time_ms,      # Client → Relay の通信時間
  "relay_to_client" => elapsed_time_ms       # Relay → Client の応答時間
}

# save_module の場合（Relay → Engine 通信も含む）
{:ok, measurements} = Giocci.save_module(relay_name, module, measure: true)

measurements = %{
  "client_to_relay" => elapsed_time_ms,      # Client → Relay の通信時間
  "relay_to_client" => elapsed_time_ms,      # Relay → Client の応答時間
  "relay_to_engine" => elapsed_time_ms,      # Relay → Engine の通信時間
  "engine_to_relay" => elapsed_time_ms       # Engine → Relay の応答時間
}
```

### 計測オプションなし（従来の動作）

計測オプションがない場合は、従来通り `:ok` または `{:error, reason}` を返す：

```elixir
:ok = Giocci.register_client(relay_name)
:ok = Giocci.save_module(relay_name, module)
```

### エラーが発生した場合

タイムアウトやネットワークエラーが発生した場合は、計測オプション有効/無効にかかわらず、従来のエラータプル形式で返される。計測データは含まれない：

```elixir
{:error, "timeout: ..."} = Giocci.register_client(relay_name, measure: true)
{:error, "connection_failed: ..."} = Giocci.save_module(relay_name, module, measure: true)
```

## 計測時刻の取得方法

タイムスタンプベースの計測により、各層で片道ずつの通信時間を正確に算出する。

- **時刻取得**: `System.system_time(:millisecond)` を使用（異なるErlang VM間で時刻比較可能）
- **計測の基本原理**: 送信側がペイロードにタイムスタンプを含める → 受信側が受け取り時刻を記録 → 差分で通信時間を算出

## 計測ポイント

### Client → Relay の通信時間計測

1. **Client 側（送信）**
   - `measure: true` を指定してリクエストを構成
   - Zenohex GET 実行直前に `client_send_timestamp_to_relay = System.system_time(:millisecond)` を記録
   - ペイロードに `client_send_timestamp_to_relay` を含める

2. **Relay 側（受信）**
   - ペイロードから `client_send_timestamp_to_relay` を抽出
   - 受信時に `relay_recv_timestamp_from_client = System.system_time(:millisecond)` を記録
   - 片道時間 = `relay_recv_timestamp_from_client - client_send_timestamp_to_relay`

### Relay → Client の応答時間計測

1. **Relay 側（送信）**
   - 応答ペイロード準備時に `relay_send_timestamp_to_client = System.system_time(:millisecond)` を記録
   - ペイロードに `relay_send_timestamp_to_client` を含める

2. **Client 側（受信）**
   - Zenohex GET の応答を受け取った直後に `client_recv_timestamp_from_relay = System.system_time(:millisecond)` を記録
   - ペイロードから `relay_send_timestamp_to_client` を抽出
   - 片道時間 = `client_recv_timestamp_from_relay - relay_send_timestamp_to_client`

### Relay → Engine の通信時間計測（save_module のみ）

1. **Relay 側（送信）**
   - Zenohex GET 実行直前に `relay_send_timestamp_to_engine = System.system_time(:millisecond)` を記録
   - ペイロードに含める

2. **Engine 側（受信）**
   - 受信時に `engine_recv_timestamp_from_relay = System.system_time(:millisecond)` を記録
   - ペイロードに含めて応答

3. **Relay 側（受信・計算）**
   - Engine の応答ペイロードから `engine_recv_timestamp_from_relay` を抽出
   - 片道時間 = `engine_recv_timestamp_from_relay - relay_send_timestamp_to_engine`

### Engine → Relay の応答時間計測（save_module のみ）

1. **Engine 側（送信）**
   - 応答直前に `engine_send_timestamp_to_relay = System.system_time(:millisecond)` を記録
   - ペイロードに含める

2. **Relay 側（受信・計算）**
   - Zenohex GET の応答受け取り時に `relay_recv_timestamp_from_engine = System.system_time(:millisecond)` を記録
   - ペイロードから `engine_send_timestamp_to_relay` を抽出
   - 片道時間 = `relay_recv_timestamp_from_engine - engine_send_timestamp_to_relay`

## ペイロード設計

### Client が Relay に送信するペイロード

```elixir
# measure: true の場合
send_term = %{
  client_name: client_name,
  # ... その他のデータ（module_object_code など）...
  measure: true,                                        # 計測フラグ
  client_send_timestamp_to_relay: System.system_time(:millisecond)  # Client 送信時刻
}
```

### Relay が Client に応答するペイロード

```elixir
# 成功時（measure: true を受け取った場合）
response = %{
  result: :ok,
  measure: true,                                            # 計測フラグの応答
  relay_send_timestamp_to_client: System.system_time(:millisecond),  # Relay 送信時刻
  relay_recv_timestamp_from_client: relay_recv_timestamp_from_client, # Relay 受信時刻（Client が client_to_relay 計算用）
  relay_to_engine: relay_to_engine_time,                  # Relay -> Engine の通信時間（save_module のみ）
  engine_to_relay: engine_to_relay_time                   # Engine -> Relay の応答時間（save_module のみ）
}
```

### Relay が Engine に送信するペイロード（save_module のみ）

```elixir
# measure: true を受け取った場合
send_term_to_engine = %{
  # ... その他のデータ（module_object_code など）...
  measure: true,
  relay_send_timestamp_to_engine: System.system_time(:millisecond)  # Relay 送信時刻
}
```

### Engine が Relay に応答するペイロード（save_module のみ）

```elixir
# measure: true を受け取った場合
response_from_engine = %{
  result: :ok,
  measure: true,
  engine_send_timestamp_to_relay: System.system_time(:millisecond),  # Engine 送信時刻
  engine_recv_timestamp_from_relay: engine_recv_timestamp_from_relay  # Engine 受信時刻（Relay が relay_to_engine 計算用）
}
```

### 計測値の流れ

1. **Client → Relay**
   - Client: `client_send_timestamp_to_relay` をペイロードに含めて送信
   - Relay: 受信時刻を記録し、Client → Relay 時間を算出
   - Relay: `relay_send_timestamp_to_client` をペイロードに含めて応答
   - Client: 受信時刻を記録し、Relay → Client 時間を算出

2. **Relay → Engine（save_module のみ）**
   - Relay: `relay_send_timestamp_to_engine` をペイロードに含めて送信
   - Engine: 受信時刻を記録し、`engine_recv_timestamp_from_relay` をペイロードに含めて応答
   - Relay: Relay → Engine 時間を算出
   - Engine: `engine_send_timestamp_to_relay` をペイロードに含める
   - Relay: Engine → Relay 時間を算出

3. **計測値の集約**
   - Relay は計測値をまとめて Client への応答に含める
   - Client は受け取った計測値をすべてマージして、最終的な計測結果を返す

## 実装方針

### Client 層（`apps/giocci`）

1. `Giocci.Worker.handle_call/3` で `measure` オプションを抽出
2. `measure: true` の場合：
   - `client_send_timestamp_to_relay = System.system_time(:millisecond)` を記録
   - リクエストペイロードに `measure` と `client_send_timestamp_to_relay` を含める
   - `Utils.zenohex_get()` を呼び出し
   - 応答受信後に `client_recv_timestamp_from_relay = System.system_time(:millisecond)` を記録
   - レスポンスペイロードから以下を抽出：
     - `relay_send_timestamp_to_client` と `relay_recv_timestamp_from_client`
     - `client_to_relay = relay_recv_timestamp_from_client - client_send_timestamp_to_relay` を計算
     - `relay_to_client = client_recv_timestamp_from_relay - relay_send_timestamp_to_client` を計算
   - `save_module` の場合、レスポンスペイロードから `relay_to_engine`, `engine_to_relay` を抽出
   - すべての計測値を map で構成し、`{:ok, measurements}` で返す
3. タイムアウトやエラーが発生した場合は、従来の `{:error, reason}` を返す

### Relay 層（`apps/giocci_relay`）

1. リクエストペイロードから `measure` フラグを抽出
2. `measure: true` の場合：
   - ペイロードから `client_send_timestamp_to_relay` を抽出
   - `relay_recv_timestamp_from_client = System.system_time(:millisecond)` を記録（Client → Relay 受信完了）
   - `relay_send_timestamp_to_client = System.system_time(:millisecond)` を記録（Relay → Client 送信直前）
   - レスポンスペイロードに以下を含める：
     - `measure`, `relay_send_timestamp_to_client`, `relay_recv_timestamp_from_client`
3. `save_module` の場合、Relay → Engine 通信も計測：
   - Relay が Engine にリクエスト送信直前に、新たに `relay_send_timestamp_to_engine = System.system_time(:millisecond)` を記録
   - Engine からの応答ペイロードから `engine_recv_timestamp_from_relay` を抽出
   - `relay_to_engine = engine_recv_timestamp_from_relay - relay_send_timestamp_to_engine` を計算
   - Engine からの応答ペイロードから `engine_send_timestamp_to_relay` を抽出
   - Zenohex GET 応答受け取り直後に `relay_recv_timestamp_from_engine = System.system_time(:millisecond)` を記録
   - `engine_to_relay = relay_recv_timestamp_from_engine - engine_send_timestamp_to_relay` を計算
   - `relay_to_engine`, `engine_to_relay` を Client への応答ペイロードに含める

### Engine 層（`apps/giocci_engine`）

1. リクエストペイロードから `measure` フラグを抽出
2. `measure: true` の場合：
   - Zenohex でリクエストが到着した直後に `engine_recv_timestamp_from_relay = System.system_time(:millisecond)` を記録
   - 応答送信直前に `engine_send_timestamp_to_relay = System.system_time(:millisecond)` を記録
   - レスポンスペイロードに `measure`, `engine_send_timestamp_to_relay`, `engine_recv_timestamp_from_relay` を含める

### 設計原則

- **タイムスタンプベース**: ペイロードにタイムスタンプを含めることで、各層での片道計測を正確に実現
- **非侵襲的な設計**: 既存ロジックに最小限の変更
- **ペイロードベース**: 計測値をペイロードに乗せることで、各層での計測結果を統合
- **エラー安全性**: エラー発生時は計測データなしで従来通り返す

## 拡張性

- 将来的に計測結果をデータベースやモニタリングサービスに送信する場合は、`Measurement` モジュールを拡張
- 複数の計測戦略に対応できるように設計

## 注意事項

- `System.system_time(:millisecond)` を使用しているため、異なるErlang VM間で時刻比較が可能
- 各サーバーの時刻が上位している場合、計測値に誤差が生じることに注意
- ネットワーク遅延を含めて計測される
- 計測結果は大容量ログにはならない（微小な追加）
