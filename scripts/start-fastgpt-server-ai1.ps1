param(
    [string]$ComposeFile = ".\infra\fastgpt\docker-compose.local.yml",
    [string]$OverrideComposeFile = ".\infra\fastgpt\docker-compose.server.ai1.override.yml",
    [string]$EnvFile = ".\deploy\env\fastgpt.server.ai1.env"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ComposeFile)) {
    throw "Compose file not found: $ComposeFile"
}

if (-not (Test-Path -LiteralPath $OverrideComposeFile)) {
    throw "Override compose file not found: $OverrideComposeFile"
}

if (-not (Test-Path -LiteralPath $EnvFile)) {
    $example = ".\deploy\env\fastgpt.server.ai1.env.example"
    if (-not (Test-Path -LiteralPath $example)) {
        throw "Env file not found: $EnvFile, and example is missing: $example"
    }
    Copy-Item -LiteralPath $example -Destination $EnvFile
    Write-Output "Created $EnvFile from template. Please fill CHAT_API_KEY before rerunning."
    exit 1
}

$requiredDirs = @(
    ".\infra\fastgpt\runtime_server\pg",
    ".\infra\fastgpt\runtime_server\mongo",
    ".\infra\fastgpt\runtime_server\redis",
    ".\infra\fastgpt\runtime_server\minio",
    ".\infra\fastgpt\runtime_server\aiproxy_pg",
    ".\data\raw_docs",
    ".\data\clean_text",
    ".\data\faq",
    ".\data\import_ready",
    ".\data\uploads",
    ".\data\logs"
)

foreach ($dir in $requiredDirs) {
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

docker compose --env-file $EnvFile -f $ComposeFile -f $OverrideComposeFile up -d
