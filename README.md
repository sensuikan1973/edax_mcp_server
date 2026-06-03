# edax_mcp_server

Edax Reversi エンジンを MCP (Model Context Protocol) サーバーとして提供します。

## 提供されるツール

サーバーは以下のツールを提供します:

- `get_moves`: 現在の棋譜を座標形式で取得します (例: f5d6c5)。
- `edax_hint`: Edax エンジンによる推奨手（ヒント）を取得します。
  - 引数: `n` (整数, 任意) - 取得するヒントの数。
- `play_move`: 指定した手を打ちます。
  - 引数: `move` (文字列, 必須) - 打つ手 (例: `f5`)。

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
