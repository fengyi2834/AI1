param(
    [string]$PythonSelector = "3.12",
    [string]$VenvPath = ".\.venv",
    [string]$RequirementsPath = ".\tools\knowledge_ingest\requirements.txt"
)

$ErrorActionPreference = "Stop"

function Get-PyLauncher {
    $command = Get-Command py -ErrorAction SilentlyContinue
    if (-not $command) {
        throw "Python launcher 'py' was not found. Please install Python 3.12 first."
    }
    return $command.Source
}

function New-Venv {
    param(
        [string]$PyLauncher,
        [string]$Selector,
        [string]$TargetPath
    )

    try {
        & $PyLauncher -$Selector -m venv --clear $TargetPath
        return
    } catch {
        if (Test-Path -LiteralPath $TargetPath) {
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $backupPath = "$TargetPath.broken.$timestamp"
            Move-Item -LiteralPath $TargetPath -Destination $backupPath -Force
            Write-Output "Existing broken venv moved to: $backupPath"
        }
        & $PyLauncher -$Selector -m venv $TargetPath
    }
}

$pyLauncher = Get-PyLauncher
New-Venv -PyLauncher $pyLauncher -Selector $PythonSelector -TargetPath $VenvPath

$pythonExe = Join-Path $VenvPath "Scripts\python.exe"
if (-not (Test-Path -LiteralPath $pythonExe)) {
    throw "Venv python executable not found: $pythonExe"
}

& $pythonExe -m pip install --upgrade pip
if (Test-Path -LiteralPath $RequirementsPath) {
    & $pythonExe -m pip install -r $RequirementsPath
}

& $pythonExe -c "import openpyxl, docx; print('VENV_OK')"
Write-Output "Rebuilt virtual environment at: $VenvPath"
