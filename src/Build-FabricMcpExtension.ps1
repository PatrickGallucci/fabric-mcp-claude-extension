<#
.SYNOPSIS
    Builds the Microsoft Fabric MCP Server Desktop Extension Package (.mcpb)

.DESCRIPTION
    This script clones the Microsoft MCP repository, builds the Fabric.Mcp.Server
    project as self-contained executables for Windows and macOS, and packages
    everything into a .mcpb file ready for Claude Desktop installation.

.PARAMETER OutputPath
    The directory where the final .mcpb file will be created.
    Defaults to the current directory.

.PARAMETER SkipClone
    If specified, skips cloning the repository and uses an existing local copy.

.PARAMETER RepoPath
    Path to existing repository clone (use with -SkipClone).

.PARAMETER Platforms
    Array of target platforms to build. 
    Valid values: 'win-x64', 'osx-x64', 'osx-arm64'
    Defaults to all platforms.

.PARAMETER TargetFramework
    Override the target framework (e.g., 'net9.0' if you don't have .NET 10 SDK).
    If not specified, attempts to use the project's default or auto-detects based on installed SDK.

.PARAMETER Force
    Force build even if SDK version mismatch is detected.

.EXAMPLE
    .\Build-FabricMcpExtension.ps1
    
.EXAMPLE
    .\Build-FabricMcpExtension.ps1 -TargetFramework net9.0

.EXAMPLE
    .\Build-FabricMcpExtension.ps1 -OutputPath "C:\Extensions" -Platforms @('win-x64')

.NOTES
    Prerequisites:
    - .NET SDK 8.0 or later (9.0+ recommended)
    - Git (if not using -SkipClone)
    - PowerShell 7+
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$OutputPath = (Get-Location).Path,
    
    [Parameter()]
    [switch]$SkipClone,
    
    [Parameter()]
    [string]$RepoPath,
    
    [Parameter()]
    [ValidateSet('win-x64', 'osx-x64', 'osx-arm64')]
    [string[]]$Platforms = @('win-x64'),
    
    [Parameter()]
    [ValidatePattern('^net\d+\.\d+$')]
    [string]$TargetFramework,
    
    [Parameter()]
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Helper Functions

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "    $Message" -ForegroundColor Gray
}

function Get-InstalledSdkVersion {
    $sdkOutput = & dotnet --list-sdks 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $null
    }
    
    # Parse SDK versions and get the highest one
    $versions = $sdkOutput | ForEach-Object {
        if ($_ -match '^(\d+\.\d+)\.\d+') {
            [version]$Matches[1]
        }
    } | Sort-Object -Descending
    
    if ($versions.Count -gt 0) {
        return $versions[0]
    }
    return $null
}

function Get-ProjectTargetFramework {
    param([string]$ProjectPath)
    
    if (-not (Test-Path $ProjectPath)) {
        return $null
    }
    
    $content = Get-Content $ProjectPath -Raw
    if ($content -match '<TargetFramework>([^<]+)</TargetFramework>') {
        return $Matches[1]
    }
    return $null
}

function Update-ProjectTargetFrameworks {
    param(
        [string]$RepoPath,
        [string]$OldFramework,
        [string]$NewFramework
    )
    
    Write-Step "Patching project files to use $NewFramework instead of $OldFramework..."
    
    # Find all csproj files in the Fabric.Mcp.Server folder and its dependencies
    $fabricServerPath = Join-Path $RepoPath 'servers/Fabric.Mcp.Server'
    $csprojFiles = Get-ChildItem -Path $fabricServerPath -Filter '*.csproj' -Recurse -ErrorAction SilentlyContinue
    
    # Also check for shared projects in parent directories
    $serversPath = Join-Path $RepoPath 'servers'
    $sharedCsprojFiles = Get-ChildItem -Path $serversPath -Filter '*.csproj' -Recurse -ErrorAction SilentlyContinue
    
    $allCsprojFiles = @($csprojFiles) + @($sharedCsprojFiles) | Select-Object -Unique
    
    $patchedCount = 0
    foreach ($csproj in $allCsprojFiles) {
        $content = Get-Content $csproj.FullName -Raw
        
        if ($content -match "<TargetFramework>$OldFramework</TargetFramework>") {
            $newContent = $content -replace "<TargetFramework>$OldFramework</TargetFramework>", "<TargetFramework>$NewFramework</TargetFramework>"
            Set-Content -Path $csproj.FullName -Value $newContent -Encoding UTF8 -NoNewline
            Write-Info "Patched: $($csproj.Name)"
            $patchedCount++
        }
    }
    
    if ($patchedCount -eq 0) {
        Write-Warning "No project files found with $OldFramework"
    }
    else {
        Write-Success "Patched $patchedCount project file(s)"
    }
    
    return $patchedCount
}

function Test-Prerequisites {
    Write-Step "Checking prerequisites..."
    
    # Check .NET SDK
    $dotnetVersion = $null
    try {
        $dotnetVersion = & dotnet --version 2>$null
    }
    catch {
        throw ".NET SDK is not installed. Please install .NET SDK 8.0 or later from https://dotnet.microsoft.com/download"
    }
    
    $majorVersion = [int]($dotnetVersion -split '\.')[0]
    if ($majorVersion -lt 8) {
        throw ".NET SDK 8.0 or later is required. Current version: $dotnetVersion"
    }
    Write-Success ".NET SDK $dotnetVersion found"
    
    # Get highest installed SDK version
    $installedVersion = Get-InstalledSdkVersion
    if ($installedVersion) {
        Write-Info "Highest SDK version available: $installedVersion"
    }
    
    # Check Git if not skipping clone
    if (-not $SkipClone) {
        try {
            $gitVersion = & git --version 2>$null
            Write-Success "Git found: $gitVersion"
        }
        catch {
            throw "Git is not installed. Please install Git or use -SkipClone with an existing repository."
        }
    }
    
    return $installedVersion
}

function Get-SourceCode {
    param([string]$WorkDir)
    
    if ($SkipClone) {
        if ([string]::IsNullOrEmpty($RepoPath)) {
            throw "When using -SkipClone you must specify -RepoPath parameter"
        }
        if (-not (Test-Path $RepoPath)) {
            throw "Repository path does not exist: $RepoPath"
        }
        Write-Success "Using existing repository at $RepoPath"
        return $RepoPath
    }
    
    Write-Step "Cloning Microsoft MCP repository..."
    $clonePath = Join-Path $WorkDir 'mcp'
    
    if (Test-Path $clonePath) {
        Write-Info "Removing existing clone..."
        Remove-Item -Path $clonePath -Recurse -Force
    }
    
    & git clone --depth 1 'https://github.com/microsoft/mcp.git' $clonePath
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to clone repository"
    }
    
    Write-Success "Repository cloned successfully"
    return $clonePath
}

function Build-ServerForPlatform {
    param(
        [string]$ProjectPath,
        [string]$Platform,
        [string]$OutputDir
    )
    
    Write-Step "Building for $Platform..."
    
    $publishDir = Join-Path $OutputDir $Platform
    
    $publishArgs = @(
        'publish'
        $ProjectPath
        '-c', 'Release'
        '-r', $Platform
        '--self-contained', 'true'
        '-p:PublishSingleFile=true'
        '-p:PublishTrimmed=true'
        '-p:IncludeNativeLibrariesForSelfExtract=true'
        '-o', $publishDir
    )
    
    Write-Info "Running: dotnet $($publishArgs -join ' ')"
    & dotnet @publishArgs
    
    if ($LASTEXITCODE -ne 0) {
        throw "Build failed for $Platform"
    }
    
    Write-Success "Build completed for $Platform"
    return $publishDir
}

function New-ExtensionPackage {
    param(
        [string]$BuildOutputDir,
        [string]$ExtensionDir,
        [string]$OutputPath,
        [string[]]$Platforms
    )
    
    Write-Step "Creating extension package..."
    
    $serverDir = Join-Path $ExtensionDir 'server'
    if (-not (Test-Path $serverDir)) {
        New-Item -ItemType Directory -Path $serverDir -Force | Out-Null
    }
    
    foreach ($platform in $Platforms) {
        $platformDir = Join-Path $BuildOutputDir $platform
        
        if (-not (Test-Path $platformDir)) {
            Write-Warning "Build output not found for $platform, skipping..."
            continue
        }
        
        # Determine executable name based on platform
        $exeName = if ($platform -like 'win-*') { 'Fabric.Mcp.Server.exe' } else { 'Fabric.Mcp.Server' }
        $sourceExe = Join-Path $platformDir $exeName
        
        if (-not (Test-Path $sourceExe)) {
            Write-Warning "Executable not found at $sourceExe, skipping..."
            continue
        }
        
        # Copy executable (keep same name)
        $destPath = Join-Path $serverDir $exeName
        Copy-Item -Path $sourceExe -Destination $destPath -Force
        Write-Info "Copied $platform executable to $exeName"
    }
    
    # Update manifest with correct entry point and platform
    $manifestPath = Join-Path $ExtensionDir 'manifest.json'
    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
    
    # Determine the primary platform from what was built
    $primaryPlatform = $Platforms | Select-Object -First 1
    $isWindows = $primaryPlatform -like 'win-*'
    
    # Set the correct entry point and command based on platform
    if ($isWindows) {
        $manifest.server.entry_point = 'server/Fabric.Mcp.Server.exe'
        $manifest.server.mcp_config = @{
            'command' = '${__dirname}/server/Fabric.Mcp.Server.exe'
            'args' = @()
        }
        $manifest.compatibility.platforms = @('win32')
    }
    else {
        $manifest.server.entry_point = 'server/Fabric.Mcp.Server'
        $manifest.server.mcp_config = @{
            'command' = '${__dirname}/server/Fabric.Mcp.Server'
            'args' = @()
        }
        $manifest.compatibility.platforms = @('darwin')
    }
    
    $manifest | ConvertTo-Json -Depth 10 | Set-Content $manifestPath -Encoding UTF8
    Write-Success "Updated manifest.json for $primaryPlatform"
    
    # Create the .mcpb archive with platform in filename
    $platformSuffix = if ($isWindows) { 'win32' } else { 'darwin' }
    $mcpbFileName = "fabric-mcp-server-$($manifest.version)-$platformSuffix.mcpb"
    $mcpbPath = Join-Path $OutputPath $mcpbFileName
    
    # Remove existing archive if present
    if (Test-Path $mcpbPath) {
        Remove-Item $mcpbPath -Force
    }
    
    Write-Info "Creating archive: $mcpbPath"
    
    # Create ZIP archive
    $compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
    [System.IO.Compression.ZipFile]::CreateFromDirectory(
        $ExtensionDir, 
        $mcpbPath, 
        $compressionLevel, 
        $false  # Don't include base directory name
    )
    
    Write-Success "Created package: $mcpbPath"
    
    # Display package contents
    Write-Step "Package contents:"
    $zip = [System.IO.Compression.ZipFile]::OpenRead($mcpbPath)
    try {
        foreach ($entry in $zip.Entries) {
            $sizeKB = [math]::Round($entry.Length / 1024, 2)
            $displayText = "{0} ({1} KB)" -f $entry.FullName, $sizeKB
            Write-Info $displayText
        }
    }
    finally {
        $zip.Dispose()
    }
    
    return $mcpbPath
}

#endregion

#region Main Script

try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Magenta
    Write-Host "  Microsoft Fabric MCP Server - Desktop Extension Builder" -ForegroundColor Magenta
    Write-Host "================================================================" -ForegroundColor Magenta
    
    # Validate prerequisites and get installed SDK version
    $installedSdkVersion = Test-Prerequisites
    
    # Create work directory
    $workDir = Join-Path ([System.IO.Path]::GetTempPath()) "fabric-mcp-build-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $workDir -Force | Out-Null
    Write-Info "Working directory: $workDir"
    
    # Create extension staging directory
    $extensionDir = Join-Path $workDir 'extension'
    New-Item -ItemType Directory -Path $extensionDir -Force | Out-Null
    
    # Copy base extension files
    $scriptDir = $PSScriptRoot
    $baseExtDir = Split-Path $scriptDir -Parent
    
    # Copy manifest and icon
    Copy-Item (Join-Path $baseExtDir 'manifest.json') $extensionDir -Force
    $iconPath = Join-Path $baseExtDir 'icon.png'
    if (Test-Path $iconPath) {
        Copy-Item $iconPath $extensionDir -Force
    }
    
    # Copy README
    $readmePath = Join-Path $baseExtDir 'README.md'
    if (Test-Path $readmePath) {
        Copy-Item $readmePath $extensionDir -Force
    }
    
    # Get source code
    $repoPath = Get-SourceCode -WorkDir $workDir
    
    # Build for each platform
    $projectPath = Join-Path $repoPath 'servers/Fabric.Mcp.Server/src/Fabric.Mcp.Server.csproj'
    
    if (-not (Test-Path $projectPath)) {
        throw "Project file not found at: $projectPath"
    }
    
    # Check project target framework and determine if override is needed
    $projectTargetFramework = Get-ProjectTargetFramework -ProjectPath $projectPath
    $effectiveTargetFramework = $TargetFramework
    
    if ($projectTargetFramework) {
        Write-Info "Project targets: $projectTargetFramework"
        
        # Extract version number from target framework (e.g., net10.0 -> 10.0)
        if ($projectTargetFramework -match 'net(\d+\.\d+)') {
            $projectVersion = [version]$Matches[1]
            
            # If project targets a higher version than installed and no override specified
            if ($installedSdkVersion -and $projectVersion -gt $installedSdkVersion -and [string]::IsNullOrEmpty($TargetFramework)) {
                $suggestedFramework = "net$($installedSdkVersion.Major).0"
                Write-Host ""
                Write-Warning "Project targets .NET $projectVersion but you have SDK $installedSdkVersion installed."
                Write-Warning "The build will patch project files to use $suggestedFramework."
                Write-Host ""
                
                if (-not $Force) {
                    $response = Read-Host "Continue with $suggestedFramework? [Y/n]"
                    if ($response -eq 'n' -or $response -eq 'N') {
                        Write-Host "Build cancelled. Install .NET $projectVersion SDK or specify -TargetFramework."
                        exit 0
                    }
                }
                
                $effectiveTargetFramework = $suggestedFramework
            }
        }
    }
    
    # If we need to override the target framework, patch project files directly
    if (-not [string]::IsNullOrEmpty($effectiveTargetFramework) -and $effectiveTargetFramework -ne $projectTargetFramework) {
        Update-ProjectTargetFrameworks -RepoPath $repoPath -OldFramework $projectTargetFramework -NewFramework $effectiveTargetFramework
    }
    
    $buildOutputDir = Join-Path $workDir 'publish'
    
    foreach ($platform in $Platforms) {
        Build-ServerForPlatform -ProjectPath $projectPath -Platform $platform -OutputDir $buildOutputDir
    }
    
    # Create the extension package
    $mcpbPath = New-ExtensionPackage `
        -BuildOutputDir $buildOutputDir `
        -ExtensionDir $extensionDir `
        -OutputPath $OutputPath `
        -Platforms $Platforms
    
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host "  BUILD SUCCESSFUL!" -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Extension package created at:" -ForegroundColor White
    Write-Host "  $mcpbPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  To install:" -ForegroundColor White
    Write-Host "  1. Open Claude Desktop" -ForegroundColor Gray
    Write-Host "  2. Go to Settings > Extensions" -ForegroundColor Gray
    Write-Host "  3. Click 'Install Extension...' and select the .mcpb file" -ForegroundColor Gray
    Write-Host ""
    
    return $mcpbPath
}
catch {
    Write-Host ""
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
    exit 1
}
finally {
    # Cleanup work directory (optional - commented out for debugging)
    # if ($workDir -and (Test-Path $workDir)) {
    #     Remove-Item $workDir -Recurse -Force
    # }
}

#endregion