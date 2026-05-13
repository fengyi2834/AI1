param(
    [int]$Port = 4180
)

$ErrorActionPreference = "Stop"

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$serverScript = Join-Path $root "scripts\demo-server.ps1"
$webRoot = Join-Path $root "guanwang"
$envFile = Join-Path $root "infra\fastgpt\.env.local"

if (-not (Test-Path -LiteralPath $serverScript)) {
    throw "Demo server script not found: $serverScript"
}

if (-not (Test-Path -LiteralPath $webRoot)) {
    throw "Guanwang web root not found: $webRoot"
}

if (-not (Test-Path -LiteralPath $envFile)) {
    throw "Environment file not found: $envFile"
}

Write-Output "Starting guanwang with live AI at http://127.0.0.1:$Port/"
& $serverScript -Port $Port -WebRoot $webRoot -EnvFile $envFile
