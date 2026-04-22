param(
    [Parameter(Mandatory = $false)]
    [string]$RawDocsPath = ".\\data\\raw_docs",
    [Parameter(Mandatory = $false)]
    [string]$ImportPath = ".\\data\\import_ready",
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = ".\\infra\\fastgpt\\.env.local"
)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$checkRaw = Join-Path -Path $scriptRoot -ChildPath "check_raw_docs.ps1"
$checkImport = Join-Path -Path $scriptRoot -ChildPath "check_import_outputs.ps1"
$checkConfig = Join-Path -Path $scriptRoot -ChildPath "check_config.ps1"

$exitCodes = @()

Write-Output "Running raw docs check..."
& $checkRaw -Path $RawDocsPath
$exitCodes += $LASTEXITCODE

Write-Output "Running import outputs check..."
& $checkImport -Path $ImportPath
$exitCodes += $LASTEXITCODE

Write-Output "Running config check..."
& $checkConfig -ConfigPath $ConfigPath
$exitCodes += $LASTEXITCODE

$max = ($exitCodes | Measure-Object -Maximum).Maximum
if ($max -eq $null) { $max = 0 }
exit $max
