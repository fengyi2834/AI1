param(
    [string]$ModelId = "glm-4-flash-250414",
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

$tmpJs = Join-Path $PWD "tmp\\fastgpt_register_model.js"
if (-not (Test-Path -LiteralPath (Split-Path -Parent $tmpJs))) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $tmpJs) -Force | Out-Null
}

$js = @'
const modelId = '__MODEL_ID__';
const exists = db.system_models.findOne({ model: modelId });
if (!exists) {
  db.system_models.insertOne({
    model: modelId,
    metadata: {
      provider: 'ChatGLM',
      model: modelId,
      name: modelId,
      type: 'llm',
      maxContext: 128000,
      maxTokens: 4096,
      quoteMaxToken: 32000,
      maxTemperature: 1,
      showTopP: true,
      responseFormatList: ['text', 'json_object'],
      showStopSign: true,
      vision: false,
      reasoning: false,
      toolChoice: true,
      maxResponse: 4096,
      isActive: true
    }
  });
  printjson({ ok: true, inserted: modelId });
} else {
  db.system_models.updateOne(
    { model: modelId },
    {
      $set: {
        'metadata.provider': 'ChatGLM',
        'metadata.model': modelId,
        'metadata.name': modelId,
        'metadata.type': 'llm',
        'metadata.maxContext': 128000,
        'metadata.maxTokens': 4096,
        'metadata.quoteMaxToken': 32000,
        'metadata.maxTemperature': 1,
        'metadata.showTopP': true,
        'metadata.responseFormatList': ['text', 'json_object'],
        'metadata.showStopSign': true,
        'metadata.vision': false,
        'metadata.reasoning': false,
        'metadata.toolChoice': true,
        'metadata.maxResponse': 4096,
        'metadata.isActive': true
      }
    }
  );
  printjson({ ok: true, updated: modelId });
}
'@

$js = $js.Replace('__MODEL_ID__', $ModelId)
$js | Set-Content -LiteralPath $tmpJs -Encoding UTF8

try {
    Invoke-MongoScriptFile -LocalPath $tmpJs -ContainerName $MongoContainer -Username $MongoUser -Password $MongoPassword
} finally {
    Remove-Item -LiteralPath $tmpJs -Force -ErrorAction SilentlyContinue
}
