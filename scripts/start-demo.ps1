param(
    [int]$Port = 8099
)

$ErrorActionPreference = "Stop"

$root = (Resolve-Path -LiteralPath ".").Path
$serverScript = Join-Path $root "scripts\demo-server.ps1"

if (-not (Test-Path -LiteralPath $serverScript)) {
    throw "Demo server script not found: $serverScript"
}

Write-Output "Starting demo server in foreground at http://127.0.0.1:$Port/"
& $serverScript -Port $Port
