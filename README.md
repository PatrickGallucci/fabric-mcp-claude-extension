# Microsoft Fabric MCP Server - Desktop Extension

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![MCP](https://img.shields.io/badge/MCP-Compatible-green.svg)](https://modelcontextprotocol.io)
[![.NET](https://img.shields.io/badge/.NET-8.0-purple.svg)](https://dotnet.microsoft.com/)

A **local-first** Model Context Protocol (MCP) server that provides AI agents with comprehensive access to Microsoft Fabric's public APIs, item definitions, and best practices—all without connecting to live Fabric environments.

## Features

- **Complete API Coverage**: Full OpenAPI specifications for all Microsoft Fabric public APIs
- **Item Definition Knowledge**: JSON schemas for every Fabric item type (Lakehouses, pipelines, semantic models, notebooks, etc.)
- **Built-in Best Practices**: Embedded guidance on pagination, error handling, and recommended patterns
- **Local-First Security**: Runs entirely on your machine—never connects to your Fabric environment
- **Cross-Platform**: Supports Windows (x64), macOS (Intel), and macOS (Apple Silicon)

## Installation

### Quick Install (Pre-built Package)

1. Download the latest `.mcpb` file from the [Releases](https://github.com/microsoft/mcp/releases) page
2. Open **Claude Desktop**
3. Navigate to **Settings** → **Extensions**
4. Click **"Install Extension..."**
5. Select the downloaded `.mcpb` file
6. The extension will be immediately available

### Build from Source

#### Prerequisites

- [.NET SDK 8.0](https://dotnet.microsoft.com/download) or later
- [Git](https://git-scm.com/)
- PowerShell 7+ (Windows) or Bash (macOS/Linux)

#### Windows (PowerShell)

```powershell
# Clone this extension template
git clone <this-repo>
cd fabric-mcp-extension

# Run the build script
./scripts/Build-FabricMcpExtension.ps1

# The .mcpb file will be created in the current directory
```

#### macOS/Linux (Bash)

```bash
# Clone this extension template
git clone <this-repo>
cd fabric-mcp-extension

# Make the build script executable
chmod +x scripts/build.sh

# Run the build script
./scripts/build.sh

# The .mcpb file will be created in the current directory
```

#### Build Options

**PowerShell:**

```powershell
# Build for specific platforms only
./scripts/Build-FabricMcpExtension.ps1 -Platforms @('win-x64')

# Specify output directory
./scripts/Build-FabricMcpExtension.ps1 -OutputPath "C:\MyExtensions"

# Use existing repository clone
./scripts/Build-FabricMcpExtension.ps1 -SkipClone -RepoPath "C:\Dev\mcp"
```

**Bash:**

```bash
# Build for specific platforms only
./scripts/build.sh -p osx-arm64

# Specify output directory
./scripts/build.sh -o ~/MyExtensions

# Use existing repository clone
./scripts/build.sh --skip-clone --repo ~/Dev/mcp
```

## Available Tools

Once installed, the Fabric MCP Server exposes the following tools to Claude:

| Tool                            | Description                                                                                                |
| ------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `platform_get_platform_apis`    | Get detailed information about Microsoft Fabric platform APIs including endpoints, operations, and schemas |
| `platform_get_item_definitions` | Get JSON schemas for Fabric item types                                                                     |
| `platform_get_best_practices`   | Get embedded guidance on pagination, error handling, and recommended patterns                              |

## Usage Examples

After installation, you can ask Claude questions like:

```
"What APIs are available for managing Lakehouses in Microsoft Fabric?"

"Show me the JSON schema for creating a Fabric pipeline."

"What are the best practices for handling pagination in Fabric API calls?"

"Generate code to create a new Lakehouse using the Fabric REST API."

"What's the recommended error handling pattern for Fabric API authentication?"
```

## Architecture

```
fabric-mcp-extension/
├── manifest.json           # MCPB manifest with metadata and configuration
├── icon.png               # Extension icon (optional)
├── README.md              # This documentation
├── server/                # Platform-specific executables
│   ├── Fabric.Mcp.Server.exe          # Windows x64
│   ├── Fabric.Mcp.Server-darwin-x64   # macOS Intel
│   └── Fabric.Mcp.Server-darwin-arm64 # macOS Apple Silicon
└── scripts/
    ├── Build-FabricMcpExtension.ps1   # PowerShell build script
    └── build.sh                        # Bash build script
```

## Security

This MCP server is **local-first** and **privacy-focused**:

-  **No network connections** to Microsoft Fabric or any external services
-  **No authentication required** - uses bundled API specifications
-  **No data collection** - runs entirely offline
-  **Read-only operations** - cannot modify your Fabric environment

The server provides AI agents with API documentation and schemas to help generate correct code, but never accesses actual Fabric resources.

## Troubleshooting

### Extension won't install

1. Ensure you're running Claude Desktop version 0.10.0 or later
2. Check that the `.mcpb` file isn't corrupted (try re-downloading)
3. Verify you have sufficient disk space

### Tools not appearing

1. Restart Claude Desktop after installation
2. Check **Settings** → **Extensions** to verify the extension is enabled
3. View extension logs for error messages

### Build failures

1. Ensure .NET SDK 8.0+ is installed: `dotnet --version`
2. Check Git is available: `git --version`
3. Verify network connectivity for repository clone

### Debug logging

Enable debug logging in Claude Desktop:

1. Go to **Settings** → **Developer**
2. Enable **Debug Logging**
3. Check logs in the Extensions panel

## Resources

- [Microsoft Fabric Documentation](https://learn.microsoft.com/fabric/)
- [Microsoft MCP Repository](https://github.com/microsoft/mcp)
- [Fabric MCP Server README](https://github.com/microsoft/mcp/blob/main/servers/Fabric.Mcp.Server/README.md)
- [MCP Protocol Specification](https://modelcontextprotocol.io/)
- [MCPB Bundle Specification](https://github.com/modelcontextprotocol/mcpb)

## Contributing

Contributions are welcome! Please see the [Microsoft MCP Contributing Guide](https://github.com/microsoft/mcp/blob/main/CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Disclaimer

This extension is in **Public Preview**. Microsoft Fabric MCP Server gives your AI agents the knowledge they need to generate code for Microsoft Fabric, but:

- Does not connect to your actual Fabric environment
- Generated code should be reviewed before deployment
- API specifications may be updated; rebuild for the latest version

---
