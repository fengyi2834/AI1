param(
    [string]$SourceCsv = "",
    [string]$OutputCsv = ".\data\faq\gx_yiku_fastgpt_faq_clean.csv"
)

$ErrorActionPreference = "Stop"

if (-not $SourceCsv) {
    $candidate = Get-ChildItem -LiteralPath "." -File -Filter "*.csv" |
        Where-Object { $_.Name -match "FAQ|faq" } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($candidate) {
        $SourceCsv = $candidate.FullName
    }
}

if (-not (Test-Path -LiteralPath $SourceCsv)) {
    throw "Source CSV not found: $SourceCsv"
}

$rows = Import-Csv -LiteralPath $SourceCsv
if (-not $rows -or $rows.Count -eq 0) {
    throw "No FAQ rows found in: $SourceCsv"
}

$cleanRows = foreach ($row in $rows) {
    $question = (($row.question | Out-String).Trim())
    $answer = (($row.answer | Out-String).Trim())

    if (-not $question -or -not $answer) {
        continue
    }

    [pscustomobject]@{
        question = $question
        answer = $answer
    }
}

$outDir = Split-Path -Parent $OutputCsv
if (-not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$cleanRows | Export-Csv -LiteralPath $OutputCsv -NoTypeInformation -Encoding UTF8

Write-Output ("Rebuilt FAQ rows: {0}" -f $cleanRows.Count)
Write-Output ("Output: {0}" -f (Resolve-Path -LiteralPath $OutputCsv))
