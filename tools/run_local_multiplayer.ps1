[CmdletBinding()]
param(
    [ValidateRange(1, 65535)]
    [int]$Port = 7777,

    [ValidateRange(1, 10)]
    [int]$ServerStartupDelaySeconds = 2
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

function Quote-ProcessArgument([string]$Value) {
    return '"' + $Value.Replace('"', '\"') + '"'
}

$godot = Resolve-GodotBinary
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$serverProject = Join-Path $repositoryRoot "server"
$clientProject = Join-Path $repositoryRoot "client"
$server = $null
$clients = @()

try {
    $serverArguments = "--headless --path $(Quote-ProcessArgument $serverProject) -- --network-port=$Port"
    Write-Host "Starting headless server on 127.0.0.1:$Port"
    $server = Start-Process -FilePath $godot -ArgumentList $serverArguments -WindowStyle Hidden -PassThru

    Start-Sleep -Seconds $ServerStartupDelaySeconds
    if ($server.HasExited) {
        throw "The server exited before clients could start (exit code $($server.ExitCode))."
    }

    $clientArguments = "--path $(Quote-ProcessArgument $clientProject) -- --network-host=127.0.0.1 --network-port=$Port"
    Write-Host "Starting two independent clients. Close both client windows to stop the local server."
    $clients += Start-Process -FilePath $godot -ArgumentList $clientArguments -PassThru
    $clients += Start-Process -FilePath $godot -ArgumentList $clientArguments -PassThru
    $clients | Wait-Process
}
finally {
    foreach ($client in $clients) {
        if ($null -ne $client -and -not $client.HasExited) {
            Stop-Process -Id $client.Id
        }
    }
    if ($null -ne $server -and -not $server.HasExited) {
        Write-Host "Stopping local server."
        Stop-Process -Id $server.Id
        $server.WaitForExit()
    }
}
