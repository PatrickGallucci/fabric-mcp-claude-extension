#!/usr/bin/env bash
#
# Build-FabricMcpExtension.sh
# Builds the Microsoft Fabric MCP Server Desktop Extension Package (.mcpb)
#
# Prerequisites:
#   - .NET SDK 8.0 or later
#   - Git
#   - zip utility
#
# Usage:
#   ./Build-FabricMcpExtension.sh [OPTIONS]
#
# Options:
#   -o, --output <path>     Output directory (default: current directory)
#   -p, --platforms <list>  Comma-separated platforms (default: all)
#                           Valid: win-x64,osx-x64,osx-arm64
#   -s, --skip-clone        Skip repository clone
#   -r, --repo <path>       Path to existing repository (use with --skip-clone)
#   -h, --help              Show this help message

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GRAY='\033[0;90m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Default values
OUTPUT_PATH="$(pwd)"
PLATFORMS="win-x64,osx-x64,osx-arm64"
SKIP_CLONE=false
REPO_PATH=""

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Helper functions
step() { echo -e "\n${CYAN}==> $1${NC}"; }
success() { echo -e "${GREEN}[✓] $1${NC}"; }
info() { echo -e "${GRAY}    $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; exit 1; }
warning() { echo -e "${YELLOW}[WARN] $1${NC}"; }

show_help() {
    cat << EOF
Microsoft Fabric MCP Server - Desktop Extension Builder

Usage: $(basename "$0") [OPTIONS]

Options:
    -o, --output <path>     Output directory (default: current directory)
    -p, --platforms <list>  Comma-separated platforms (default: all)
                            Valid: win-x64,osx-x64,osx-arm64
    -s, --skip-clone        Skip repository clone
    -r, --repo <path>       Path to existing repository (use with --skip-clone)
    -h, --help              Show this help message

Examples:
    $(basename "$0")
    $(basename "$0") -o ~/Extensions -p osx-arm64
    $(basename "$0") --skip-clone --repo ~/mcp

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            OUTPUT_PATH="$2"
            shift 2
            ;;
        -p|--platforms)
            PLATFORMS="$2"
            shift 2
            ;;
        -s|--skip-clone)
            SKIP_CLONE=true
            shift
            ;;
        -r|--repo)
            REPO_PATH="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

check_prerequisites() {
    step "Checking prerequisites..."
    
    # Check .NET SDK
    if ! command -v dotnet &> /dev/null; then
        error ".NET SDK is not installed. Please install .NET SDK 8.0 or later from https://dotnet.microsoft.com/download"
    fi
    
    local dotnet_version
    dotnet_version=$(dotnet --version)
    local major_version
    major_version=$(echo "$dotnet_version" | cut -d'.' -f1)
    
    if [[ $major_version -lt 8 ]]; then
        error ".NET SDK 8.0 or later is required. Current version: $dotnet_version"
    fi
    success ".NET SDK $dotnet_version found"
    
    # Check Git if not skipping clone
    if [[ "$SKIP_CLONE" == false ]]; then
        if ! command -v git &> /dev/null; then
            error "Git is not installed. Please install Git or use --skip-clone with an existing repository."
        fi
        success "Git found: $(git --version)"
    fi
    
    # Check zip
    if ! command -v zip &> /dev/null; then
        error "zip utility is not installed. Please install it (brew install zip on macOS, apt install zip on Ubuntu)."
    fi
    success "zip utility found"
}

get_source_code() {
    local work_dir="$1"
    
    if [[ "$SKIP_CLONE" == true ]]; then
        if [[ -z "$REPO_PATH" ]]; then
            error "When using --skip-clone, you must specify --repo"
        fi
        if [[ ! -d "$REPO_PATH" ]]; then
            error "Repository path does not exist: $REPO_PATH"
        fi
        success "Using existing repository at $REPO_PATH"
        echo "$REPO_PATH"
        return
    fi
    
    step "Cloning Microsoft MCP repository..."
    local clone_path="$work_dir/mcp"
    
    if [[ -d "$clone_path" ]]; then
        info "Removing existing clone..."
        rm -rf "$clone_path"
    fi
    
    git clone --depth 1 'https://github.com/microsoft/mcp.git' "$clone_path"
    success "Repository cloned successfully"
    echo "$clone_path"
}

build_for_platform() {
    local project_path="$1"
    local platform="$2"
    local output_dir="$3"
    
    step "Building for $platform..."
    
    local publish_dir="$output_dir/$platform"
    
    info "Running: dotnet publish -c Release -r $platform --self-contained"
    dotnet publish "$project_path" \
        -c Release \
        -r "$platform" \
        --self-contained true \
        -p:PublishSingleFile=true \
        -p:PublishTrimmed=true \
        -p:IncludeNativeLibrariesForSelfExtract=true \
        -o "$publish_dir"
    
    success "Build completed for $platform"
}

create_extension_package() {
    local build_output_dir="$1"
    local extension_dir="$2"
    local output_path="$3"
    local platforms="$4"
    
    step "Creating extension package..."
    
    local server_dir="$extension_dir/server"
    mkdir -p "$server_dir"
    
    IFS=',' read -ra PLATFORM_ARRAY <<< "$platforms"
    
    for platform in "${PLATFORM_ARRAY[@]}"; do
        local platform_dir="$build_output_dir/$platform"
        
        if [[ ! -d "$platform_dir" ]]; then
            warning "Build output not found for $platform, skipping..."
            continue
        fi
        
        # Determine executable name
        local exe_name
        local dest_name
        case "$platform" in
            win-x64)
                exe_name="Fabric.Mcp.Server.exe"
                dest_name="Fabric.Mcp.Server.exe"
                ;;
            osx-x64)
                exe_name="Fabric.Mcp.Server"
                dest_name="Fabric.Mcp.Server-darwin-x64"
                ;;
            osx-arm64)
                exe_name="Fabric.Mcp.Server"
                dest_name="Fabric.Mcp.Server-darwin-arm64"
                ;;
        esac
        
        local source_exe="$platform_dir/$exe_name"
        if [[ ! -f "$source_exe" ]]; then
            warning "Executable not found at $source_exe, skipping..."
            continue
        fi
        
        local dest_path="$server_dir/$dest_name"
        cp "$source_exe" "$dest_path"
        info "Copied $platform executable to $dest_name"
        
        # Make Unix executables executable
        if [[ "$platform" != "win-x64" ]]; then
            chmod +x "$dest_path"
        fi
    done
    
    # Read version from manifest
    local version
    version=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$extension_dir/manifest.json" | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
    
    # Create the .mcpb archive
    local mcpb_filename="fabric-mcp-server-${version}.mcpb"
    local mcpb_path="$output_path/$mcpb_filename"
    
    # Remove existing archive if present
    rm -f "$mcpb_path"
    
    info "Creating archive: $mcpb_path"
    
    # Create ZIP archive
    pushd "$extension_dir" > /dev/null
    zip -r "$mcpb_path" . -x "*.DS_Store" -x "__MACOSX/*"
    popd > /dev/null
    
    success "Created package: $mcpb_path"
    
    # Display package contents
    step "Package contents:"
    unzip -l "$mcpb_path" | tail -n +4 | head -n -2 | while read -r size date time name; do
        local size_kb
        size_kb=$(echo "scale=2; $size / 1024" | bc)
        info "$name ($size_kb KB)"
    done
    
    echo "$mcpb_path"
}

# Main script
main() {
    echo -e "\n${MAGENTA}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║   Microsoft Fabric MCP Server - Desktop Extension Builder   ║${NC}"
    echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════╝${NC}"
    
    # Validate prerequisites
    check_prerequisites
    
    # Create work directory
    local work_dir
    work_dir=$(mktemp -d -t fabric-mcp-build-XXXXXXXX)
    info "Working directory: $work_dir"
    
    # Cleanup on exit
    trap 'rm -rf "$work_dir"' EXIT
    
    # Create extension staging directory
    local extension_dir="$work_dir/extension"
    mkdir -p "$extension_dir"
    
    # Copy base extension files
    cp "$BASE_DIR/manifest.json" "$extension_dir/"
    
    if [[ -f "$BASE_DIR/icon.png" ]]; then
        cp "$BASE_DIR/icon.png" "$extension_dir/"
    fi
    
    if [[ -f "$BASE_DIR/README.md" ]]; then
        cp "$BASE_DIR/README.md" "$extension_dir/"
    fi
    
    # Get source code
    local repo_path
    repo_path=$(get_source_code "$work_dir")
    
    # Build for each platform
    local project_path="$repo_path/servers/Fabric.Mcp.Server/src/Fabric.Mcp.Server.csproj"
    
    if [[ ! -f "$project_path" ]]; then
        error "Project file not found at: $project_path"
    fi
    
    local build_output_dir="$work_dir/publish"
    
    IFS=',' read -ra PLATFORM_ARRAY <<< "$PLATFORMS"
    for platform in "${PLATFORM_ARRAY[@]}"; do
        build_for_platform "$project_path" "$platform" "$build_output_dir"
    done
    
    # Create the extension package
    local mcpb_path
    mcpb_path=$(create_extension_package \
        "$build_output_dir" \
        "$extension_dir" \
        "$OUTPUT_PATH" \
        "$PLATFORMS")
    
    echo -e "\n${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  BUILD SUCCESSFUL!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "\n  Extension package created at:"
    echo -e "${YELLOW}  $mcpb_path${NC}"
    echo -e "\n  To install:"
    echo -e "${GRAY}  1. Open Claude Desktop${NC}"
    echo -e "${GRAY}  2. Go to Settings > Extensions${NC}"
    echo -e "${GRAY}  3. Click 'Install Extension...' and select the .mcpb file${NC}"
    echo ""
}

main
