param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = ".\\.env",
    [Parameter(Mandatory = $false)]
    [string]$RequiredKeysPath = "",
    [Parameter(Mandatory = $false)]
    [string[]]$RequiredKeys = @()
)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($RequiredKeysPath)) {
    $RequiredKeysPath = Join-Path -Path $scriptRoot -ChildPath "required_keys.txt"
}

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    $fallback = ".\\config\\.env"
    if (Test-Path -LiteralPath $fallback) {
        $ConfigPath = $fallback
        Write-Output ("ConfigPath not found, using fallback: {0}" -f $ConfigPath)
    } else {
        Write-Error "Config file not found: $ConfigPath"
        exit 2
    }
}

if ($RequiredKeys.Count -eq 0) {
    if (Test-Path -LiteralPath $RequiredKeysPath) {
        $RequiredKeys = Get-Content -LiteralPath $RequiredKeysPath | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_)
        }
    }
}

if ($RequiredKeys.Count -eq 0) {
    Write-Error "No required keys provided. Pass -RequiredKeys or populate required_keys.txt."
    exit 2
}

$lines = Get-Content -LiteralPath $ConfigPath -ErrorAction SilentlyContinue
$kv = @{}
foreach ($line in $lines) {
    $trim = $line.Trim()
    if ($trim.StartsWith("#") -or $trim.StartsWith(";") -or $trim -eq "") { continue }
    $match = [Regex]::Match($trim, "^(?<key>[A-Za-z0-9_.-]+)\\s*=\\s*(?<val>.*)$")
    if ($match.Success) {
        $key = $match.Groups["key"].Value
        $val = $match.Groups["val"].Value.Trim()
        if ($val.StartsWith('"') -and $val.EndsWith('"')) {
            $val = $val.Trim('"')
        }
        $kv[$key] = $val
    }
}

$missing = @()
$empty = @()
foreach ($key in $RequiredKeys) {
    if (-not $kv.ContainsKey($key)) {
        $missing += $key
    } elseif ([string]::IsNullOrWhiteSpace($kv[$key])) {
        $empty += $key
    }
}

Write-Output ("Config file: {0}" -f (Resolve-Path -LiteralPath $ConfigPath))
Write-Output ("Required keys: {0}" -f ($RequiredKeys -join ", "))
Write-Output ("Found keys: {0}" -f ($kv.Keys -join ", "))

if ($missing.Count -gt 0) {
    Write-Error ("Missing keys: {0}" -f ($missing -join ", "))
}
if ($empty.Count -gt 0) {
    Write-Error ("Empty keys: {0}" -f ($empty -join ", "))
}

if ($missing.Count -gt 0 -or $empty.Count -gt 0) {
    exit 1
}

exit 0
