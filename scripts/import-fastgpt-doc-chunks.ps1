param(
    [string]$DocChunksCsv = "",
    [string]$DatasetId = "69e03880d9b607f9459582d6",
    [string]$CollectionName = "gx-yiku-doc-chunks-reviewed",
    [string]$ApiBaseUrl = "http://127.0.0.1:3100/api",
    [string]$ApiKey = "fgtest-001",
    [int]$BatchSize = 100
)

$ErrorActionPreference = "Stop"

function Resolve-DocChunksCsvPath {
    param([string]$ConfiguredPath)

    if ($ConfiguredPath -and (Test-Path -LiteralPath $ConfiguredPath)) {
        return (Resolve-Path -LiteralPath $ConfiguredPath).Path
    }

    $desktop = Join-Path $env:USERPROFILE "Desktop"
    $candidates = @(Get-ChildItem -LiteralPath $desktop -Directory -ErrorAction SilentlyContinue |
        ForEach-Object {
            Join-Path $_.FullName "outputs\fastgpt_import\final_for_import\doc_chunks.csv"
        } |
        Where-Object { Test-Path -LiteralPath $_ })

    if ($candidates) {
        return $candidates[0]
    }

    return $null
}

function Invoke-FastGPTJson {
    param(
        [string]$Path,
        [object]$Body
    )

    $uri = $ApiBaseUrl.TrimEnd("/") + $Path
    $json = $Body | ConvertTo-Json -Depth 10
    return Invoke-RestMethod -Uri $uri `
        -Method Post `
        -Headers @{ Authorization = "Bearer $ApiKey" } `
        -ContentType "application/json; charset=utf-8" `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($json))
}

function Invoke-FastGPTDeleteCollection {
    param([string[]]$CollectionIds)

    if (-not $CollectionIds -or $CollectionIds.Count -eq 0) {
        return
    }

    $body = @{ collectionIds = $CollectionIds }
    $null = Invoke-FastGPTJson -Path "/core/dataset/collection/delete" -Body $body
}

function Get-DocChunkPrimaryText {
    param(
        [string]$Title,
        [string]$Content
    )

    $trimmedTitle = ($Title | Out-String).Trim()
    $trimmedContent = ($Content | Out-String).Trim()

    if (-not $trimmedContent) {
        return $trimmedTitle
    }

    if (-not $trimmedTitle) {
        return $trimmedContent
    }

    $looksLikeLocationTitle = $trimmedTitle -match '\.(pdf|pptx)\s+(page|slide)='
    if ($looksLikeLocationTitle) {
        return $trimmedContent
    }

    if ($trimmedTitle.Length -le 80) {
        return $trimmedTitle
    }

    return $trimmedContent
}

$resolvedDocChunksCsv = Resolve-DocChunksCsvPath -ConfiguredPath $DocChunksCsv
if (-not $resolvedDocChunksCsv) {
    throw "Doc chunks CSV not found: $DocChunksCsv"
}

$rows = Import-Csv -LiteralPath $resolvedDocChunksCsv
if (-not $rows -or $rows.Count -eq 0) {
    throw "No doc chunk rows found: $resolvedDocChunksCsv"
}

$listResponse = Invoke-FastGPTJson -Path "/core/dataset/collection/listV2" -Body @{
    offset = 0
    pageSize = 100
    datasetId = $DatasetId
    parentId = $null
    searchText = ""
}

$existing = @($listResponse.data.list | Where-Object { $_.name -eq $CollectionName })
if ($existing.Count -gt 0) {
    Invoke-FastGPTDeleteCollection -CollectionIds @($existing | ForEach-Object { $_._id })
    Start-Sleep -Seconds 1
}

$createResponse = Invoke-FastGPTJson -Path "/core/dataset/collection/create" -Body @{
    datasetId = $DatasetId
    parentId = $null
    name = $CollectionName
    type = "virtual"
    metadata = @{
        importSource = "final_for_import/doc_chunks.csv"
        sourceFile = $resolvedDocChunksCsv
    }
}

$collectionId = [string]$createResponse.data
if (-not $collectionId) {
    throw "Failed to create FastGPT collection."
}

$data = New-Object System.Collections.Generic.List[object]
$index = 0
foreach ($row in $rows) {
    $title = (($row.title | Out-String).Trim())
    $content = (($row.content | Out-String).Trim())
    $sourceFile = (($row.source_file | Out-String).Trim())
    $sourceLoc = (($row.source_loc | Out-String).Trim())

    if (-not $content) {
        continue
    }

    $primary = Get-DocChunkPrimaryText -Title $title -Content $content
    $sourceLine = if ($sourceLoc) {
        "Source: $sourceFile ($sourceLoc)"
    } elseif ($sourceFile) {
        "Source: $sourceFile"
    } else {
        ""
    }

    $parts = @()
    if ($title) { $parts += $title }
    $parts += $content
    if ($sourceLine) { $parts += $sourceLine }
    $indexText = ($parts -join "`n").Trim()

    $data.Add([ordered]@{
        q = $primary
        a = $content
        indexes = @(
            @{
                type = "default"
                dataId = [string]$index
                text = $indexText
            }
        )
    })

    $index += 1
}

if ($data.Count -eq 0) {
    throw "No importable doc chunk rows remained after filtering."
}

$inserted = 0
$batchResults = New-Object System.Collections.Generic.List[object]
for ($offset = 0; $offset -lt $data.Count; $offset += $BatchSize) {
    $take = [Math]::Min($BatchSize, $data.Count - $offset)
    $batch = @($data.GetRange($offset, $take))
    $pushResponse = Invoke-FastGPTJson -Path "/core/dataset/data/pushData" -Body @{
        collectionId = $collectionId
        trainingType = "chunk"
        data = $batch
    }

    $batchResults.Add($pushResponse.data)
    $inserted += [int]$pushResponse.data.insertLen
}

$verifyResponse = Invoke-FastGPTJson -Path "/core/dataset/data/v2/list" -Body @{
    offset = 0
    pageSize = 10
    collectionId = $collectionId
    searchText = ""
}

Write-Output ("CollectionId: {0}" -f $collectionId)
Write-Output ("CollectionName: {0}" -f $CollectionName)
Write-Output ("SourceCsv: {0}" -f $resolvedDocChunksCsv)
Write-Output ("SourceRows: {0}" -f $rows.Count)
Write-Output ("PushedRows: {0}" -f $data.Count)
Write-Output ("InsertedRows: {0}" -f $inserted)
Write-Output ("CollectionDataTotal: {0}" -f $verifyResponse.data.total)
