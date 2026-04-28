param(
    [string]$OutputRoot = ".\restore_bundles",
    [string]$BundleName = "",
    [string]$MongoContainer = "fastgpt-mongo",
    [string]$MongoUser = "myusername",
    [string]$MongoPassword = "mypassword",
    [switch]$IncludeEnvLocal,
    [string[]]$ExtraSourcePaths = @()
)

$ErrorActionPreference = "Stop"

function Copy-TreeIfExists {
    param(
        [string]$SourcePath,
        [string]$TargetPath
    )

    if (-not (Test-Path -LiteralPath $SourcePath)) {
        return
    }

    New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
    Get-ChildItem -LiteralPath $SourcePath -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $TargetPath -Recurse -Force
    }
}

$root = (Resolve-Path -LiteralPath ".").Path
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
if (-not $BundleName) {
    $BundleName = "fastgpt_restore_bundle_$timestamp"
}

$outputRootAbs = if ([System.IO.Path]::IsPathRooted($OutputRoot)) {
    $OutputRoot
} else {
    Join-Path $root $OutputRoot
}

$bundleDir = Join-Path $outputRootAbs $BundleName
$mongoDir = Join-Path $bundleDir "mongo"
$projectDataDir = Join-Path $bundleDir "project_data"
$envDir = Join-Path $bundleDir "env"
$metaPath = Join-Path $bundleDir "metadata.json"
$archivePath = Join-Path $outputRootAbs ($BundleName + ".zip")

New-Item -ItemType Directory -Path $mongoDir -Force | Out-Null
New-Item -ItemType Directory -Path $projectDataDir -Force | Out-Null

$containerArchive = "/tmp/fastgpt_restore_bundle.archive.gz"
$hostArchive = Join-Path $mongoDir "fastgpt.archive.gz"

docker exec $MongoContainer sh -lc "rm -f '$containerArchive'" | Out-Null
docker exec $MongoContainer sh -lc "mongodump --gzip --archive='$containerArchive' --db fastgpt -u '$MongoUser' -p '$MongoPassword' --authenticationDatabase admin" | Out-Null
docker cp "${MongoContainer}:$containerArchive" $hostArchive | Out-Null
docker exec $MongoContainer sh -lc "rm -f '$containerArchive'" | Out-Null

Copy-TreeIfExists -SourcePath (Join-Path $root "data\faq") -TargetPath (Join-Path $projectDataDir "faq")
Copy-TreeIfExists -SourcePath (Join-Path $root "data\import_ready") -TargetPath (Join-Path $projectDataDir "import_ready")

foreach ($extra in $ExtraSourcePaths) {
    if (-not $extra) {
        continue
    }

    $sourceAbs = if ([System.IO.Path]::IsPathRooted($extra)) {
        $extra
    } else {
        Join-Path $root $extra
    }

    if (-not (Test-Path -LiteralPath $sourceAbs)) {
        continue
    }

    $name = Split-Path -Leaf $sourceAbs
    $target = Join-Path $bundleDir "extra\$name"
    if (Test-Path -LiteralPath $sourceAbs -PathType Container) {
        Copy-TreeIfExists -SourcePath $sourceAbs -TargetPath $target
    } else {
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        Copy-Item -LiteralPath $sourceAbs -Destination $target -Force
    }
}

if ($IncludeEnvLocal) {
    $envSource = Join-Path $root "infra\fastgpt\.env.local"
    if (Test-Path -LiteralPath $envSource) {
        New-Item -ItemType Directory -Path $envDir -Force | Out-Null
        Copy-Item -LiteralPath $envSource -Destination (Join-Path $envDir ".env.local.private") -Force
    }
}

$gitBranch = ""
$gitCommit = ""
try {
    $gitBranch = (git branch --show-current).Trim()
    $gitCommit = (git rev-parse HEAD).Trim()
} catch {
    $gitBranch = ""
    $gitCommit = ""
}

$metadata = [ordered]@{
    bundleName = $BundleName
    createdAt = (Get-Date).ToString("s")
    projectRoot = $root
    gitBranch = $gitBranch
    gitCommit = $gitCommit
    containsMongoArchive = (Test-Path -LiteralPath $hostArchive)
    containsEnvLocal = (Test-Path -LiteralPath (Join-Path $envDir ".env.local.private"))
    notes = @(
        "This bundle is intended for private teammate-to-teammate restore only.",
        "It may contain database state and optionally private environment configuration.",
        "Do not publish this bundle to a public repository or public file share."
    )
}

$metadata | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $metaPath -Encoding UTF8

if (Test-Path -LiteralPath $archivePath) {
    Remove-Item -LiteralPath $archivePath -Force
}
Compress-Archive -LiteralPath $bundleDir -DestinationPath $archivePath -Force

Write-Output ("BundleDir: {0}" -f $bundleDir)
Write-Output ("BundleZip: {0}" -f $archivePath)
Write-Output ("MongoArchive: {0}" -f $hostArchive)
