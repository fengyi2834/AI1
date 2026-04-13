param(
    [Parameter(Mandatory = $false)]
    [string]$Path = ".\\data\\import_ready",
    [Parameter(Mandatory = $false)]
    [string[]]$ExpectedExtensions = @(".md", ".txt", ".csv", ".json", ".jsonl"),
    [Parameter(Mandatory = $false)]
    [string[]]$RequiredFiles = @(),
    [Parameter(Mandatory = $false)]
    [int]$MinFiles = 1,
    [Parameter(Mandatory = $false)]
    [switch]$Recurse = $true
)

$resolvedPath = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
if (-not $resolvedPath) {
    Write-Error "Import outputs path not found: $Path"
    exit 2
}

$extSet = @{}
foreach ($ext in $ExpectedExtensions) {
    if (-not [string]::IsNullOrWhiteSpace($ext)) {
        $norm = $ext.Trim().ToLowerInvariant()
        if (-not $norm.StartsWith(".")) { $norm = "." + $norm }
        $extSet[$norm] = $true
    }
}

$files = Get-ChildItem -LiteralPath $resolvedPath -File -Recurse:$Recurse | Where-Object {
    $extSet.ContainsKey($_.Extension.ToLowerInvariant())
}

$count = $files.Count
$totalBytes = ($files | Measure-Object -Property Length -Sum).Sum
$totalMB = [Math]::Round($totalBytes / 1MB, 2)

Write-Output ("Path: {0}" -f $resolvedPath)
Write-Output ("Expected Extensions: {0}" -f ($extSet.Keys -join ", "))
Write-Output ("Files: {0}" -f $count)
Write-Output ("Total Size (MB): {0}" -f $totalMB)

if ($RequiredFiles.Count -gt 0) {
    $missing = @()
    foreach ($req in $RequiredFiles) {
        $reqPath = Join-Path -Path $resolvedPath -ChildPath $req
        if (-not (Test-Path -LiteralPath $reqPath)) {
            $missing += $req
        }
    }
    if ($missing.Count -gt 0) {
        Write-Error ("Missing required files: {0}" -f ($missing -join ", "))
        exit 1
    }
}

if ($count -lt $MinFiles) {
    Write-Error ("File count {0} is less than MinFiles {1}." -f $count, $MinFiles)
    exit 1
}

$zeroFiles = $files | Where-Object { $_.Length -eq 0 }
if ($zeroFiles.Count -gt 0) {
    Write-Warning ("Zero-byte files: {0}" -f ($zeroFiles.FullName -join "; "))
}

$csvFiles = $files | Where-Object { $_.Extension -ieq ".csv" }
foreach ($csv in $csvFiles) {
    $firstLine = Get-Content -LiteralPath $csv.FullName -TotalCount 1 -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($firstLine)) {
        Write-Warning ("CSV header is empty: {0}" -f $csv.FullName)
    }
}

exit 0
