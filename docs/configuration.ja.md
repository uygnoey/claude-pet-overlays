# 設定

[English](configuration.md) · [한국어](configuration.ko.md) · [Español](configuration.es.md) · **日本語**

Claude Pet Overlays は、環境変数、Claude Pet の既存の `~/.claude_pet.json` ファイル、そして Claude Code のフックイベントを通じて設定します。

## フックイベント

このプラグインは 2 つの Claude Code フックパスを処理します。

| フック | イベント | 動作 |
| --- | --- | --- |
| `Stop` | `stop` | Claude Code が応答を終えたときにオーバーレイを表示します。 |
| `AskUserQuestion` を伴う `PreToolUse` | `ask` | Claude Code がユーザー入力を待っているときにオーバーレイを表示します。 |

`ask` 以外のイベントは `scripts/notify.sh` によってすべて `stop` に正規化されます。

## オーバーレイの環境変数

| 変数 | デフォルト | 説明 |
| --- | --- | --- |
| `CLAUDE_PLUGIN_ROOT` | `scripts/notify.sh` が推測するリポジトリルート | プラグインのルート。インストール済みプラグインでは通常 Claude Code が設定します。 |
| `CLAUDE_PET_OVERLAY_LANG` | 自動検出 | オーバーレイの言語を強制します。`en`、`ko`、`es` などに対応します。 |
| `CLAUDE_PET_LANG` | 自動検出 | Claude Pet と共有するフォールバックの言語上書き値。 |
| `CLAUDE_PET_OVERLAY_TIMEOUT` | `18` | オーバーレイが自動で閉じるまでの秒数。`0` にするとクリックまたはキー入力まで表示し続けます。 |
| `CLAUDE_PET_OVERLAY_MESSAGE` | イベントごとのデフォルト | デフォルトのオーバーレイメッセージを置き換えます。 |

言語検出の順序:

1. `CLAUDE_PET_OVERLAY_LANG`
2. `CLAUDE_PET_LANG`
3. `~/.claude_pet.json` の `lang`
4. macOS の優先言語
5. 英語

## トークン上限の環境変数

これらの値は、オーバーレイがローカルの Claude Code ログにフォールバックしたときにのみ使用されます。

| 変数 | デフォルト | 説明 |
| --- | --- | --- |
| `CLAUDE_PET_SESSION_LIMIT` | `8000000` | 推定 5 時間セッションのトークン上限。 |
| `CLAUDE_PET_WEEKLY_LIMIT` | `60000000` | 推定週間トークン上限。 |
| `CLAUDE_PET_OPUS_LIMIT` | `15000000` | 推定モデルファミリー週間トークン上限。 |
| `CLAUDE_PET_MODEL` | `auto` | 3 番目のゲージのモデルキーワード。`auto` は最近のログに現れたプレミアムファミリーを選び、なければ `opus` にフォールバックします。 |

## `~/.claude_pet.json`

このファイルが存在すると、オーバーレイは既存の Claude Pet のキャリブレーション値を読み取ります。

```json
{
  "lang": "ko",
  "session_limit": 8000000,
  "weekly_limit": 60000000,
  "opus_limit": 15000000,
  "model_keyword": "opus",
  "weekly_reset_day": 0,
  "weekly_reset_hour": 20
}
```

対応キー:

| キー | 説明 |
| --- | --- |
| `lang` | UI 言語。英語・韓国語・スペイン語のエイリアスに対応します。 |
| `session_limit` | ローカルログモード用の推定 5 時間セッション上限。 |
| `weekly_limit` | ローカルログモード用の推定週間上限。 |
| `opus_limit` | ローカルログモード用の推定モデルファミリー上限。 |
| `model_keyword` | 3 番目のローカルログゲージに使うモデル名の部分文字列。 |
| `weekly_reset_day` | Claude Pet 互換ロジックで使う週間リセットの曜日インデックス。月曜が `0`、日曜が `6`。 |
| `weekly_reset_hour` | ローカル時間での週間リセット時刻。デフォルトは `20`。 |

環境変数のトークン上限が先に読み取られ、`~/.claude_pet.json` に値がある場合はそれで上書きされます。

## 使用量のソース

オーバーレイはまず正確な使用量の取得を試みます。

1. `~/.claude/.credentials.json` から OAuth アクセストークンを読み取る
2. 利用できない場合は `/usr/bin/security` で macOS キーチェーンの `Claude Code-credentials` を読み取る
3. `https://api.anthropic.com/api/oauth/usage` から使用量パーセンテージを取得する

正確な使用量が得られない場合は、ローカルの Claude Code JSONL ログから使用量を推定します。

- `~/.claude/projects`
- `~/.config/claude/projects`

ローカルログモードは最近の `.jsonl` ファイルをスキャンし、リクエスト/メッセージ ID を重複排除したうえで、次の重み付けで使用量を計算します。

| 使用量フィールド | 重み |
| --- | --- |
| `input_tokens` | `1.0` |
| `output_tokens` | `5.0` |
| `cache_creation_input_tokens` | `1.25` |
| `cache_read_input_tokens` | `0.1` |

## アニメーションルール

アニメーションは最も高いゲージのパーセンテージに基づいて選択されます。

| 条件 | アニメーション |
| --- | --- |
| `85%` 以上 | `failed` |
| `50%` 〜 `84%` | `waiting` |
| `50%` 未満の `ask` イベント | `review` |
| `50%` 未満の `stop` イベント | `waving` |

緊急度の高い状態ほどフレーム間隔がやや速くなります。

| アニメーション | 間隔 |
| --- | --- |
| `failed` | `0.16s` |
| `waiting` | `0.20s` |
| `review` | `0.24s` |
| `waving` | `0.26s` |
| その他のフォールバック状態 | `0.28s` |
