param(
    [string]$ComposeFile = ".\infra\fastgpt\docker-compose.local.yml",
    [string]$EnvFile = ".\infra\fastgpt\.env.local"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ComposeFile)) {
    throw "Compose file not found: $ComposeFile"
}

if (Test-Path -LiteralPath $EnvFile) {
    docker compose --env-file $EnvFile -f $ComposeFile down
} else {
    docker compose -f $ComposeFile down
}
