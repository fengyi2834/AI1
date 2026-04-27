param(
    [string]$SourceCsv,
    [string]$DatasetId = "69e03880d9b607f9459582d6",
    [string]$CollectionName = "",
    [string]$ApiBaseUrl = "http://127.0.0.1:3100/api",
    [string]$ApiKey = "fgtest-001",
    [string]$MongoContainer = "fastgpt-mongo",
    [string]$MongoUser = "myusername",
    [string]$MongoPassword = "mypassword"
)

$ErrorActionPreference = "Stop"

function Invoke-MongoScriptFile {
    param(
        [string]$LocalPath,
        [string]$ContainerName,
        [string]$Username,
        [string]$Password
    )

    $containerPath = "/tmp/" + [System.IO.Path]::GetFileName($LocalPath)

    try {
        docker cp $LocalPath "${ContainerName}:${containerPath}" | Out-Null
        docker exec $ContainerName sh -lc "mongosh -u '$Username' -p '$Password' --authenticationDatabase admin fastgpt --quiet '$containerPath'"
    } finally {
        docker exec $ContainerName sh -lc "rm -f '$containerPath'" | Out-Null
    }
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

if (-not (Test-Path -LiteralPath $SourceCsv)) {
    throw "Source CSV not found: $SourceCsv"
}

if (-not $CollectionName) {
    $CollectionName = [System.IO.Path]::GetFileNameWithoutExtension($SourceCsv)
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

if (-not $cleanRows -or $cleanRows.Count -eq 0) {
    throw "No valid FAQ rows remained after cleaning."
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
        importSource = "faq_csv"
        sourceFile = (Resolve-Path -LiteralPath $SourceCsv).Path
    }
}

$collectionId = [string]$createResponse.data
if (-not $collectionId) {
    throw "Failed to create FastGPT collection."
}

$rowsJson = $cleanRows | ConvertTo-Json -Depth 4 -Compress
$tmpJs = Join-Path $PWD "tmp\\fastgpt_import_faq_collection.js"

if (-not (Test-Path -LiteralPath (Split-Path -Parent $tmpJs))) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $tmpJs) -Force | Out-Null
}

$js = @'
const rows = __ROWS_JSON__;
const datasetId = ObjectId('__DATASET_ID__');
const collectionId = ObjectId('__COLLECTION_ID__');

const dataset = db.datasets.findOne({ _id: datasetId });
if (!dataset) {
  throw new Error('dataset_not_found');
}

function tokenize(text) {
  if (!text) return [];
  const tokens = [];
  const seen = new Set();

  const latinMatches = text.match(/[A-Za-z0-9]{2,}/g) || [];
  for (const item of latinMatches) {
    const token = item.toLowerCase();
    if (!seen.has(token)) {
      seen.add(token);
      tokens.push(token);
    }
  }

  const cjkMatches = text.match(/[\u4e00-\u9fff]+/g) || [];
  for (const segment of cjkMatches) {
    if (segment.length >= 2) {
      for (let i = 0; i <= segment.length - 2; i++) {
        const token = segment.slice(i, i + 2);
        if (!seen.has(token)) {
          seen.add(token);
          tokens.push(token);
        }
      }
    } else if (!seen.has(segment)) {
      seen.add(segment);
      tokens.push(segment);
    }
  }

  return tokens;
}

db.dataset_datas.deleteMany({ collectionId });
db.dataset_data_texts.deleteMany({ collectionId });

const now = new Date();
let chunkIndex = 0;
let rawTextLength = 0;

for (const row of rows) {
  const q = String(row.question || '').trim();
  const a = String(row.answer || '').trim();
  if (!q || !a) continue;

  const dataId = new ObjectId();
  const text = 'Question: ' + q + '\nAnswer: ' + a;
  const fullTextToken = tokenize(q + ' ' + a).join(' ');

  db.dataset_datas.insertOne({
    _id: dataId,
    teamId: dataset.teamId,
    tmbId: dataset.tmbId,
    datasetId,
    collectionId,
    q,
    a,
    indexes: [
      {
        type: 'default',
        dataId: String(chunkIndex),
        text
      }
    ],
    chunkIndex,
    history: [],
    updateTime: now,
    __v: 0
  });

  db.dataset_data_texts.insertOne({
    teamId: dataset.teamId,
    datasetId,
    collectionId,
    dataId,
    fullTextToken,
    __v: 0
  });

  rawTextLength += text.length;
  chunkIndex += 1;
}

db.dataset_collections.updateOne(
  { _id: collectionId },
  {
    $set: {
      updateTime: now,
      rawTextLength
    }
  }
);

printjson({
  ok: true,
  datasetId,
  collectionId,
  inserted: chunkIndex,
  rawTextLength
});
'@

$js = $js.Replace('__ROWS_JSON__', $rowsJson)
$js = $js.Replace('__DATASET_ID__', $DatasetId)
$js = $js.Replace('__COLLECTION_ID__', $collectionId)
$js | Set-Content -LiteralPath $tmpJs -Encoding UTF8

try {
    Invoke-MongoScriptFile -LocalPath $tmpJs -ContainerName $MongoContainer -Username $MongoUser -Password $MongoPassword
} finally {
    Remove-Item -LiteralPath $tmpJs -Force -ErrorAction SilentlyContinue
}

$verifyList = Invoke-FastGPTJson -Path "/core/dataset/data/v2/list" -Body @{
    offset = 0
    pageSize = 10
    collectionId = $collectionId
    searchText = ""
}

Write-Output ("CollectionId: {0}" -f $collectionId)
Write-Output ("CollectionName: {0}" -f $CollectionName)
Write-Output ("SourceCsv: {0}" -f (Resolve-Path -LiteralPath $SourceCsv).Path)
Write-Output ("SourceRows: {0}" -f $rows.Count)
Write-Output ("ImportedRows: {0}" -f $cleanRows.Count)
Write-Output ("CollectionDataTotal: {0}" -f $verifyList.data.total)
