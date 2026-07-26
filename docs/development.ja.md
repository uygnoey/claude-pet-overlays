# 開発

[English](development.md) · [한국어](development.ko.md) · [Español](development.es.md) · **日本語**

このリポジトリは意図的に小さく保たれています。Claude Code のフックがシェルスクリプトを呼び出し、スクリプトが 1 つのネイティブ Swift バイナリをビルドまたは起動し、バイナリが同梱の PNG フレームでオーバーレイを描画します。

## プロジェクト構成

| パス | 用途 |
| --- | --- |
| `.claude-plugin/plugin.json` | Claude Code プラグインのメタデータ。 |
| `.claude-plugin/marketplace.json` | ローカルマーケットプレイスのメタデータ。 |
| `hooks/hooks.json` | Claude Code フックの登録。 |
| `scripts/notify.sh` | フックのエントリポイント。イベントを正規化し、初回実行時にビルドし、オーバーレイをバックグラウンドで起動します。 |
| `scripts/build.sh` | `swiftc` で `src/ClaudePetOverlay.swift` をビルドします。 |
| `src/ClaudePetOverlay.swift` | AppKit オーバーレイ、言語処理、トークンスキャン、ゲージ描画、アニメーション選択。 |
| `frames/` | 同梱の Claude Pet アニメーションフレーム。 |
| `frames/frames-manifest.json` | 同梱アセットのソースとフレーム一覧。 |
| `bin/` | ローカルビルドの出力。git では無視されます。 |

## ビルド

```bash
bash scripts/build.sh
```

ビルドスクリプトの動作:

1. macOS を必要とします。
2. `swiftc` を必要とします。
3. Cocoa フレームワークで `src/ClaudePetOverlay.swift` をコンパイルします。
4. `bin/claude-pet-overlay` を生成します。

## ローカルテスト

```bash
bash scripts/notify.sh stop
bash scripts/notify.sh ask
CLAUDE_PET_OVERLAY_TIMEOUT=0 bash scripts/notify.sh stop
CLAUDE_PET_OVERLAY_MESSAGE="Custom message" bash scripts/notify.sh ask
```

フックの失敗が Claude Code を中断させてはならないため、`notify.sh` はローカルビルドが失敗しても正常終了します。ビルドエラーは次のファイルに追記されます。

```text
${TMPDIR:-/tmp}/claude-pet-overlays.log
```

## フックのライフサイクル

Claude Code は `hooks/hooks.json` のコマンドを実行します。

```json
{
  "Stop": "bash \"${CLAUDE_PLUGIN_ROOT}/scripts/notify.sh\" stop",
  "PreToolUse AskUserQuestion": "bash \"${CLAUDE_PLUGIN_ROOT}/scripts/notify.sh\" ask"
}
```

`notify.sh` は次のようにネイティブバイナリを起動します。

```bash
bin/claude-pet-overlay --root "$ROOT" --event "$EVENT" --timeout "$TIMEOUT"
```

`CLAUDE_PET_OVERLAY_MESSAGE` が設定されている場合は、さらに次を渡します。

```bash
--message "$CLAUDE_PET_OVERLAY_MESSAGE"
```

ネイティブアプリは次の場所に一時ロックを使用します。

```text
${TMPDIR:-/tmp}/claude-pet-overlays.lock
```

すでに別のオーバーレイが実行中の場合、新しいプロセスは 2 つ目のオーバーレイを表示せずに終了します。

## アセット

アニメーションフレームは `frames/<state>/NN.png` の下にあります。

現在のマニフェストが想定する内容:

| 状態 | フレーム数 |
| --- | --- |
| `failed` | `8` |
| `idle` | `6` |
| `jumping` | `5` |
| `review` | `6` |
| `running` | `6` |
| `running-left` | `8` |
| `running-right` | `8` |
| `waiting` | `6` |
| `waving` | `4` |

オーバーレイは `frames/<選択された状態>` を読み込み、その状態のディレクトリが存在しない場合は `frames/idle` にフォールバックします。

## トラブルシューティング

### 何も表示されない

実行:

```bash
bash scripts/build.sh
bash scripts/notify.sh stop
```

その後に確認:

```bash
tail -n 100 "${TMPDIR:-/tmp}/claude-pet-overlays.log"
```

### `swiftc` が見つからない

Xcode Command Line Tools をインストール:

```bash
xcode-select --install
```

### トークンゲージが表示されない

使用量データがなくてもオーバーレイは表示されます。ゲージには次のいずれかが必要です。

- `~/.claude/.credentials.json` で利用可能な Claude Code の OAuth 認証情報
- macOS キーチェーンで利用可能な Claude Code の認証情報
- `~/.claude/projects` または `~/.config/claude/projects` 下の最近の Claude Code JSONL ログ

### 言語が正しくない

1 回の実行に対して言語を強制:

```bash
CLAUDE_PET_OVERLAY_LANG=ko bash scripts/notify.sh stop
```

対応値には `en`、`ko`、`es` が含まれます。
