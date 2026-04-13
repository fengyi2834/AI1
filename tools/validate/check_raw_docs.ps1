param(
    [Parameter(Mandatory = $false)]
    [string]$Path = ".\\data\\raw_docs",
    [Parameter(Mandatory = $false)]
    [string[]]$Extensions = @(".xlsx", ".docx"),
    [Parameter(Mandatory = $false)]
    [int]$MinFiles = 1,
    [Parameter(Mandatory = $false)]
    [switch]$Recurse = $true
)

$resolvedPath = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
if (-not $resolvedPath) {
    Write-Error "Raw docs path not found: $Path"
    exit 2
}

$extSet = @{}
foreach ($ext in $Extensions) {
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
Write-Output ("Extensions: {0}" -f ($extSet.Keys -join ", "))
Write-Output ("Files: {0}" -f $count)
Write-Output ("Total Size (MB): {0}" -f $totalMB)

if ($count -lt $MinFiles) {
    Write-Error ("File count {0} is less than MinFiles {1}." -f $count, $MinFiles)
    exit 1
}

$zeroFiles = $files | Where-Object { $_.Length -eq 0 }
if ($zeroFiles.Count -gt 0) {
    Write-Warning ("Zero-byte files: {0}" -f ($zeroFiles.FullName -join "; "))
}

$topLargest = $files | Sort-Object Length -Descending | Select-Object -First 5
if ($topLargest.Count -gt 0) {
    Write-Output "Top 5 largest files:"
    foreach ($f in $topLargest) {
        $mb = [Math]::Round($f.Length / 1MB, 2)
        Write-Output ("  {0} ({1} MB)" -f $f.FullName, $mb)
    }
}

exit 0
