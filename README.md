# edax_mcp_server

Edax Othello engine as an MCP (Model Context Protocol) server.

## Requirements

- **Dart SDK**: `3.12.0` or higher.
- **Edax Binaries**: The server requires `libedax` dynamic library and `eval.dat`.
  - Place dynamic libraries in `resources/dll/` (e.g., `libedax.so`, `libedax.universal.dylib`, `libedax-x64.dll`).
  - Place `eval.dat` in `resources/data/`.

## Setup

1. Clone this repository.
2. Install dependencies:
   ```bash
   dart pub get
   ```
3. Ensure the Edax binaries are in the `resources/` directory as described above.

## Tools

The server provides the following tools:

- `get_moves`: Get the current game moves in coordinate format (e.g., f5d6c5).
- `edax_hint`: Get suggested moves from Edax engine.
  - Arguments: `n` (integer, optional) - Number of hints to retrieve.
- `play_move`: Play a move in the current game.
  - Arguments: `move` (string, required) - The move to play (e.g., `f5`).

## Connection to LLM (MCP Client)

To use this server with an MCP client like Claude Desktop, add the following to your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "edax": {
      "command": "dart",
      "args": [
        "run",
        "path/to/edax_mcp_server/lib/main.dart"
      ]
    }
  }
}
```

Replace `path/to/edax_mcp_server` with the actual absolute path to your cloned repository.

### For Production (Compiled)

For better performance, you can compile the server to a native executable:

```bash
dart compile exe lib/main.dart -o edax_mcp_server
```

Then update your config:

```json
{
  "mcpServers": {
    "edax": {
      "command": "path/to/edax_mcp_server/edax_mcp_server",
      "args": []
    }
  }
}
```

## Development

### Run tests

```bash
dart test
```

### Static analysis

```bash
dart analyze
```
