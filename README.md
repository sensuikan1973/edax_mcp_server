# edax_mcp_server

Edax Reversi エンジンを MCP サーバーとして提供します。

## 提供される機能

このサーバーは以下の MCP 機能を提供します。

### ツール (Tools)
オセロエンジンの操作や情報の取得が可能です。
- `get_moves`: 現在の棋譜を取得。
- `edax_hint`: エンジンによる推奨手を取得。
- `play_move`: 指定した手を打つ。
- `get_board`: 現在の盤面状態を取得。
- `play_print`: 盤面、石数、着手可能数などの要約を表示。

### リソース (Resources)
オセロに関する専門知識を AI に提供します。
- `日本オセロ連盟競技ルール`: 公式ルール、対局時計、勝敗記録方法など。
- `黒引き分け勝ち (オセロブログ)`: 戦略、序盤研究、Edax の使い方など。
- `統計的に見るオセロ (黒と白の勝率)`: 大規模データに基づく勝率統計。

### プロンプト (Prompts)
特定のタスクを AI に依頼するためのテンプレートです。
- `othello_knowledge`: オセロの知識（ルール、統計、戦略）を活用して回答を生成します。

## MCP クライアントへの接続

### VS Code (GitHub Copilot Chat)

VS Code で GitHub Copilot Chat を使用している場合、`mcp.json` 設定ファイルにサーバーを追加できます。

通常、設定ファイルは以下の場所にあります：
- **macOS**: `~/Library/Application Support/Code/User/globalStorage/github.copilot-chat/mcp.json`
- **Windows**: `%AppData%\Code\User\globalStorage\github.copilot-chat\mcp.json`
- **Linux**: `~/.config/Code/User/globalStorage/github.copilot-chat/mcp.json`

以下のように設定を追加してください：

```json
{
  "mcpServers": {
    "edax": {
      "command": "dart",
      "args": [
        "run",
        "/絶対パス/to/edax_mcp_server/lib/main.dart"
      ]
    }
  }
}
```

### Gemini CLI

Google の `gemini-cli` を使用している場合、`~/.gemini/settings.json` に設定を追加します。

```json
{
  "mcpServers": {
    "edax": {
      "command": "dart",
      "args": [
        "run",
        "/絶対パス/to/edax_mcp_server/lib/main.dart"
      ]
    }
  }
}
```

設定後、Gemini CLI を再起動し、`/mcp list` コマンドで接続を確認できます。

### 本番環境用 (コンパイル済みバイナリ)

パフォーマンス向上のため、サーバーをネイティブ実行ファイルにコンパイルして使用することをお勧めします：

```bash
dart compile exe lib/main.dart -o edax_mcp_server
```

その後、設定の `command` を生成されたバイナリのパスに変更し、`args` を空にしてください。
