param(
    [string]$InputDir = ".\data\raw_docs",
    [string]$OutputDir = ".\data\import_ready",
    [string]$Formats = "md,json,csv",
    [int]$MaxChars = 1500,
    [string]$PythonImage = "python:3.12-slim"
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path -LiteralPath "."
$inputPath = Resolve-Path -LiteralPath $InputDir -ErrorAction SilentlyContinue
if (-not $inputPath) {
    throw "Input path not found: $InputDir"
}

if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$outputPath = Resolve-Path -LiteralPath $OutputDir
$workspaceMount = $repoRoot.Path
$containerInput = "/workspace/" + (($inputPath.Path.Substring($repoRoot.Path.Length)).TrimStart('\') -replace "\\", "/")
$containerOutput = "/workspace/" + (($outputPath.Path.Substring($repoRoot.Path.Length)).TrimStart('\') -replace "\\", "/")

$ingestCommand = @(
    "python /workspace/tools/knowledge_ingest/ingest.py",
    "--input `"$containerInput`"",
    "--output `"$containerOutput`"",
    "--format `"$Formats`"",
    "--max-chars $MaxChars"
) -join " "

docker run --rm `
    -v "${workspaceMount}:/workspace" `
    -w /workspace `
    $PythonImage `
    sh -lc "python -m pip install --no-cache-dir -r /workspace/tools/knowledge_ingest/requirements.txt && $ingestCommand"
