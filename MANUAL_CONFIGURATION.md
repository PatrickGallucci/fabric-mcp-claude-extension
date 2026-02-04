# Manual Configuration Guide

If you prefer not to use the desktop extension package, or need to configure the Fabric MCP Server for other MCP clients, follow this guide.

## Prerequisites

- [.NET SDK 8.0](https://dotnet.microsoft.com/download) or later
- [Git](https://git-scm.com/)

## Building the Server

```bash
# Clone the Microsoft MCP repository
git clone https://github.com/microsoft/mcp.git
cd mcp

# Build the Fabric MCP Server
dotnet build servers/Fabric.Mcp.Server/src/Fabric.Mcp.Server.csproj -c Release

# (Optional) Publish as self-contained executable
dotnet publish servers/Fabric.Mcp.Server/src/Fabric.Mcp.Server.csproj \
    -c Release \
    -r win-x64 \  # or osx-x64, osx-arm64, linux-x64
    --self-contained true \
    -p:PublishSingleFile=true \
    -o ./publish
```

## Claude Desktop Configuration

Edit your Claude Desktop configuration file:

**macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`

**Windows:** `%APPDATA%\Claude\claude_desktop_config.json`

### Option 1: Using dotnet run (Development)

```json
{
  "mcpServers": {
    "fabric": {
      "command": "dotnet",
      "args": [
        "run",
        "--project",
        "/absolute/path/to/mcp/servers/Fabric.Mcp.Server/src/Fabric.Mcp.Server.csproj",
        "--no-build"
      ]
    }
  }
}
```

### Option 2: Using Published Executable

```json
{
  "mcpServers": {
    "fabric": {
      "command": "/absolute/path/to/publish/Fabric.Mcp.Server"
    }
  }
}
```

**Windows:**
```json
{
  "mcpServers": {
    "fabric": {
      "command": "C:\\path\\to\\publish\\Fabric.Mcp.Server.exe"
    }
  }
}
```

## VS Code Configuration

For VS Code with GitHub Copilot or similar MCP-compatible extensions, add to your settings:

```json
{
  "mcp.servers": {
    "fabric": {
      "command": "dotnet",
      "args": [
        "run",
        "--project",
        "/absolute/path/to/mcp/servers/Fabric.Mcp.Server/src/Fabric.Mcp.Server.csproj"
      ]
    }
  }
}
```

## Cursor Configuration

Edit `~/.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "fabric": {
      "command": "dotnet",
      "args": [
        "run",
        "--project",
        "/path/to/mcp/servers/Fabric.Mcp.Server/src/Fabric.Mcp.Server.csproj"
      ]
    }
  }
}
```

## Testing the Server

You can test the server is working correctly:

```bash
# Test with MCP Inspector
npx @modelcontextprotocol/inspector dotnet run \
    --project /path/to/mcp/servers/Fabric.Mcp.Server/src/Fabric.Mcp.Server.csproj

# Or run directly to verify it starts
dotnet run --project /path/to/mcp/servers/Fabric.Mcp.Server/src/Fabric.Mcp.Server.csproj \
    -- platform get-platform-apis
```

## Troubleshooting

### "dotnet: command not found"

Ensure .NET SDK is installed and in your PATH:
```bash
export PATH="$PATH:$HOME/.dotnet"
```

### "Project file not found"

Verify the path to the `.csproj` file is correct and use absolute paths.

### Server doesn't start

Check the Claude Desktop logs:
- **macOS:** `~/Library/Logs/Claude/`
- **Windows:** `%APPDATA%\Claude\logs\`

### Configuration not taking effect

Restart Claude Desktop after editing the configuration file.
