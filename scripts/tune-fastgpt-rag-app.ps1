param(
    [string]$AppId = "69e0562ea67193262b8de666",
    [string]$VersionId = "69e0562ea67193262b8de667",
    [string]$DatasetId = "69e03880d9b607f9459582d6",
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
      { key: 'model', renderTypeList: ['settingLLMModel', 'reference'], label: '', valueType: 'string', value: 'glm-4-flash-250414' },
      { key: 'temperature', renderTypeList: ['hidden'], label: '', value: 0.05, valueType: 'number' },
      { key: 'maxToken', renderTypeList: ['hidden'], label: '', value: 220, valueType: 'number' },
      { key: 'isResponseAnswerText', renderTypeList: ['hidden'], label: '', value: true, valueType: 'boolean' },
      { key: 'aiChatQuoteRole', renderTypeList: ['hidden'], label: '', valueType: 'string', value: 'system' },
      { key: 'quoteTemplate', renderTypeList: ['hidden'], label: '', valueType: 'string', value: '{instruction:"{{q}}",output:"{{a}}",source:"{{source}}"}' },
      { key: 'quotePrompt', renderTypeList: ['hidden'], label: '', valueType: 'string', value: 'Knowledge:`n{{quote}}`nQuestion: {{question}}`nRules: reply in Simplified Chinese; answer only from the knowledge; if only part is supported, state the confirmed part first; if evidence is insufficient, say so plainly and ask at most one short follow-up question.' },
      { key: 'systemPrompt', renderTypeList: ['textarea', 'reference'], max: 3000, valueType: 'string', label: 'System Prompt', description: 'RAG customer service prompt', placeholder: 'System prompt', value: 'You are the Guangxi Yiku customer service assistant. Reply in Simplified Chinese with direct, natural answers. Use only the provided knowledge and do not invent facts.' },
      { key: 'history', renderTypeList: ['numberInput', 'reference'], valueType: 'chatHistory', label: 'Chat History', required: true, min: 0, max: 30, value: 4 },
      { key: 'quoteQA', renderTypeList: ['settingDatasetQuotePrompt'], label: '', debugLabel: 'Dataset Quote', description: '', valueType: 'datasetQuote', value: [[datasetNodeId, 'quoteQA']] },
      { key: 'fileUrlList', renderTypeList: ['reference', 'input'], label: 'User Files', debugLabel: 'User Files', valueType: 'arrayString', value: [[startId, 'userFiles']] },
      { key: 'userChatInput', renderTypeList: ['reference', 'textarea'], valueType: 'string', label: 'User Question', required: true, toolDescription: 'user question', value: [startId, 'userChatInput'] },
      { key: 'aiChatVision', renderTypeList: ['hidden'], label: '', valueType: 'boolean', value: false },
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
  { $set: { modules: nodes, edges, updateTime: new Date() } }
));
'@

$js = $js.Replace('__APP_ID__', $AppId)
$js = $js.Replace('__VERSION_ID__', $VersionId)
$js = $js.Replace('__DATASET_ID__', $DatasetId)

$js | Set-Content -LiteralPath $tmpJs -Encoding UTF8

try {
    Invoke-MongoScriptFile -LocalPath $tmpJs -ContainerName $MongoContainer -Username $MongoUser -Password $MongoPassword
} finally {
    Remove-Item -LiteralPath $tmpJs -Force -ErrorAction SilentlyContinue
}
