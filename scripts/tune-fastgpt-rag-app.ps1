param(
    [string]$AppId = "69e0562ea67193262b8de666",
    [string]$VersionId = "69e0562ea67193262b8de667",
    [string]$DatasetId = "69e03880d9b607f9459582d6",
    [string]$AnswerModel = "glm-4-flash-250414",
    [bool]$EnableVision = $false,
    [bool]$EnableImageUpload = $false,
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

$tmpJs = Join-Path $PWD "tmp\\fastgpt_tune_rag_app.js"
if (-not (Test-Path -LiteralPath (Split-Path -Parent $tmpJs))) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $tmpJs) -Force | Out-Null
}

$js = @'
const appId = ObjectId('__APP_ID__');
const versionId = ObjectId('__VERSION_ID__');
const datasetRefId = '__DATASET_ID__';
const answerModel = '__ANSWER_MODEL__';
const enableVision = __ENABLE_VISION__;
const enableImageUpload = __ENABLE_IMAGE_UPLOAD__;
const systemId = 'gxSystemConfig';
const startId = 'gxWorkflowStart';
const datasetNodeId = 'gxDatasetSearch';
const chatNodeId = 'gxChatNode';

const nodes = [
  {
    nodeId: systemId,
    name: 'System Config',
    intro: '',
    flowNodeType: 'systemConfig',
    position: { x: 531.2422736065552, y: -486.7611729549753 },
    inputs: [],
    outputs: []
  },
  {
    nodeId: startId,
    name: 'Workflow Start',
    intro: '',
    avatar: 'core/workflow/template/workflowStart',
    flowNodeType: 'workflowStart',
    showStatus: true,
    position: { x: 558.4082376415505, y: 123.72387429194112 },
    inputs: [
      {
        key: 'userChatInput',
        renderTypeList: ['reference', 'textarea'],
        valueType: 'string',
        label: 'User Question',
        toolDescription: 'user question',
        required: true
      }
    ],
    outputs: [
      { id: 'userChatInput', key: 'userChatInput', label: 'User Question', type: 'static', valueType: 'string' },
      { id: 'userFiles', key: 'userFiles', label: 'User Files', description: 'User uploaded files', type: 'static', valueType: 'arrayString' }
    ]
  },
  {
    nodeId: datasetNodeId,
    name: 'Dataset Search',
    intro: 'Search FAQ knowledge base',
    avatar: 'core/workflow/template/datasetSearch',
    flowNodeType: 'datasetSearchNode',
    showStatus: true,
    position: { x: 918.5901682164496, y: -227.11542247619582 },
    version: '4.9.2',
    inputs: [
      { key: 'datasets', renderTypeList: ['selectDataset', 'reference'], label: 'Select dataset', value: [{ datasetId: datasetRefId }], valueType: 'selectDataset', list: [], required: true },
      { key: 'similarity', renderTypeList: ['selectDatasetParamsModal'], label: '', value: 0, valueType: 'number' },
      { key: 'limit', renderTypeList: ['hidden'], label: '', value: 20, valueType: 'number' },
      { key: 'searchMode', renderTypeList: ['hidden'], label: '', valueType: 'string', value: 'fullTextRecall' },
      { key: 'embeddingWeight', renderTypeList: ['hidden'], label: '', valueType: 'number', value: 1 },
      { key: 'usingReRank', renderTypeList: ['hidden'], label: '', valueType: 'boolean', value: false },
      { key: 'rerankModel', renderTypeList: ['hidden'], label: '', valueType: 'string', value: '' },
      { key: 'rerankWeight', renderTypeList: ['hidden'], label: '', valueType: 'number', value: 0.5 },
      { key: 'datasetSearchUsingExtensionQuery', renderTypeList: ['hidden'], label: '', valueType: 'boolean', value: false },
      { key: 'datasetSearchExtensionModel', renderTypeList: ['hidden'], label: '', valueType: 'string', value: '' },
      { key: 'datasetSearchExtensionBg', renderTypeList: ['hidden'], label: '', valueType: 'string', value: '' },
      { key: 'authTmbId', renderTypeList: ['hidden'], label: '', valueType: 'boolean', value: false },
      { key: 'userChatInput', renderTypeList: ['reference', 'textarea'], valueType: 'string', label: 'Question to search', toolDescription: 'content to search', required: true, value: [startId, 'userChatInput'] }
    ],
    outputs: [
      { id: 'quoteQA', key: 'quoteQA', label: 'Dataset Quote', description: 'Retrieved knowledge snippets', type: 'static', valueType: 'datasetQuote' },
      { id: 'system_error_text', key: 'system_error_text', type: 'error', valueType: 'string', label: 'Error Text' }
    ]
  },
  {
    nodeId: chatNodeId,
    name: 'AI Chat',
    intro: 'Answer with knowledge base grounding',
    avatar: 'core/workflow/template/aiChat',
    flowNodeType: 'chatNode',
    showStatus: true,
    position: { x: 1106.3238387960757, y: -350.6030674683474 },
    version: '4.9.7',
    inputs: [
      { key: 'model', renderTypeList: ['settingLLMModel', 'reference'], label: '', valueType: 'string', value: answerModel },
      { key: 'temperature', renderTypeList: ['hidden'], label: '', value: 0.18, valueType: 'number' },
      { key: 'maxToken', renderTypeList: ['hidden'], label: '', value: 320, valueType: 'number' },
      { key: 'isResponseAnswerText', renderTypeList: ['hidden'], label: '', value: true, valueType: 'boolean' },
      { key: 'aiChatQuoteRole', renderTypeList: ['hidden'], label: '', valueType: 'string', value: 'system' },
      { key: 'quoteTemplate', renderTypeList: ['hidden'], label: '', valueType: 'string', value: '{instruction:"{{q}}",output:"{{a}}",source:"{{source}}"}' },
      { key: 'quotePrompt', renderTypeList: ['hidden'], label: '', valueType: 'string', value: '\u5df2\u77e5\u8d44\u6599\uff1a\n{{quote}}\n\n\u7528\u6237\u95ee\u9898\uff1a{{question}}\n\n\u56de\u7b54\u8981\u6c42\uff1a\n1. \u5168\u7a0b\u4f7f\u7528\u7b80\u4f53\u4e2d\u6587\u3002\n2. \u5148\u76f4\u63a5\u56de\u7b54\u7528\u6237\u6700\u5173\u5fc3\u7684\u95ee\u9898\uff0c\u518d\u8865 2 \u5230 4 \u4e2a\u6700\u6709\u4ef7\u503c\u7684\u4e8b\u5b9e\u3002\n3. \u8bed\u6c14\u50cf\u61c2\u4ea7\u54c1\u7684\u9500\u552e\u987e\u95ee\uff0c\u81ea\u7136\u3001\u4e13\u4e1a\u3001\u514b\u5236\uff0c\u4e0d\u8981\u50cf\u8bf4\u660e\u4e66\u3002\n4. \u53ea\u80fd\u4f7f\u7528\u5df2\u77e5\u8d44\u6599\uff0c\u4e0d\u8981\u81ea\u884c\u8865\u5168\u672a\u63d0\u4f9b\u7684\u4e8b\u5b9e\u3002\n5. \u5982\u679c\u8d44\u6599\u53ea\u652f\u6301\u90e8\u5206\u7ed3\u8bba\uff0c\u8981\u660e\u786e\u8bf4\u201c\u76ee\u524d\u8d44\u6599\u80fd\u786e\u8ba4\u5230\u8fd9\u91cc\u201d\u3002\n6. \u5982\u679c\u95ee\u9898\u6d89\u53ca\u65b0\u623f\u3001\u6c14\u5473\u3001\u73af\u4fdd\u3001\u6548\u679c\u7b49\u987e\u8651\uff0c\u53ef\u4ee5\u5148\u7528\u4e00\u53e5\u7b80\u77ed\u5171\u60c5\uff0c\u4f46\u4e0d\u8981\u8fc7\u5ea6\u3002' },
      { key: 'systemPrompt', renderTypeList: ['textarea', 'reference'], max: 3000, valueType: 'string', label: 'System Prompt', description: 'RAG customer service prompt', placeholder: 'System prompt', value: '\u4f60\u662f\u201c\u5e7f\u897f\u4ebf\u5e93\u5149\u517b\u7845\u85fb\u73af\u4fdd\u79d1\u6280\u6709\u9650\u516c\u53f8\u201d\u7684\u5b98\u7f51\u9500\u552e\u5ba2\u670d\u987e\u95ee\uff0c\u4e0d\u662f\u901a\u7528\u52a9\u624b\u3002\u5168\u7a0b\u7528\u7b80\u4f53\u4e2d\u6587\u3002\u56de\u7b54\u65f6\u5148\u7ed9\u7ed3\u8bba\uff0c\u518d\u8865\u6700\u5173\u952e\u7684\u4f9d\u636e\uff0c\u8bed\u6c14\u81ea\u7136\u3001\u4e13\u4e1a\u3001\u514b\u5236\uff0c\u50cf\u771f\u5b9e\u987e\u95ee\uff0c\u4e0d\u50cf\u516c\u544a\u6216\u8bf4\u660e\u4e66\u3002\u53ea\u80fd\u4f9d\u636e\u63d0\u4f9b\u7684\u77e5\u8bc6\u56de\u7b54\uff0c\u4e0d\u8981\u8865\u884c\u4e1a\u5e38\u8bc6\u3002\u4e0d\u8981\u7f16\u9020\u4ef7\u683c\u3001\u5408\u540c\u6761\u6b3e\u3001\u65bd\u5de5\u5468\u671f\u3001\u68c0\u6d4b\u7ed3\u8bba\u3001\u5408\u4f5c\u653f\u7b56\u3001\u7edd\u5bf9\u6548\u679c\u6216\u672a\u786e\u8ba4\u53c2\u6570\u3002\u82e5\u77e5\u8bc6\u53ea\u80fd\u652f\u6301\u90e8\u5206\u7b54\u6848\uff0c\u5c31\u5148\u8bf4\u5df2\u786e\u8ba4\u7684\u90e8\u5206\uff0c\u518d\u660e\u786e\u54ea\u4e9b\u7ec6\u8282\u4ecd\u9700\u4eba\u5de5\u786e\u8ba4\u3002\u82e5\u7528\u6237\u4e00\u53e5\u8bdd\u95ee\u4e86\u591a\u4e2a\u70b9\uff0c\u8981\u5c3d\u91cf\u9010\u9879\u8986\u76d6\u3002' },
      { key: 'history', renderTypeList: ['numberInput', 'reference'], valueType: 'chatHistory', label: 'Chat History', required: true, min: 0, max: 30, value: 4 },
      { key: 'quoteQA', renderTypeList: ['settingDatasetQuotePrompt'], label: '', debugLabel: 'Dataset Quote', description: '', valueType: 'datasetQuote', value: [[datasetNodeId, 'quoteQA']] },
      { key: 'fileUrlList', renderTypeList: ['reference', 'input'], label: 'User Files', debugLabel: 'User Files', valueType: 'arrayString', value: [[startId, 'userFiles']] },
      { key: 'userChatInput', renderTypeList: ['reference', 'textarea'], valueType: 'string', label: 'User Question', required: true, toolDescription: 'user question', value: [startId, 'userChatInput'] },
      { key: 'aiChatVision', renderTypeList: ['hidden'], label: '', valueType: 'boolean', value: enableVision },
      { key: 'aiChatReasoning', renderTypeList: ['hidden'], label: '', valueType: 'boolean', value: false },
      { key: 'aiChatTopP', renderTypeList: ['hidden'], label: '', valueType: 'number', value: 0.7 },
      { key: 'aiChatStopSign', renderTypeList: ['hidden'], label: '', valueType: 'string', value: '' },
      { key: 'aiChatResponseFormat', renderTypeList: ['hidden'], label: '', valueType: 'string', value: '' },
      { key: 'aiChatJsonSchema', renderTypeList: ['hidden'], label: '', valueType: 'string', value: '' }
    ],
    outputs: [
      { id: 'history', key: 'history', required: true, label: 'New Context', description: 'Updated chat history', valueType: 'chatHistory', type: 'static' },
      { id: 'answerText', key: 'answerText', required: true, label: 'AI Response Content', description: 'Assistant answer', valueType: 'string', type: 'static' },
      { id: 'reasoningText', key: 'reasoningText', required: false, label: 'Reasoning Content', valueType: 'string', type: 'static' },
      { id: 'system_error_text', key: 'system_error_text', type: 'error', valueType: 'string', label: 'Error Text' }
    ]
  }
];

const edges = [
  { source: startId, sourceHandle: `${startId}-source-right`, target: datasetNodeId, targetHandle: `${datasetNodeId}-target-left` },
  { source: datasetNodeId, sourceHandle: `${datasetNodeId}-source-right`, target: chatNodeId, targetHandle: `${chatNodeId}-target-left` }
];

printjson(db.app_versions.updateOne(
  { _id: versionId },
  { $set: { nodes, edges, isPublish: true, time: new Date(), versionName: 'Guangxi Yiku AI Customer Service' } }
));

printjson(db.apps.updateOne(
  { _id: appId },
  {
    $set: {
      modules: nodes,
      edges,
      updateTime: new Date(),
      'chatConfig.fileSelectConfig.maxFiles': enableImageUpload ? 6 : 10,
      'chatConfig.fileSelectConfig.canSelectFile': false,
      'chatConfig.fileSelectConfig.canSelectImg': enableImageUpload,
      'chatConfig.fileSelectConfig.canSelectVideo': false,
      'chatConfig.fileSelectConfig.canSelectAudio': false,
      'chatConfig.fileSelectConfig.canSelectCustomFileExtension': false,
      'chatConfig.fileSelectConfig.customFileExtensionList': [],
      chatModels: [answerModel]
    }
  }
));
'@

$js = $js.Replace('__APP_ID__', $AppId)
$js = $js.Replace('__VERSION_ID__', $VersionId)
$js = $js.Replace('__DATASET_ID__', $DatasetId)
$js = $js.Replace('__ANSWER_MODEL__', $AnswerModel)
$js = $js.Replace('__ENABLE_VISION__', $EnableVision.ToString().ToLowerInvariant())
$js = $js.Replace('__ENABLE_IMAGE_UPLOAD__', $EnableImageUpload.ToString().ToLowerInvariant())

$js | Set-Content -LiteralPath $tmpJs -Encoding UTF8

try {
    Invoke-MongoScriptFile -LocalPath $tmpJs -ContainerName $MongoContainer -Username $MongoUser -Password $MongoPassword
} finally {
    Remove-Item -LiteralPath $tmpJs -Force -ErrorAction SilentlyContinue
}
