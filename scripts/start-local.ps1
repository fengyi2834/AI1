param(
    [string]$ComposeFile = ".\infra\fastgpt\docker-compose.local.yml",
    [string]$EnvFile = ".\infra\fastgpt\.env.local"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ComposeFile)) {
    throw "Compose file not found: $ComposeFile"
}

if (-not (Test-Path -LiteralPath $EnvFile)) {
    $example = ".\infra\fastgpt\.env.example"
    if (-not (Test-Path -LiteralPath $example)) {
        throw "Env file not found, and example is missing: $example"
    }
    Copy-Item -LiteralPath $example -Destination $EnvFile
    Write-Output "Created $EnvFile from template. Please fill OPENAI_BASE_URL and CHAT_API_KEY before rerunning."
    exit 1
}

$requiredDirs = @(
    ".\infra\fastgpt\runtime\pg",
    ".\infra\fastgpt\runtime\mongo",
    ".\infra\fastgpt\runtime\redis",
    ".\infra\fastgpt\runtime\minio",
    ".\infra\fastgpt\runtime\aiproxy_pg",
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

docker compose --env-file $EnvFile -f $ComposeFile up -d
