param(
    [string]$BundlePath,
    [string]$EnvFile = ".\infra\fastgpt\.env.local",
    [string]$MongoContainer = "fastgpt-mongo",
    [string]$MongoUser = "myusername",
    [string]$MongoPassword = "mypassword",
    [switch]$RebuildVenv,
    [switch]$StartDemo
)

$ErrorActionPreference = "Stop"

function Resolve-AbsolutePath {
    param([string]$PathValue)

    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return $PathValue
    }

    return Join-Path (Resolve-Path -LiteralPath ".").Path $PathValue
}

function Wait-HttpReady {
    param(
        [string]$Url,
        [int]$TimeoutSec = 120
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        try {
            $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5
            if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500) {
                return
            }
        } catch {
        }
        Start-Sleep -Seconds 2
    }

    throw "Timed out waiting for: $Url"
}

function Ensure-DockerService {
    $service = Get-Service -Name "com.docker.service" -ErrorAction SilentlyContinue
    if ($service -and $service.Status -ne "Running") {
        Start-Service -Name "com.docker.service"
        Start-Sleep -Seconds 5
    }
}

function Get-BundleRoot {
    param([string]$ResolvedBundlePath)

    if (Test-Path -LiteralPath $ResolvedBundlePath -PathType Container) {
        return $ResolvedBundlePath
    }

    if (-not (Test-Path -LiteralPath $ResolvedBundlePath -PathType Leaf)) {
        throw "Bundle path not found: $ResolvedBundlePath"
    }

    $extractRoot = Join-Path (Resolve-Path -LiteralPath ".").Path ("tmp\restore_bundle_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
    if (Test-Path -LiteralPath $extractRoot) {
        Remove-Item -LiteralPath $extractRoot -Recurse -Force
    }
    New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null
    Expand-Archive -LiteralPath $ResolvedBundlePath -DestinationPath $extractRoot -Force

    $children = @(Get-ChildItem -LiteralPath $extractRoot -Directory)
    if ($children.Count -eq 1) {
        return $children[0].FullName
    }

    return $extractRoot
}

$root = (Resolve-Path -LiteralPath ".").Path
if (-not $BundlePath) {
    throw "BundlePath is required. Pass either a zip file or an extracted bundle directory."
}

$resolvedBundlePath = Resolve-AbsolutePath -PathValue $BundlePath
$bundleRoot = Get-BundleRoot -ResolvedBundlePath $resolvedBundlePath
$mongoArchive = Join-Path $bundleRoot "mongo\fastgpt.archive.gz"
$bundledEnv = Join-Path $bundleRoot "env\.env.local.private"
$bundledData = Join-Path $bundleRoot "project_data"
$envFileAbs = Resolve-AbsolutePath -PathValue $EnvFile

if (-not (Test-Path -LiteralPath $envFileAbs)) {
    if (Test-Path -LiteralPath $bundledEnv) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $envFileAbs) -Force | Out-Null
        Copy-Item -LiteralPath $bundledEnv -Destination $envFileAbs -Force
        Write-Output ("Copied bundled env file to: {0}" -f $envFileAbs)
    }
}

if (-not (Test-Path -LiteralPath $envFileAbs)) {
    throw "Env file missing: $envFileAbs. Provide one manually, or include env/.env.local.private in the restore bundle."
}

if ($RebuildVenv) {
    & (Join-Path $root "scripts\rebuild-venv.ps1")
}

Ensure-DockerService

& (Join-Path $root "scripts\prepare-data-dirs.ps1")
& (Join-Path $root "scripts\start-local.ps1") -EnvFile $envFileAbs

Wait-HttpReady -Url "http://127.0.0.1:3100/"

if (Test-Path -LiteralPath $mongoArchive) {
    $containerArchive = "/tmp/fastgpt_restore_bundle.archive.gz"
    docker cp $mongoArchive "${MongoContainer}:${containerArchive}" | Out-Null
    docker exec $MongoContainer sh -lc "mongorestore --gzip --archive='$containerArchive' --drop -u '$MongoUser' -p '$MongoPassword' --authenticationDatabase admin" | Out-Null
    docker exec $MongoContainer sh -lc "rm -f '$containerArchive'" | Out-Null
    docker restart fastgpt-app | Out-Null
    Start-Sleep -Seconds 5
    Wait-HttpReady -Url "http://127.0.0.1:3100/"
}

if (Test-Path -LiteralPath $bundledData) {
    $faqSource = Join-Path $bundledData "faq"
    $importReadySource = Join-Path $bundledData "import_ready"
    if (Test-Path -LiteralPath $faqSource) {
        Copy-Item -LiteralPath $faqSource -Destination (Join-Path $root "data") -Recurse -Force
    }
    if (Test-Path -LiteralPath $importReadySource) {
        Copy-Item -LiteralPath $importReadySource -Destination (Join-Path $root "data") -Recurse -Force
    }
}

& (Join-Path $root "scripts\register-fastgpt-chat-model.ps1")
& (Join-Path $root "scripts\tune-fastgpt-rag-app.ps1")

if ($StartDemo) {
    $listener = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $_.LocalPort -eq 8099 } | Select-Object -First 1
    if ($listener) {
        Stop-Process -Id $listener.OwningProcess -Force
    }
    Start-Process -FilePath "powershell.exe" `
        -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $root "scripts\start-demo.ps1"), "-Port", "8099") `
        -WorkingDirectory $root | Out-Null
    Start-Sleep -Seconds 3
}

Write-Output ("BundleRoot: {0}" -f $bundleRoot)
Write-Output ("FastGPT: http://127.0.0.1:3100/")
if ($StartDemo) {
    Write-Output ("Demo: http://127.0.0.1:8099/")
}
Write-Output "Restore completed."
