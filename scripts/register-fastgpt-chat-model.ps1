param(
    [string]$ModelId = "glm-4-flash-250414",
    [bool]$Vision = $false,
    [bool]$Reasoning = $false,
    [int]$MaxContext = 128000,
    [int]$MaxTokens = 4096,
    [int]$QuoteMaxToken = 32000,
    [int]$MaxResponse = 4096,
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
const vision = __VISION__;
const reasoning = __REASONING__;
const maxContext = __MAX_CONTEXT__;
const maxTokens = __MAX_TOKENS__;
const quoteMaxToken = __QUOTE_MAX_TOKENS__;
const maxResponse = __MAX_RESPONSE__;
const exists = db.system_models.findOne({ model: modelId });
if (!exists) {
  db.system_models.insertOne({
    model: modelId,
    metadata: {
      provider: 'ChatGLM',
      model: modelId,
      name: modelId,
      type: 'llm',
      maxContext,
      maxTokens,
      quoteMaxToken,
      maxTemperature: 1,
      showTopP: true,
      responseFormatList: ['text', 'json_object'],
      showStopSign: true,
      vision,
      reasoning,
      toolChoice: true,
      maxResponse,
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
        'metadata.maxContext': maxContext,
        'metadata.maxTokens': maxTokens,
        'metadata.quoteMaxToken': quoteMaxToken,
        'metadata.maxTemperature': 1,
        'metadata.showTopP': true,
        'metadata.responseFormatList': ['text', 'json_object'],
        'metadata.showStopSign': true,
        'metadata.vision': vision,
        'metadata.reasoning': reasoning,
        'metadata.toolChoice': true,
        'metadata.maxResponse': maxResponse,
        'metadata.isActive': true
      }
    }
  );
  printjson({ ok: true, updated: modelId });
}
'@

$js = $js.Replace('__MODEL_ID__', $ModelId)
$js = $js.Replace('__VISION__', $Vision.ToString().ToLowerInvariant())
$js = $js.Replace('__REASONING__', $Reasoning.ToString().ToLowerInvariant())
$js = $js.Replace('__MAX_CONTEXT__', $MaxContext.ToString())
$js = $js.Replace('__MAX_TOKENS__', $MaxTokens.ToString())
$js = $js.Replace('__QUOTE_MAX_TOKENS__', $QuoteMaxToken.ToString())
$js = $js.Replace('__MAX_RESPONSE__', $MaxResponse.ToString())
$js | Set-Content -LiteralPath $tmpJs -Encoding UTF8

try {
    Invoke-MongoScriptFile -LocalPath $tmpJs -ContainerName $MongoContainer -Username $MongoUser -Password $MongoPassword
} finally {
    Remove-Item -LiteralPath $tmpJs -Force -ErrorAction SilentlyContinue
}
