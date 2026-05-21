param(
    [int]$Port = 4180,
    [string]$EnvFile = ".\deploy\env\guanwang.server.env"
)

$ErrorActionPreference = "Stop"

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$startScript = Join-Path $root "scripts\start-guanwang.ps1"
$resolvedEnvFile = if ([System.IO.Path]::IsPathRooted($EnvFile)) {
    $EnvFile
} else {
    Join-Path $root $EnvFile
}

if (-not (Test-Path -LiteralPath $resolvedEnvFile)) {
    $example = Join-Path $root "deploy\env\guanwang.server.env.example"
    if (-not (Test-Path -LiteralPath $example)) {
        throw "Env file not found: $resolvedEnvFile, and example is missing: $example"
    }
    Copy-Item -LiteralPath $example -Destination $resolvedEnvFile
    Write-Output "Created $resolvedEnvFile from template. Please fill FASTGPT_APP_API_KEY and CHAT_API_KEY before rerunning."
    exit 1
}

& $startScript -Port $Port -EnvFile $resolvedEnvFile
