[CmdletBinding()]
param(
    [ValidateRange(1, 65535)]
    [int]$Port = 7777
)

$ErrorActionPreference = "Stop"

function Resolve-GodotBinary {
    if (-not [string]::IsNullOrWhiteSpace($env:GODOT_BIN)) {
        if (-not (Test-Path -LiteralPath $env:GODOT_BIN -PathType Leaf)) {
            throw "GODOT_BIN does not point to a file: $env:GODOT_BIN"
        }
        return (Resolve-Path -LiteralPath $env:GODOT_BIN).Path
    }

    $command = Get-Command godot -CommandType Application -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        throw "Godot was not found. Set GODOT_BIN or add godot to PATH."
    }
    return $command.Source
}

$godot = Resolve-GodotBinary
$serverProject = Join-Path (Split-Path -Parent $PSScriptRoot) "server"

Write-Host "Starting Aetherfall zone server on 127.0.0.1:$Port"
& $godot --headless --path $serverProject -- "--network-port=$Port"
exit $LASTEXITCODE
