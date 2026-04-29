param(
    [int]$Port = 8099,
    [switch]$NoDemo,
    [switch]$NoLocal,
    [switch]$DemoInCurrentWindow
)

$ErrorActionPreference = "Stop"

$root = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$startLocalScript = Join-Path $root "scripts\start-local.ps1"
$startDemoScript = Join-Path $root "scripts\start-demo.ps1"

function Test-PortListening {
    param([int]$PortNumber)

    return $null -ne (Get-NetTCPConnection -LocalPort $PortNumber -State Listen -ErrorAction SilentlyContinue)
}

function Start-DemoWindow {
    param(
        [string]$DemoScriptPath,
        [int]$DemoPort
    )

    $escapedScript = $DemoScriptPath.Replace("'", "''")
    $command = "& '$escapedScript' -Port $DemoPort"
    & cmd.exe /c start "AI1 Demo" "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command $command | Out-Null
}

if (-not (Test-Path -LiteralPath $startLocalScript)) {
    throw "Missing script: $startLocalScript"
}

if (-not (Test-Path -LiteralPath $startDemoScript)) {
    throw "Missing script: $startDemoScript"
}

Push-Location $root
try {
    if (-not $NoLocal) {
        Write-Host "Starting local FastGPT stack from $root" -ForegroundColor Cyan
        & $startLocalScript
    }

    if (-not $NoDemo) {
        if (Test-PortListening -PortNumber $Port) {
            Write-Host "Demo server is already listening at http://127.0.0.1:$Port/" -ForegroundColor Yellow
        } else {
            if ($DemoInCurrentWindow) {
                Write-Host "Starting demo server in the current window on http://127.0.0.1:$Port/" -ForegroundColor Cyan
                & $startDemoScript -Port $Port
            } else {
                Write-Host "Starting demo server in a new window on http://127.0.0.1:$Port/" -ForegroundColor Cyan
                Start-DemoWindow -DemoScriptPath $startDemoScript -DemoPort $Port
                Start-Sleep -Seconds 2
            }
        }
    }

    Write-Host ""
    Write-Host "Project root: $root" -ForegroundColor Green
    Write-Host "FastGPT: http://127.0.0.1:3100/" -ForegroundColor Green
    if (-not $NoDemo) {
        Write-Host "Demo page: http://127.0.0.1:$Port/" -ForegroundColor Green
    }
} finally {
    Pop-Location
}
