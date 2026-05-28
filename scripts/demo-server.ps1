param(
    [int]$Port = 8099,
    [string]$WebRoot = ".\web-demo",
    [string]$EnvFile = ".\infra\fastgpt\.env.local",
    [string]$KnowledgeDir = ".\data\import_ready",
    [string]$ImageCatalogPath = ".\data\image_catalog\board_images.json",
    [string]$FaqCsv = ".\data\faq\gx_yiku_fastgpt_faq_curated.csv",
    [string]$PromptTemplate = ".\config\fastgpt\prompts\demo_live_system_prompt.md",
    [string]$RagPromptTemplate = ".\config\fastgpt\prompts\demo_live_rag_prompt.md",
    [string]$VisionPromptTemplate = ".\config\fastgpt\prompts\demo_vision_system_prompt.md",
    [string]$MemoryRoot = ".\data\runtime\chat_memory",
    [string]$LeadLogPath = ".\data\logs\lead_requests.jsonl",
    [string]$HandoffLogPath = ".\data\logs\handoff_requests.jsonl",
    [string]$RateLimitPath = ".\data\runtime\rate_limits.json"
)

$ErrorActionPreference = "Stop"
$script:FastGptAnswerCache = @{}
$script:PythonExe = ""
$script:SessionProfiles = @{}
$script:SessionHistories = @{}
$script:MemoryRootPath = ""

function Get-EnvMap {
    param([string]$Path)

    $map = @{}
    if (-not (Test-Path -LiteralPath $Path)) {
        return $map
    }

    foreach ($rawLine in Get-Content -LiteralPath $Path -ErrorAction Stop) {
        $line = $rawLine.Trim()
        if (-not $line -or $line.StartsWith("#")) {
            continue
        }

        $index = $line.IndexOf("=")
        if ($index -le 0) {
            continue
        }

        $key = $line.Substring(0, $index).Trim()
        $value = $line.Substring($index + 1).Trim()
        $map[$key] = $value
    }

    return $map
}

function Get-EnvValue {
    param(
        [hashtable]$EnvMap,
        [string]$Key,
        [string]$Default = ""
    )

    if ($EnvMap -and $EnvMap.ContainsKey($Key)) {
        $value = (($EnvMap[$Key] | Out-String).Trim())
        if ($value) {
            return $value
        }
    }

    return $Default
}

function Get-AllowedDirectTextModels {
    return @(
        "glm-4-flash-250414",
        "glm-5",
        "deepseek-v4-flash"
    )
}

function Get-DirectTextModel {
    param(
        [hashtable]$EnvMap,
        [string]$Override = ""
    )

    $candidate = (($Override | Out-String).Trim())
    if ($candidate -and (Get-AllowedDirectTextModels) -contains $candidate) {
        return $candidate
    }

    return Get-EnvValue -EnvMap $EnvMap -Key "DEMO_TEXT_MODEL" -Default "deepseek-chat"
}

function Get-VisionModel {
    param([hashtable]$EnvMap)

    return Get-EnvValue -EnvMap $EnvMap -Key "DEMO_VISION_MODEL" -Default "glm-4.6v-flashx"
}

function Get-ImageFlowTextModel {
    param([hashtable]$EnvMap)

    return Get-EnvValue -EnvMap $EnvMap -Key "DEMO_IMAGE_TEXT_MODEL" -Default "deepseek-chat"
}

function Get-DirectTextProviderConfig {
    param(
        [hashtable]$EnvMap,
        [string]$Override = ""
    )

    $model = Get-DirectTextModel -EnvMap $EnvMap -Override $Override
    if ($model -eq "deepseek-v4-flash") {
        $baseUrl = Get-EnvValue -EnvMap $EnvMap -Key "DEEPSEEK_BASE_URL" -Default "https://api.deepseek.com"
        $apiKey = Get-EnvValue -EnvMap $EnvMap -Key "DEEPSEEK_API_KEY" -Default ""
        return @{
            model = $model
            base_url = $baseUrl
            api_key = $apiKey
            provider = "deepseek"
        }
    }

    return @{
        model = $model
        base_url = Get-EnvValue -EnvMap $EnvMap -Key "OPENAI_BASE_URL" -Default ""
        api_key = Get-EnvValue -EnvMap $EnvMap -Key "CHAT_API_KEY" -Default ""
        provider = "default"
    }
}

function Invoke-JsonApiRequest {
    param(
        [string]$Uri,
        [hashtable]$Headers,
        [byte[]]$BodyBytes,
        [int]$TimeoutSec = 60,
        [string]$EncodingName = "utf-8"
    )

    $request = [System.Net.HttpWebRequest]::Create($Uri)
    $request.Method = "POST"
    $request.ContentType = "application/json; charset=utf-8"
    $request.Timeout = $TimeoutSec * 1000
    $request.ReadWriteTimeout = $TimeoutSec * 1000

    foreach ($key in @($Headers.Keys)) {
        $request.Headers[$key] = [string]$Headers[$key]
    }

    $requestStream = $request.GetRequestStream()
    try {
        $requestStream.Write($BodyBytes, 0, $BodyBytes.Length)
    } finally {
        $requestStream.Dispose()
    }

    $response = $null
    try {
        $response = $request.GetResponse()
        $responseStream = $response.GetResponseStream()
        $memory = New-Object System.IO.MemoryStream
        try {
            $responseStream.CopyTo($memory)
            $bytes = $memory.ToArray()
            $encoding = [System.Text.Encoding]::GetEncoding($EncodingName)
            $text = $encoding.GetString($bytes)
            return ($text | ConvertFrom-Json)
        } finally {
            $memory.Dispose()
            if ($responseStream) {
                $responseStream.Dispose()
            }
        }
    } finally {
        if ($response) {
            $response.Dispose()
        }
    }
}

function Get-TextFileContent {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return ""
    }

    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8
}

function ConvertTo-Hashtable {
    param($Value)

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [System.Collections.IDictionary]) {
        $table = @{}
        foreach ($key in $Value.Keys) {
            $table[$key] = ConvertTo-Hashtable -Value $Value[$key]
        }
        return $table
    }

    if ($Value -is [pscustomobject]) {
        $table = @{}
        foreach ($property in $Value.PSObject.Properties) {
            $table[$property.Name] = ConvertTo-Hashtable -Value $property.Value
        }
        return $table
    }

    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        $items = @()
        foreach ($item in $Value) {
            $items += ,(ConvertTo-Hashtable -Value $item)
        }
        return $items
    }

    return $Value
}

function Resolve-StorageRootPath {
    param([string]$ConfiguredPath)

    if (-not $ConfiguredPath) {
        return [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\data\runtime\chat_memory"))
    }

    if ([System.IO.Path]::IsPathRooted($ConfiguredPath)) {
        return [System.IO.Path]::GetFullPath($ConfiguredPath)
    }

    $relative = $ConfiguredPath -replace '^[.][\\/]+', ''
    return [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ("..\{0}" -f $relative)))
}

function Resolve-ProjectRelativePath {
    param([string]$ConfiguredPath)

    if (-not $ConfiguredPath) {
        return $null
    }

    if ([System.IO.Path]::IsPathRooted($ConfiguredPath)) {
        return [System.IO.Path]::GetFullPath($ConfiguredPath)
    }

    $relative = $ConfiguredPath -replace '^[.][\\/]+', ''
    return [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ("..\{0}" -f $relative)))
}

function Get-TempStatePath {
    param([string]$FileName)

    $tempDir = Join-Path $PSScriptRoot "..\tmp"
    if (-not (Test-Path -LiteralPath $tempDir)) {
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    }

    return (Join-Path $tempDir $FileName)
}

function Read-JsonHashtableFile {
    param(
        [string]$Path,
        [string]$RootKey
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return @{}
    }

    try {
        $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        if (-not $raw.Trim()) {
            return @{}
        }

        $parsed = ConvertTo-Hashtable -Value ($raw | ConvertFrom-Json)
        if ($RootKey -and $parsed.ContainsKey($RootKey)) {
            return ConvertTo-Hashtable -Value $parsed[$RootKey]
        }
        return $parsed
    } catch {
        return @{}
    }
}

function Write-JsonHashtableFile {
    param(
        [string]$Path,
        [string]$RootKey,
        $Data
    )

    $payload = if ($RootKey) {
        [ordered]@{ $RootKey = $Data }
    } else {
        $Data
    }

    $json = $payload | ConvertTo-Json -Depth 12
    [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
}

function Get-StringHash {
    param([string]$Text)

    $value = if ($Text) { $Text } else { "" }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($value)
    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $algorithm.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($hash)).Replace("-", "").ToLowerInvariant()
    } finally {
        $algorithm.Dispose()
    }
}

function Get-SafeStorageSegment {
    param(
        [string]$Value,
        [string]$Prefix = "item"
    )

    $trimmed = if ($Value) { (($Value | Out-String).Trim().ToLowerInvariant()) } else { "" }
    $slug = ($trimmed -replace "[^a-z0-9_-]+", "_").Trim("_")
    if (-not $slug) {
        $slug = $Prefix
    }
    if ($slug.Length -gt 32) {
        $slug = $slug.Substring(0, 32).Trim("_")
    }

    $hash = Get-StringHash -Text $trimmed
    return "{0}_{1}" -f $slug, $hash.Substring(0, 12)
}

function Get-UserMemoryDirectory {
    param(
        [string]$Channel,
        [string]$ExternalUserId
    )

    $channelSegment = Get-SafeStorageSegment -Value $Channel -Prefix "channel"
    $userSegment = Get-SafeStorageSegment -Value $ExternalUserId -Prefix "user"
    $channelDir = Join-Path $script:MemoryRootPath $channelSegment
    $userDir = Join-Path $channelDir $userSegment
    if (-not (Test-Path -LiteralPath $userDir)) {
        New-Item -ItemType Directory -Path $userDir -Force | Out-Null
    }
    return $userDir
}

function Get-UserProfilePath {
    param(
        [string]$Channel,
        [string]$ExternalUserId
    )

    return (Join-Path (Get-UserMemoryDirectory -Channel $Channel -ExternalUserId $ExternalUserId) "profile.json")
}

function Get-ConversationMemoryPath {
    param(
        [string]$Channel,
        [string]$ExternalUserId,
        [string]$ConversationId
    )

    $conversationDir = Join-Path (Get-UserMemoryDirectory -Channel $Channel -ExternalUserId $ExternalUserId) "conversations"
    if (-not (Test-Path -LiteralPath $conversationDir)) {
        New-Item -ItemType Directory -Path $conversationDir -Force | Out-Null
    }

    $conversationSegment = Get-SafeStorageSegment -Value $ConversationId -Prefix "conversation"
    return (Join-Path $conversationDir ($conversationSegment + ".json"))
}

function Get-DefaultUserProfile {
    param(
        [string]$Channel,
        [string]$ExternalUserId
    )

    return [ordered]@{
        channel = $Channel
        external_user_id = $ExternalUserId
        customer_type = ""
        last_active_at = ""
        intent_primary = ""
        scene = ""
        room_type = ""
        usage_area = ""
        noise_source_guess = ""
        care_points = @()
        preferred_board_types = @()
        preferred_attributes = @()
        recent_questions = @()
        budget_level = ""
        stage = ""
        image_interest = "normal"
        handoff_readiness = "low"
        summary = ""
        summary_updated_at = ""
    }
}

function Get-DefaultConversationState {
    param(
        [string]$Channel,
        [string]$ExternalUserId,
        [string]$ConversationId,
        [string]$SessionId
    )

    return [ordered]@{
        channel = $Channel
        external_user_id = $ExternalUserId
        conversation_id = $ConversationId
        session_id = $SessionId
        fastgpt_chat_id = "demo-" + [guid]::NewGuid().ToString("N").Substring(0, 16)
        last_active_at = ""
        current_topic = ""
        current_goal = ""
        current_board_type = ""
        last_answer = ""
        summary = ""
        turns = @()
    }
}

function Merge-HashtableDefaults {
    param(
        $Record,
        $Defaults
    )

    if (-not $Record) {
        $Record = @{}
    }

    foreach ($key in $Defaults.Keys) {
        if (-not (Test-MapContainsKey -Map $Record -Key $key) -or $null -eq $Record[$key]) {
            $Record[$key] = ConvertTo-Hashtable -Value $Defaults[$key]
        }
    }

    return $Record
}

function Normalize-UserProfile {
    param(
        [hashtable]$Record,
        [string]$Channel,
        [string]$ExternalUserId
    )

    $profile = Merge-HashtableDefaults -Record $Record -Defaults (Get-DefaultUserProfile -Channel $Channel -ExternalUserId $ExternalUserId)
    $profile.care_points = @($profile.care_points)
    $profile.preferred_board_types = @($profile.preferred_board_types)
    $profile.preferred_attributes = @($profile.preferred_attributes)
    $profile.recent_questions = @($profile.recent_questions)
    return $profile
}

function Normalize-ConversationState {
    param(
        [hashtable]$Record,
        [string]$Channel,
        [string]$ExternalUserId,
        [string]$ConversationId,
        [string]$SessionId
    )

    $state = Merge-HashtableDefaults -Record $Record -Defaults (Get-DefaultConversationState -Channel $Channel -ExternalUserId $ExternalUserId -ConversationId $ConversationId -SessionId $SessionId)
    $state.turns = @($state.turns)
    if ($SessionId) {
        $state.session_id = $SessionId
    }
    return $state
}

function Initialize-SessionStores {
    $script:MemoryRootPath = Resolve-StorageRootPath -ConfiguredPath $MemoryRoot
    if (-not (Test-Path -LiteralPath $script:MemoryRootPath)) {
        New-Item -ItemType Directory -Path $script:MemoryRootPath -Force | Out-Null
    }

    $script:SessionProfiles = @{}
    $script:SessionHistories = @{}
}

function Save-UserProfileDocument {
    param($Profile)

    if (-not $Profile) {
        return
    }

    $path = Get-UserProfilePath -Channel $Profile.channel -ExternalUserId $Profile.external_user_id
    Write-JsonHashtableFile -Path $path -RootKey "" -Data $Profile
}

function Save-ConversationStateDocument {
    param($ConversationState)

    if (-not $ConversationState) {
        return
    }

    $path = Get-ConversationMemoryPath -Channel $ConversationState.channel -ExternalUserId $ConversationState.external_user_id -ConversationId $ConversationState.conversation_id
    Write-JsonHashtableFile -Path $path -RootKey "" -Data $ConversationState
}

function Save-SessionStores {
    if ($script:SkipPersistence) {
        return
    }

    foreach ($item in @($script:SessionProfiles.GetEnumerator())) {
        Save-UserProfileDocument -Profile $item.Value
    }

    foreach ($item in @($script:SessionHistories.GetEnumerator())) {
        Save-ConversationStateDocument -ConversationState $item.Value
    }
}

function Get-AdminRuntimeConfigResponse {
    param([hashtable]$EnvMap)

    return [ordered]@{
        online_only = $true
        chat_backend = Get-ChatBackendMode -EnvMap $EnvMap
        guided_answer_enabled = Test-GuidedAnswerEnabled -EnvMap $EnvMap
        deepseek_text_enabled = [bool](Get-EnvValue -EnvMap $EnvMap -Key "DEEPSEEK_API_KEY" -Default "")
        updated_at = ""
    }
}

function Get-NowIsoString {
    return [DateTime]::UtcNow.ToString("o")
}

function Ensure-ParentDirectory {
    param([string]$Path)

    if (-not $Path) {
        return
    }

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
}

function New-RequestCaptureResponse {
    param(
        [string]$Kind,
        [hashtable]$Payload,
        [string]$LogPath
    )

    $requestId = "{0}-{1}" -f $Kind, ([guid]::NewGuid().ToString("N"))
    $capturedAt = Get-NowIsoString
    $record = [ordered]@{
        request_id = $requestId
        kind = $Kind
        captured_at = $capturedAt
        payload = if ($Payload) { $Payload } else { @{} }
    }

    Ensure-ParentDirectory -Path $LogPath
    (($record | ConvertTo-Json -Depth 8 -Compress) + [Environment]::NewLine) | Add-Content -LiteralPath $LogPath -Encoding UTF8

    return [ordered]@{
        status = "queued"
        message = if ($Kind -eq "lead") { "Lead request has been captured." } else { "Handoff request has been captured." }
        request_id = $requestId
        captured_at = $capturedAt
    }
}

function New-TrimmedText {
    param(
        [string]$Text,
        [int]$MaxLength = 160
    )

    if (-not $Text) {
        return ""
    }

    $normalized = (($Text | Out-String).Trim()) -replace "\s+", " "
    if ($normalized.Length -le $MaxLength) {
        return $normalized
    }

    return $normalized.Substring(0, $MaxLength) + "..."
}

function Add-UniqueString {
    param(
        [object]$Items,
        [string]$Value,
        [int]$MaxItems = 6
    )

    $list = New-Object System.Collections.Generic.List[string]
    foreach ($item in @($Items)) {
        $text = (($item | Out-String).Trim())
        if ($text -and -not $list.Contains($text)) {
            $list.Add($text)
        }
    }

    $candidate = (($Value | Out-String).Trim())
    if ($candidate -and -not $list.Contains($candidate)) {
        $list.Add($candidate)
    }

    while ($list.Count -gt $MaxItems) {
        $list.RemoveAt(0)
    }

    return @($list.ToArray())
}

function Test-MapContainsKey {
    param(
        $Map,
        [string]$Key
    )

    if ($null -eq $Map -or -not $Key) {
        return $false
    }

    if ($Map -is [System.Collections.IDictionary]) {
        return $Map.Contains($Key)
    }

    return $null -ne $Map.PSObject.Properties[$Key]
}

function Get-ChannelProfileKey {
    param(
        [string]$Channel,
        [string]$ExternalUserId
    )

    return (($Channel | Out-String).Trim().ToLowerInvariant()) + "::" + (($ExternalUserId | Out-String).Trim().ToLowerInvariant())
}

function Get-ConversationStoreKey {
    param(
        [string]$Channel,
        [string]$ExternalUserId,
        [string]$ConversationId
    )

    return (($Channel | Out-String).Trim().ToLowerInvariant()) + "::" + (($ExternalUserId | Out-String).Trim().ToLowerInvariant()) + "::" + (($ConversationId | Out-String).Trim().ToLowerInvariant())
}

function Get-BoardTypeFromText {
    param([string]$Text)

    if (-not $Text) {
        return ""
    }

    if ($Text -match "隔音板|隔音|吸音板|吸音|午睡|睡觉|车流|噪音|噪声") {
        return "soundproof_board"
    }
    if ($Text -match "防火板|防火|耐火") {
        return "fireproof_board"
    }
    if ($Text -match "背景墙板|背景墙|墙板") {
        return "background_wall_board"
    }
    if ($Text -match "菜板|砧板|案板") {
        return "cutting_board"
    }

    return ""
}

function Get-BoardTypeInfo {
    param([string]$BoardType)

    switch ($BoardType) {
        "soundproof_board" {
            return @{
                id = "soundproof_board"
                title = "隔音板"
                caption = "隔音板，适合卧室、午休或车流噪声干扰场景，偏隔音。"
            }
        }
        "fireproof_board" {
            return @{
                id = "fireproof_board"
                title = "防火板"
                caption = "防火板，更适合对耐火和安全性有要求的空间，重点不是隔音。"
            }
        }
        "background_wall_board" {
            return @{
                id = "background_wall_board"
                title = "背景墙板"
                caption = "背景墙板更偏装饰和空间呈现，不适合作为隔音主方案。"
            }
        }
        "cutting_board" {
            return @{
                id = "cutting_board"
                title = "菜板"
                caption = "这类样板更偏材质展示，不是卧室隔音推荐主项。"
            }
        }
        default {
            return @{
                id = ""
                title = ""
                caption = ""
            }
        }
    }
}

function Get-Or-CreateUserProfile {
    param(
        [string]$Channel,
        [string]$ExternalUserId
    )

    $key = Get-ChannelProfileKey -Channel $Channel -ExternalUserId $ExternalUserId
    if (-not $script:SessionProfiles.ContainsKey($key)) {
        if ($script:SkipPersistence) {
            $script:SessionProfiles[$key] = Normalize-UserProfile -Record $null -Channel $Channel -ExternalUserId $ExternalUserId
        } else {
            $path = Get-UserProfilePath -Channel $Channel -ExternalUserId $ExternalUserId
            $record = Read-JsonHashtableFile -Path $path -RootKey ""
            $script:SessionProfiles[$key] = Normalize-UserProfile -Record $record -Channel $Channel -ExternalUserId $ExternalUserId
        }
    }

    return $script:SessionProfiles[$key]
}

function Get-Or-CreateConversationState {
    param(
        [string]$Channel,
        [string]$ExternalUserId,
        [string]$ConversationId,
        [string]$SessionId
    )

    $key = Get-ConversationStoreKey -Channel $Channel -ExternalUserId $ExternalUserId -ConversationId $ConversationId
    if (-not $script:SessionHistories.ContainsKey($key)) {
        if ($script:SkipPersistence) {
            $script:SessionHistories[$key] = Normalize-ConversationState -Record $null -Channel $Channel -ExternalUserId $ExternalUserId -ConversationId $ConversationId -SessionId $SessionId
        } else {
            $path = Get-ConversationMemoryPath -Channel $Channel -ExternalUserId $ExternalUserId -ConversationId $ConversationId
            $record = Read-JsonHashtableFile -Path $path -RootKey ""
            $script:SessionHistories[$key] = Normalize-ConversationState -Record $record -Channel $Channel -ExternalUserId $ExternalUserId -ConversationId $ConversationId -SessionId $SessionId
        }
    }
    return $script:SessionHistories[$key]
}

function Get-PrimaryIntentFromQuestion {
    param(
        [string]$Question,
        $UserProfile
    )

    if ($Question -match "车流|噪音|噪声|吵醒|午睡|睡觉|隔音板|隔音|吸音板|吸音") {
        return "sound_insulation"
    }
    if ($Question -match "甲醛|异味|味道|环保|除醛|除味|空气") {
        return "environment"
    }
    if ($Question -match "图片|参考图|实拍图|照片|发图|看图") {
        return "image_request"
    }
    if ($Question -match "公司|地址|哪里|在哪|企业") {
        return "company_profile"
    }
    if ($Question -match "价格|报价|多少钱|施工|合作|联系方式") {
        return "commercial_followup"
    }
    if ($UserProfile -and $UserProfile.intent_primary) {
        return $UserProfile.intent_primary
    }

    return ""
}

function Update-UserProfile {
    param(
        $UserProfile,
        [string]$Question,
        [string]$Answer,
        [bool]$HasImage
    )

    if (-not $UserProfile) {
        return
    }

    $UserProfile.last_active_at = Get-NowIsoString
    $intent = Get-PrimaryIntentFromQuestion -Question $Question -UserProfile $UserProfile
    if ($intent) {
        $UserProfile.intent_primary = $intent
    }

    if ($Question -match "新房|装修|家装|入住") {
        $UserProfile.scene = "新房装修"
        $UserProfile.stage = if ($Question -match "准备装修|最近装修") { "准备装修" } else { "装修/入住阶段" }
    }

    if ($Question -match "家装|新房|儿童房|卧室|客厅|背景墙") {
        $UserProfile.customer_type = "家装客户"
    } elseif ($Question -match "工装|酒店|学校|医院|办公室|展厅|门店|商场|项目") {
        $UserProfile.customer_type = "工装客户"
    }

    if ($Question -match "卧室|午睡|睡觉") {
        $UserProfile.room_type = "卧室/午休"
    }

    if ($Question -match "墙面|墙板|背景墙") {
        $UserProfile.usage_area = "墙面/背景墙"
    } elseif ($Question -match "柜体|橱柜|柜门|柜子") {
        $UserProfile.usage_area = "柜体/柜门"
    } elseif ($Question -match "吊顶|顶面") {
        $UserProfile.usage_area = "顶面"
    }

    if ($Question -match "车流|马路|路边|街边") {
        $UserProfile.noise_source_guess = "外部交通噪声"
    }

    if ($Question -match "预算|便宜|贵|多少钱") {
        $UserProfile.budget_level = "待确认"
    }

    if ($HasImage -or $Question -match "图片|参考图|实拍图|照片|发图|看图") {
        $UserProfile.image_interest = "high"
    }

    if ($Question -match "价格|报价|施工|联系方式|电话|微信|怎么联系") {
        $UserProfile.handoff_readiness = "high"
    } elseif ($Question -match "方案|合作|城市|面积") {
        $UserProfile.handoff_readiness = "medium"
    }

    if ($Question -match "午睡|睡觉|安静") {
        $UserProfile.care_points = Add-UniqueString -Items $UserProfile.care_points -Value "午睡安静"
    }
    if ($Question -match "板材|推荐|哪种") {
        $UserProfile.care_points = Add-UniqueString -Items $UserProfile.care_points -Value "板材推荐"
    }
    if ($Question -match "效果|能不能|有没有用|隔音") {
        $UserProfile.care_points = Add-UniqueString -Items $UserProfile.care_points -Value "效果边界"
    }
    if ($Question -match "甲醛|异味|味道|环保") {
        $UserProfile.care_points = Add-UniqueString -Items $UserProfile.care_points -Value "环保和味道"
    }
    if ($Question -match "防火|阻燃|耐火") {
        $UserProfile.care_points = Add-UniqueString -Items $UserProfile.care_points -Value "防火等级"
    }
    if ($Question -match "防潮|潮湿|发霉|梅雨") {
        $UserProfile.care_points = Add-UniqueString -Items $UserProfile.care_points -Value "防潮稳定性"
    }
    if ($Question -match "柜体|橱柜|做柜子") {
        $UserProfile.care_points = Add-UniqueString -Items $UserProfile.care_points -Value "柜体适配"
    }

    $boardType = Get-BoardTypeFromText -Text ($Question + "`n" + $Answer)
    if ($boardType) {
        $boardInfo = Get-BoardTypeInfo -BoardType $boardType
        if ($boardInfo.title) {
            $UserProfile.preferred_board_types = Add-UniqueString -Items $UserProfile.preferred_board_types -Value $boardInfo.title
        }
    }

    if ($Question -match "环保|甲醛|异味|味道") {
        $UserProfile.preferred_attributes = Add-UniqueString -Items $UserProfile.preferred_attributes -Value "环保优先"
    }
    if ($Question -match "防火|阻燃|耐火") {
        $UserProfile.preferred_attributes = Add-UniqueString -Items $UserProfile.preferred_attributes -Value "防火优先"
    }
    if ($Question -match "防潮|潮湿|发霉") {
        $UserProfile.preferred_attributes = Add-UniqueString -Items $UserProfile.preferred_attributes -Value "防潮优先"
    }
    if ($Question -match "隔音|噪音|噪声|睡觉|午睡") {
        $UserProfile.preferred_attributes = Add-UniqueString -Items $UserProfile.preferred_attributes -Value "隔音优先"
    }
    if ($Question -match "好看|颜值|背景墙|风格|颜色") {
        $UserProfile.preferred_attributes = Add-UniqueString -Items $UserProfile.preferred_attributes -Value "装饰效果"
    }
    if ($Question) {
        $UserProfile.recent_questions = Add-UniqueString -Items $UserProfile.recent_questions -Value (New-TrimmedText -Text $Question -MaxLength 60) -MaxItems 4
    }

    $summaryParts = New-Object System.Collections.Generic.List[string]
    if ($UserProfile.customer_type) { $summaryParts.Add("客户类型：$($UserProfile.customer_type)") }
    if ($UserProfile.scene) { $summaryParts.Add("场景：$($UserProfile.scene)") }
    if ($UserProfile.room_type) { $summaryParts.Add("空间：$($UserProfile.room_type)") }
    if ($UserProfile.usage_area) { $summaryParts.Add("用途：$($UserProfile.usage_area)") }
    if ($UserProfile.intent_primary) { $summaryParts.Add("主意图：$($UserProfile.intent_primary)") }
    if ($UserProfile.noise_source_guess) { $summaryParts.Add("噪声来源：$($UserProfile.noise_source_guess)") }
    if ($UserProfile.care_points.Count -gt 0) { $summaryParts.Add("关注点：" + ($UserProfile.care_points -join "、")) }
    if ($UserProfile.preferred_board_types.Count -gt 0) { $summaryParts.Add("偏好板材：" + ($UserProfile.preferred_board_types -join "、")) }
    if ($UserProfile.preferred_attributes.Count -gt 0) { $summaryParts.Add("偏好侧重：" + ($UserProfile.preferred_attributes -join "、")) }
    if ($UserProfile.recent_questions.Count -gt 0) { $summaryParts.Add("最近问过：" + ($UserProfile.recent_questions -join "；")) }
    $UserProfile.summary = $summaryParts -join "；"
    $UserProfile.summary_updated_at = Get-NowIsoString
}

function Update-ConversationMemory {
    param(
        $ConversationState,
        [string]$Question,
        [string]$Answer,
        [bool]$HasImage
    )

    if (-not $ConversationState) {
        return
    }

    $ConversationState.last_active_at = Get-NowIsoString

    $topic = ""
    if ($Question) {
        $topic = Get-PrimaryIntentFromQuestion -Question $Question -UserProfile $null
    }
    if ($topic) {
        $ConversationState.current_topic = $topic
    }

    $boardType = Get-BoardTypeFromText -Text ($Question + "`n" + $Answer)
    if ($boardType) {
        $ConversationState.current_board_type = $boardType
    }

    if ($Question) {
        $ConversationState.current_goal = New-TrimmedText -Text $Question -MaxLength 80
        $ConversationState.turns += @(
            [ordered]@{
                role = "user"
                text = New-TrimmedText -Text $Question -MaxLength 200
                has_image = $HasImage
            }
        )
    }

    if ($Answer) {
        $ConversationState.last_answer = New-TrimmedText -Text $Answer -MaxLength 160
        $ConversationState.turns += @(
            [ordered]@{
                role = "assistant"
                text = New-TrimmedText -Text $Answer -MaxLength 240
                has_image = $false
            }
        )
    }

    if ($ConversationState.turns.Count -gt 12) {
        $ConversationState.turns = @($ConversationState.turns | Select-Object -Last 12)
    }

    $summaryParts = New-Object System.Collections.Generic.List[string]
    if ($ConversationState.current_topic) { $summaryParts.Add("当前主题：$($ConversationState.current_topic)") }
    if ($ConversationState.current_goal) { $summaryParts.Add("本轮目标：$($ConversationState.current_goal)") }
    if ($ConversationState.current_board_type) {
        $boardInfo = Get-BoardTypeInfo -BoardType $ConversationState.current_board_type
        if ($boardInfo.title) {
            $summaryParts.Add("当前板材：$($boardInfo.title)")
        }
    }
    if ($ConversationState.last_answer) { $summaryParts.Add("上一轮结论：$($ConversationState.last_answer)") }

    $recentUserTurns = @($ConversationState.turns | Where-Object { $_.role -eq "user" } | Select-Object -Last 2 | ForEach-Object { $_.text })
    if ($recentUserTurns.Count -gt 0) {
        $summaryParts.Add("最近追问：" + ($recentUserTurns -join "；"))
    }

    $ConversationState.summary = $summaryParts -join "；"
}

function Build-ContextBundle {
    param(
        [string]$Channel,
        [string]$ExternalUserId,
        [string]$ConversationId,
        [string]$Question
    )

    $profile = Get-Or-CreateUserProfile -Channel $Channel -ExternalUserId $ExternalUserId
    $conversationState = Get-Or-CreateConversationState -Channel $Channel -ExternalUserId $ExternalUserId -ConversationId $ConversationId -SessionId ""
    $intent = Get-PrimaryIntentFromQuestion -Question $Question -UserProfile $profile
    $mustInclude = New-Object System.Collections.Generic.List[string]
    $mustAvoid = New-Object System.Collections.Generic.List[string]

    if ($intent -eq "sound_insulation" -or $conversationState.current_topic -eq "sound_insulation") {
        $mustInclude.Add("先复述用户被车流或噪声打扰的场景，再给结论。")
        $mustInclude.Add("明确区分吸音和隔音。")
        $mustInclude.Add("说明卧室降噪优先级通常是窗、门缝、墙面板材。")
        $mustAvoid.Add("不要把问题转成环保宣传或品牌介绍。")
        $mustAvoid.Add("不要承诺单层装饰板就能彻底解决低频车流噪声。")
    }

    if ($intent -eq "image_request") {
        $mustInclude.Add("说明图片是同款、相似款还是示意图。")
        $mustAvoid.Add("没有图片时不要写参考图占位内容。")
    }

    $recentTurns = @($conversationState.turns | Select-Object -Last 6 | ForEach-Object {
        if ($_.role -eq "user") {
            "用户：" + $_.text
        } else {
            "客服：" + $_.text
        }
    })

    $bundleLines = New-Object System.Collections.Generic.List[string]
    $bundleLines.Add("渠道：$Channel")
    if ($profile.summary) { $bundleLines.Add("用户长期记忆：$($profile.summary)") }
    if ($conversationState.summary) { $bundleLines.Add("最近会话摘要：$($conversationState.summary)") }
    if ($conversationState.current_board_type) {
        $boardInfo = Get-BoardTypeInfo -BoardType $conversationState.current_board_type
        if ($boardInfo.title) {
            $bundleLines.Add("当前板材上下文：$($boardInfo.title)")
        }
    }
    if ($mustInclude.Count -gt 0) { $bundleLines.Add("回答必须包含：" + ($mustInclude -join "；")) }
    if ($mustAvoid.Count -gt 0) { $bundleLines.Add("回答必须避免：" + ($mustAvoid -join "；")) }
    if ($recentTurns.Count -gt 0) { $bundleLines.Add("最近上下文：`n" + ($recentTurns -join "`n")) }

    return @{
        text = ($bundleLines -join "`n")
        intent = $intent
        profile = $profile
        conversation = $conversationState
    }
}

function Build-GroundedUserPrompt {
    param(
        [string]$Question,
        [string]$ContextBundleText,
        [string]$KnowledgeText,
        [string]$RagPromptTemplateText = "",
        [string]$ImageSummary = ""
    )

    $questionText = if ($Question) {
        $Question
    } else {
        "请先总结图片里能明确看到的内容，再回答用户问题。"
    }

    $contextText = if ($ContextBundleText) {
        $ContextBundleText
    } else {
        "暂无可用的用户记忆。"
    }

    $knowledge = if ($KnowledgeText) {
        $KnowledgeText
    } else {
        "- 当前未检索到足够相关的知识事实，优先明确目前能确认到哪里。"
    }

    $imageText = if ($ImageSummary) {
        $ImageSummary
    } else {
        "无"
    }

    if ($RagPromptTemplateText) {
        return $RagPromptTemplateText.Replace("{MEMORY_CONTEXT}", $contextText).Replace("{KNOWLEDGE_SNIPPETS}", $knowledge).Replace("{QUESTION}", $questionText).Replace("{IMAGE_SUMMARY}", $imageText)
    }

    $promptParts = New-Object System.Collections.Generic.List[string]
    $promptParts.Add("用户记忆与最近会话：`n$contextText")
    $promptParts.Add("本轮知识库检索片段（优先依据，用自己的话自然回答，不要逐字照搬）：`n$knowledge")
    if ($ImageSummary) {
        $promptParts.Add("图片识别要点：`n$ImageSummary")
    }
    $promptParts.Add("当前用户问题：$questionText")
    $promptParts.Add("请直接回答用户原问题，像人在微信里回复一样自然。不要先自我介绍，不要重复公司全名，不要把问题改写成类似 您是想了解什么吗 这种客服追问。先给结论，再补少量依据；简单问题优先控制在 2 到 5 句。")
    return ($promptParts.ToArray() -join "`n`n")
}

function Build-ChannelResponse {
    param(
        [string]$Channel,
        $RawResult
    )

    $displayText = if ((Test-MapContainsKey -Map $RawResult -Key "display_text") -and $RawResult.display_text) {
        $RawResult.display_text
    } else {
        $RawResult.answer
    }

    $assets = @()
    if ((Test-MapContainsKey -Map $RawResult -Key "assets") -and $RawResult.assets) {
        $assets = @($RawResult.assets)
    }

    $channelPayload = if ($Channel -eq "wechat_mp") {
        $imageUrls = @($assets | ForEach-Object { $_.url } | Where-Object { $_ })
        $articles = @($assets | ForEach-Object {
            [ordered]@{
                title = if ($_.alt) { $_.alt } else { "参考图" }
                description = if ($_.caption) { $_.caption } else { $displayText }
                picUrl = $_.url
                url = $_.url
            }
        })

        [ordered]@{
            messageType = if ($articles.Count -gt 0) { "image_text" } else { "text" }
            text = $displayText
            imageUrls = $imageUrls
            articles = $articles
        }
    } else {
        [ordered]@{
            messageType = if ($assets.Count -gt 0) { "rich_text" } else { "text" }
            displayText = $displayText
            assets = $assets
        }
    }

    $response = [ordered]@{
        answer = $displayText
        mode = $RawResult.mode
        channel = $Channel
        channelPayload = $channelPayload
    }

    foreach ($key in @("asset_status", "asset_type", "caption", "handoff", "backend_model")) {
        if (Test-MapContainsKey -Map $RawResult -Key $key) {
            $response[$key] = $RawResult[$key]
        }
    }

    return $response
}

function Get-FastGptCacheKey {
    param(
        [string]$Question,
        [string]$Scope = ""
    )

    if (-not $Question) {
        return ""
    }

    $normalized = (($Question | Out-String).Trim()).ToLowerInvariant() -replace "[\s\p{P}\p{S}]+", ""
    if (-not $Scope) {
        return $normalized
    }

    return (($Scope | Out-String).Trim().ToLowerInvariant()) + "::" + $normalized
}

function Get-CachedFastGptAnswer {
    param(
        [string]$Question,
        [string]$Scope = ""
    )

    $key = Get-FastGptCacheKey -Question $Question -Scope $Scope
    if (-not $key) {
        return $null
    }

    if ($script:FastGptAnswerCache.ContainsKey($key)) {
        return $script:FastGptAnswerCache[$key]
    }

    return $null
}

function Set-CachedFastGptAnswer {
    param(
        [string]$Question,
        [string]$Answer,
        [string]$Scope = ""
    )

    $key = Get-FastGptCacheKey -Question $Question -Scope $Scope
    if (-not $key -or -not $Answer) {
        return
    }

    $script:FastGptAnswerCache[$key] = $Answer.Trim()
}

function Test-IsChineseText {
    param([string]$Text)

    return $Text -match "[\u4e00-\u9fff]"
}

function Test-IsLowQualityAnswer {
    param([string]$Text)

    if (-not $Text) {
        return $true
    }

    $trimmed = $Text.Trim()
    if (-not $trimmed) {
        return $true
    }

    $questionMarks = ([regex]::Matches($trimmed, "[\?\uFF1F]")).Count
    $cjkChars = ([regex]::Matches($trimmed, "[\u4e00-\u9fff]")).Count
    $latinChars = ([regex]::Matches($trimmed, "[A-Za-z]")).Count

    if ($questionMarks -ge 4 -and ($cjkChars + $latinChars) -le 2) {
        return $true
    }

    if ($trimmed -match "^\s*[\?\uFF1F\|\-:;,.\\/]+\s*$") {
        return $true
    }

    return $false
}

function Get-FaqEntries {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return @()
    }

    try {
        $csvText = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        return @($csvText | ConvertFrom-Csv)
    } catch {
        return @()
    }
}

function Get-ImageCatalogEntries {
    param([string]$Path)

    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) {
        return @()
    }

    try {
        $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        return @($raw | ConvertFrom-Json)
    } catch {
        return @()
    }
}

function Get-LocalStorageEndpoint {
    param([hashtable]$EnvMap)

    $port = if ($EnvMap -and $EnvMap["MINIO_PORT"]) {
        $EnvMap["MINIO_PORT"]
    } else {
        "9100"
    }

    return "http://127.0.0.1:$port"
}

function Get-ProxiedCatalogImageUrl {
    param([string]$OriginalUrl)

    if (-not $OriginalUrl) {
        return $null
    }

    try {
        $uri = [System.Uri]$OriginalUrl
        $objectPath = $uri.AbsolutePath.TrimStart("/")
        if (-not $objectPath) {
            return $OriginalUrl
        }

        return "/api/media?path=$([System.Uri]::EscapeDataString($objectPath))"
    } catch {
        return $OriginalUrl
    }
}

function Get-QueryParameterValue {
    param(
        [string]$QueryString,
        [string]$Name
    )

    if (-not $QueryString -or -not $Name) {
        return $null
    }

    $trimmedQuery = $QueryString.TrimStart("?")
    foreach ($pair in ($trimmedQuery -split "&")) {
        if (-not $pair) {
            continue
        }

        $key, $value = ($pair -split "=", 2)
        if ($key -ne $Name) {
            continue
        }

        $safeValue = if ($null -ne $value) { $value } else { "" }
        return [System.Uri]::UnescapeDataString($safeValue.Replace("+", "%20"))
    }

    return $null
}

function Read-RemoteBinaryResponse {
    param([string]$Url)

    $request = [System.Net.HttpWebRequest]::Create($Url)
    $request.Method = "GET"
    $request.Timeout = 15000
    $request.ReadWriteTimeout = 15000

    $response = $request.GetResponse()
    try {
        $memory = New-Object System.IO.MemoryStream
        try {
            $responseStream = $response.GetResponseStream()
            try {
                $responseStream.CopyTo($memory)
            } finally {
                $responseStream.Dispose()
            }
        } finally {
            $memory.Position = 0
        }

        $contentType = $response.ContentType
        if (-not $contentType) {
            $contentType = "application/octet-stream"
        }

        return @{
            Bytes = $memory.ToArray()
            ContentType = $contentType
        }
    } finally {
        $response.Dispose()
    }
}

function Get-ProxiedMediaResponse {
    param(
        [string]$RequestPath,
        [hashtable]$EnvMap
    )

    if (-not $RequestPath.StartsWith("/api/media?", [System.StringComparison]::OrdinalIgnoreCase)) {
        return $null
    }

    try {
        $requestUri = [System.Uri]("http://localhost" + $RequestPath)
        $objectPath = Get-QueryParameterValue -QueryString $requestUri.Query -Name "path"
        if (-not $objectPath) {
            return @{
                StatusCode = 404
                ContentType = "text/plain; charset=utf-8"
                Text = "Missing media path"
            }
        }

        $trimmedPath = $objectPath.TrimStart("/")
        $targetUrl = (Get-LocalStorageEndpoint -EnvMap $EnvMap).TrimEnd("/") + "/" + $trimmedPath
        $remote = Read-RemoteBinaryResponse -Url $targetUrl
        return @{
            StatusCode = 200
            ContentType = $remote.ContentType
            Bytes = $remote.Bytes
        }
    } catch {
        return @{
            StatusCode = 404
            ContentType = "text/plain; charset=utf-8"
            Text = "Media not found"
        }
    }
}

function Test-IsBoardImageRequest {
    param([string]$Question)

    if (-not $Question) {
        return $false
    }

    return $Question -match "样板|样品|参考图|实拍|照片|图片|发图|看看图|看下图|看图|图给我|图发我|发几张|发一下图|发一下照片"
}

function Test-IsGenericImageFollowup {
    param([string]$Question)

    if (-not $Question) {
        return $false
    }

    return $Question -match "这款|这张|这个|有图吗|参考图吗|实拍图吗|有实拍吗|发我看看|给我看看"
}

function Get-MatchedBoardImageEntries {
    param(
        [string]$Question,
        [object[]]$ImageCatalogEntries,
        $ConversationState
    )

    if (-not $ImageCatalogEntries -or $ImageCatalogEntries.Count -eq 0) {
        return @()
    }

    if (-not $Question) {
        return @()
    }

    $contextBoardType = if ($ConversationState -and $ConversationState.current_board_type) {
        $ConversationState.current_board_type
    } else {
        Get-BoardTypeFromText -Text $Question
    }

    $matched = New-Object System.Collections.Generic.List[object]
    foreach ($entry in $ImageCatalogEntries) {
        $aliases = @()
        if ($entry.aliases) {
            $aliases = @($entry.aliases)
        }
        $candidates = @($entry.title, $entry.id, $entry.source_file) + $aliases

        foreach ($alias in $candidates) {
            $aliasText = (($alias | Out-String).Trim())
            if (-not $aliasText) {
                continue
            }

            if ($Question -match [regex]::Escape($aliasText)) {
                $matched.Add($entry)
                break
            }
        }
    }

    if ($matched.Count -gt 0) {
        return @($matched.ToArray())
    }

    if ($contextBoardType -and (Test-IsGenericImageFollowup -Question $Question)) {
        $boardInfo = Get-BoardTypeInfo -BoardType $contextBoardType
        foreach ($entry in $ImageCatalogEntries) {
            if ((($entry.id | Out-String).Trim()) -eq $contextBoardType -or (($entry.title | Out-String).Trim()) -eq $boardInfo.title) {
                return @($entry)
            }
        }
    }

    $wantsAll = $Question -match "都发|都看看|全部|四种|所有|每种"
    if ($wantsAll -or (Test-IsBoardImageRequest -Question $Question)) {
        return @($ImageCatalogEntries)
    }

    return @()
}

function Get-BoardImageAnswer {
    param(
        [string]$Question,
        [object[]]$ImageCatalogEntries,
        $ConversationState
    )

    if (-not (Test-IsBoardImageRequest -Question $Question)) {
        return $null
    }

    $matchedEntries = Get-MatchedBoardImageEntries -Question $Question -ImageCatalogEntries $ImageCatalogEntries -ConversationState $ConversationState
    $matchedCount = @($matchedEntries).Count
    if (-not $matchedEntries -or $matchedCount -eq 0) {
        return @{
            answer = "我这边暂时没有识别出您要看的具体板材。您可以直接说背景墙板、菜板、防火板或隔音板，我就按名称给您发参考图。"
            display_text = "我这边暂时没有识别出您要看的具体板材。您可以直接说背景墙板、菜板、防火板或隔音板，我就按名称给您发参考图。"
            asset_status = "no_match"
            asset_type = "board_image"
            caption = "当前没有命中具体板材图片。"
            assets = @()
        }
    }

    $assets = New-Object System.Collections.Generic.List[object]
    $assetStatus = if ($Question -match "吸音板" -and $Question -notmatch "隔音板") { "similar_match" } else { "exact_match" }
    foreach ($entry in $matchedEntries) {
        $entryId = (($entry.id | Out-String).Trim())
        $entryTitle = (($entry.title | Out-String).Trim())
        $boardInfo = Get-BoardTypeInfo -BoardType $entryId
        $caption = if ($boardInfo.caption) { $boardInfo.caption } else { "$entryTitle，适合对应板材参考场景，请结合具体使用空间确认，注意区分吸音与隔音。" }
        $assets.Add([ordered]@{
            url = Get-ProxiedCatalogImageUrl -OriginalUrl $entry.image_url
            alt = $entryTitle
            caption = $caption
            assetStatus = $assetStatus
            assetType = "board_image"
        })
    }

    if ($matchedCount -eq 1) {
        $entry = @($matchedEntries)[0]
        $entryTitle = (($entry.title | Out-String).Trim())
        return @{
            answer = if ($assetStatus -eq "similar_match") { "这边先给您发相近类别的 $entryTitle 参考图，它更接近您当前提到的板材方向，但不代表就是完全同款。您如果要继续看同类实拍，我也可以再按这个方向给您补。" } else { "这是您要看的$entryTitle 参考图。我先发您看一下，如果还想看更多角度或实拍图，也可以继续告诉我。" }
            display_text = if ($assetStatus -eq "similar_match") { "这边先给您发相近类别的 $entryTitle 参考图，它更接近您当前提到的板材方向，但不代表就是完全同款。您如果要继续看同类实拍，我也可以再按这个方向给您补。" } else { "这是您要看的$entryTitle 参考图。我先发您看一下，如果还想看更多角度或实拍图，也可以继续告诉我。" }
            asset_status = $assetStatus
            asset_type = "board_image"
            caption = $assets[0].caption
            assets = @($assets.ToArray())
        }
    }

    return @{
        answer = "先把相关板材参考图发您看一下。您如果想单独看某一种板的更多角度，也可以继续告诉我名称。"
        display_text = "先把相关板材参考图发您看一下。您如果想单独看某一种板的更多角度，也可以继续告诉我名称。"
        asset_status = $assetStatus
        asset_type = "board_image"
        caption = "已返回多张匹配板材参考图。"
        assets = @($assets.ToArray())
    }
}

function Resolve-FaqCsvPath {
    param([string]$ConfiguredPath)

    if ($ConfiguredPath -and (Test-Path -LiteralPath $ConfiguredPath)) {
        return (Resolve-Path -LiteralPath $ConfiguredPath).Path
    }

    $candidates = Get-ChildItem -LiteralPath "." -File -Filter "*.csv" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match "FAQ|faq" } |
        Sort-Object LastWriteTime -Descending

    if ($candidates) {
        return $candidates[0].FullName
    }

    return $null
}

function Get-KnowledgeRecords {
    param([string]$Root)

    $records = New-Object System.Collections.Generic.List[string]
    if (-not (Test-Path -LiteralPath $Root)) {
        return $records
    }

    $files = Get-ChildItem -LiteralPath $Root -Recurse -File |
        Where-Object {
            $_.Extension -in ".json", ".md" -and
            $_.FullName -notmatch "\\smoke(2)?\\"
        } |
        Sort-Object FullName

    foreach ($file in $files) {
        try {
            if ($file.Extension -eq ".json") {
                $items = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
                foreach ($item in $items) {
                    if ($null -eq $item.content) {
                        continue
                    }

                    $content = $item.content.ToString().Trim()
                    if (-not $content) {
                        continue
                    }

                    if (Test-IsLowQualityAnswer -Text $content) {
                        continue
                    }

                    $records.Add($content)
                }
                continue
            }

            foreach ($rawLine in Get-Content -LiteralPath $file.FullName -Encoding UTF8) {
                $content = $rawLine.Trim()
                if (-not $content -or $content.StartsWith("#")) {
                    continue
                }

                if (Test-IsLowQualityAnswer -Text $content) {
                    continue
                }

                $records.Add($content)
            }
        } catch {
            continue
        }
    }

    return $records
}

function Get-QuestionTokens {
    param([string]$Text)

    $tokens = New-Object System.Collections.Generic.List[string]
    $seen = @{}
    if (-not $Text) {
        return $tokens
    }

    foreach ($match in [regex]::Matches($Text, "[A-Za-z0-9]{2,}")) {
        $token = $match.Value.ToLowerInvariant()
        if (-not $seen.ContainsKey($token)) {
            $seen[$token] = $true
            $tokens.Add($token)
        }
    }

    foreach ($match in [regex]::Matches($Text, "[\u4e00-\u9fff]+")) {
        $segment = $match.Value
        if ($segment.Length -ge 2) {
            for ($i = 0; $i -le $segment.Length - 2; $i++) {
                $token = $segment.Substring($i, 2)
                if (-not $seen.ContainsKey($token)) {
                    $seen[$token] = $true
                    $tokens.Add($token)
                }
            }
        } elseif (-not $seen.ContainsKey($segment)) {
            $seen[$segment] = $true
            $tokens.Add($segment)
        }
    }

    if ($tokens.Count -gt 0) {
        return $tokens
    }

    foreach ($match in [regex]::Matches($Text, "[\u4e00-\u9fffA-Za-z0-9]")) {
        $token = $match.Value.ToLowerInvariant()
        if (-not $seen.ContainsKey($token)) {
            $seen[$token] = $true
            $tokens.Add($token)
        }
    }

    return $tokens
}

function Get-TextMatchScore {
    param(
        [string]$Question,
        [string]$Candidate
    )

    if (-not $Question -or -not $Candidate) {
        return 0
    }

    $tokens = Get-QuestionTokens -Text $Question
    if ($tokens.Count -eq 0) {
        return 0
    }

    $haystack = $Candidate.ToLowerInvariant()
    $score = 0
    foreach ($token in $tokens) {
        if (-not $haystack.Contains($token)) {
            continue
        }

        if ($token.Length -ge 4 -or $token -match "^[\u4e00-\u9fff]{2,}$") {
            $score += 2
        } else {
            $score += 1
        }
    }

    return $score
}

function Get-BestFaqAnswer {
    param(
        [string]$Question,
        [object[]]$FaqEntries
    )

    if (-not $FaqEntries -or $FaqEntries.Count -eq 0) {
        return $null
    }

    $normalizedQuestion = (($Question | Out-String).Trim()) -replace "[\s\p{P}\p{S}]+", ""
    if ($normalizedQuestion) {
        foreach ($entry in $FaqEntries) {
            $entryQuestion = (($entry.question | Out-String).Trim()) -replace "[\s\p{P}\p{S}]+", ""
            if ($entryQuestion -and $entryQuestion -eq $normalizedQuestion) {
                return $entry.answer
            }
        }
    }

    $best = $null
    $bestScore = 0

    foreach ($entry in $FaqEntries) {
        $questionText = (($entry.question | Out-String).Trim())
        $answerText = (($entry.answer | Out-String).Trim())
        $score = (Get-TextMatchScore -Question $Question -Candidate $questionText) * 3
        $score += Get-TextMatchScore -Question $Question -Candidate $answerText

        if ($score -gt $bestScore) {
            $bestScore = $score
            $best = $entry
        }
    }

    if ($bestScore -lt 3) {
        return $null
    }

    return $best.answer
}

function Test-IsGreetingOrLowIntent {
    param([string]$Question)

    if (-not $Question) {
        return $true
    }

    $trimmed = $Question.Trim()
    if (-not $trimmed) {
        return $true
    }

    if ($trimmed -match "^(你好|您好|哈喽|嗨|在吗|有人吗|hello|hi|你好呀|你好啊|可以聊聊吗|聊聊吗|可以跟你聊聊吗|方便聊聊吗|想了解一下)[!！。,.，\s]*$") {
        return $true
    }

    $domainHint = $trimmed -match "公司|产品|板材|硅藻|菜板|隔音板|背景墙|地板|家具|柜体|新房|装修|入住|除味|异味|甲醛|空气|价格|报价|合作|代理|施工|方案|地址|在哪|哪里|质量|效果|规格|尺寸|厚度|颜色|防水|防火|防潮|抗菌|隔音|有没有|怎么卖|推荐|适合|场景|吊顶|墙板|板"
    $hasQuestion = $trimmed -match "[\?？吗么呢]"
    $isVeryShort = $trimmed.Length -le 6

    if ($isVeryShort -and -not $domainHint -and -not $hasQuestion) {
        return $true
    }

    return $false
}

function Get-ClarifyingAnswer {
    param([string]$Question)

    if (Test-IsGreetingOrLowIntent -Question $Question) {
        return "可以，您直接说您现在最想确认的点就行。比如更关心适不适合新房、会不会有味道、适合哪些空间，还是想了解报价和合作方式？"
    }

    return "我先不乱给您堆资料。您可以直接告诉我现在最想确认的一点，比如新房能不能用、除味表现怎么样、适合什么空间，或者公司和产品情况，我再按这个点给您说清楚。"
}

function Test-IsModelIdentityQuestion {
    param([string]$Question)

    if (-not $Question) {
        return $false
    }

    $trimmed = (($Question | Out-String).Trim())
    return $trimmed -match "什么模型|哪个模型|模型是什么|用的什么AI|用的什么 ai|是不是GPT|是不是 GPT|ChatGPT|OpenAI|gpt-3|gpt-4|glm|gml" -or
        $trimmed -match "^(你是|你是谁|你是谁啊|你这边是|你们是谁|你是做什么的|你是干嘛的|介绍一下你|介绍下你|先说说你自己|你是人机吗|你是机器人吗|你是真人吗|你是人工客服吗|你是人工还是机器人)[？?]?$"
}

function Test-IsModelDiagnosticsCode {
    param([string]$Question)

    if (-not $Question) {
        return $false
    }

    return (($Question | Out-String).Trim()) -eq "24761"
}

function Get-ModelIdentityAnswer {
    return "我是 AI 在线顾问，不是真人客服。板材、场景和资料问题我可以先答；涉及报价、施工或合作时，我再帮您转给顾问继续跟进。"
}

function Get-LiveFastGptAppConfig {
    param([hashtable]$EnvMap)

    $containerName = Get-EnvValue -EnvMap $EnvMap -Key "FASTGPT_MONGO_CONTAINER" -Default "fastgpt-mongo"
    $mongoUser = Get-EnvValue -EnvMap $EnvMap -Key "MONGO_USER" -Default "myusername"
    $mongoPassword = Get-EnvValue -EnvMap $EnvMap -Key "MONGO_PASSWORD" -Default "mypassword"

    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        return @{
            ok = $false
            source = "fastgpt-mongo"
            model = ""
            error = "本机当前找不到 docker 命令，无法实时读取 FastGPT 容器配置。"
        }
    }

    $tmpJs = Get-TempStatePath -FileName ("live_fastgpt_model_{0}.js" -f ([guid]::NewGuid().ToString("N")))
    $containerPath = "/tmp/" + [System.IO.Path]::GetFileName($tmpJs)
    $js = @'
const d = db.getSiblingDB('fastgpt');
const appIdText = '69e0562ea67193262b8de666';
let app = null;
try {
  app = d.apps.findOne({ _id: ObjectId(appIdText) });
} catch (err) {}
if (!app) {
  app = d.apps.findOne({ name: { $in: ['广西亿库AI客服', 'Guangxi Yiku AI Customer Service'] } });
}

const modules = app && Array.isArray(app.modules) ? app.modules : [];
const chatNode = modules.find((node) => node.flowNodeType === 'chatNode');
const inputs = chatNode && Array.isArray(chatNode.inputs) ? chatNode.inputs : [];
const modelInput = inputs.find((input) => input.key === 'model');

print(JSON.stringify({
  ok: Boolean(modelInput && modelInput.value),
  source: 'fastgpt.mongo.apps.modules.chatNode.inputs.model',
  appName: app && app.name ? app.name : '',
  appId: app && app._id ? String(app._id) : '',
  nodeId: chatNode && chatNode.nodeId ? chatNode.nodeId : '',
  model: modelInput && modelInput.value ? modelInput.value : '',
  error: modelInput && modelInput.value ? '' : '没有在 FastGPT 应用聊天节点里读到 model 输入值'
}));
'@

    try {
        [System.IO.File]::WriteAllText($tmpJs, $js, [System.Text.UTF8Encoding]::new($false))
        & docker cp $tmpJs "${containerName}:${containerPath}" | Out-Null
        $output = & docker exec $containerName sh -lc "mongosh -u '$mongoUser' -p '$mongoPassword' --authenticationDatabase admin fastgpt --quiet '$containerPath'" 2>&1
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0) {
            return @{
                ok = $false
                source = "fastgpt-mongo"
                model = ""
                error = (($output | Out-String).Trim())
            }
        }

        $jsonLine = @($output | Where-Object { ($_ | Out-String).Trim().StartsWith("{") } | Select-Object -Last 1)
        if (-not $jsonLine) {
            return @{
                ok = $false
                source = "fastgpt-mongo"
                model = ""
                error = "Mongo 查询成功，但没有返回可解析的 JSON。"
            }
        }

        return ConvertTo-Hashtable -Value (($jsonLine | Out-String).Trim() | ConvertFrom-Json)
    } catch {
        return @{
            ok = $false
            source = "fastgpt-mongo"
            model = ""
            error = $_.Exception.Message
        }
    } finally {
        Remove-Item -LiteralPath $tmpJs -Force -ErrorAction SilentlyContinue
        try {
            & docker exec $containerName sh -lc "rm -f '$containerPath'" | Out-Null
        } catch {
        }
    }
}

function Get-ModelDiagnosticsAnswer {
    param(
        [hashtable]$EnvMap,
        [string]$ChatBackendMode
    )

    $fastGptConfig = Get-LiveFastGptAppConfig -EnvMap $EnvMap
    $directTextModel = Get-DirectTextModel -EnvMap $EnvMap
    $visionModel = Get-VisionModel -EnvMap $EnvMap
    $fastGptUrl = if ($EnvMap -and $EnvMap.ContainsKey("FASTGPT_APP_API_URL")) {
        (($EnvMap["FASTGPT_APP_API_URL"] | Out-String).Trim())
    } else {
        "http://127.0.0.1:3100/api/v1/chat/completions"
    }

    $openAiBaseUrl = if ($EnvMap -and $EnvMap.ContainsKey("OPENAI_BASE_URL")) {
        (($EnvMap["OPENAI_BASE_URL"] | Out-String).Trim())
    } else {
        ""
    }

    $fastGptModelText = if ($fastGptConfig.ok) {
        $fastGptConfig.model
    } else {
        "实时读取失败：$($fastGptConfig.error)"
    }
    $fastGptAppText = if ($fastGptConfig.appName) {
        "$($fastGptConfig.appName) / $($fastGptConfig.appId)"
    } else {
        "未读到应用信息"
    }

    $lines = @(
        "隐藏诊断：以下信息为本次请求现场读取，不是固定回答。",
        "1. FastGPT 应用模型：$fastGptModelText。",
        "2. FastGPT 读取来源：$($fastGptConfig.source)。",
        "3. FastGPT 应用：$fastGptAppText。",
        "4. FastGPT 失败后的直连回退模型：$directTextModel。",
        "5. 图片识别直连模型：$visionModel。",
        "6. 当前 CHAT_BACKEND：$ChatBackendMode。",
        "7. FastGPT API：$fastGptUrl。"
    )

    if ($openAiBaseUrl) {
        $lines += "8. 兼容模型 API：$openAiBaseUrl。"
    }

    return @{
        answer = ($lines -join "`n")
        backend_model = if ($fastGptConfig.ok) { $fastGptConfig.model } else { "" }
    }
}

function Get-ConcernLead {
    param(
        [string]$Question,
        [string]$Answer
    )

    return $null
}

function Format-CustomerServiceAnswer {
    param(
        [string]$Question,
        [string]$Answer,
        [string]$Mode = ""
    )

    if (-not $Answer) {
        return $Answer
    }

    $trimmed = $Answer.Trim()
    if (-not $trimmed) {
        return $trimmed
    }

    if ($trimmed -match "\*\*我\*\*\s*[:：]\s*(?<answer>.+)$") {
        $trimmed = $Matches.answer.Trim()
    }
    $trimmed = $trimmed -replace "^好的，?以下是我根据您的要求生成的对话[:：]?\s*", ""
    $trimmed = $trimmed -replace "\*\*用户\*\*\s*[:：][^*]+", ""

    $trimmed = $trimmed -replace "^根据现有资料显示", "就目前资料来看"
    $trimmed = $trimmed -replace "^现有资料显示", "就目前资料来看"
    $trimmed = $trimmed -replace "^资料显示", "就目前资料来看"
    $trimmed = $trimmed -replace "^(请问)?您(是)?想了解[^。！？!?]*[吗嘛][？?]?\s*", ""
    $trimmed = $trimmed -replace "^(请问)?您(是)?想问[^。！？!?]*[吗嘛][？?]?\s*", ""
    $trimmed = $trimmed -replace "^我是[^。！？!?]{0,40}(AI 顾问|AI顾问|客服顾问|在线顾问)[，,。]?\s*", ""
    $trimmed = $trimmed -replace "^这里是[^。！？!?]{0,40}(AI 顾问|AI顾问|客服顾问|在线顾问)[，,。]?\s*", ""
    $trimmed = $trimmed -replace "根据现有资料", "就目前资料来看"
    $trimmed = $trimmed -replace "现有资料显示", "就目前资料来看"
    $trimmed = $trimmed -replace "资料显示", "就目前资料来看"
    $trimmed = $trimmed -replace "根据资料", "就目前资料来看"
    $trimmed = $trimmed -replace "因为就目前资料来看产品", "就目前资料来看，这款产品"
    $trimmed = $trimmed -replace "因为就目前资料来看", "因为就目前资料来看，"
    $trimmed = $trimmed -replace "^如果您主要担心[^。！？!?]*[，,]\s*", ""
    $trimmed = $trimmed -replace "^如果您比较在意[^。！？!?]*[，,]\s*", ""
    $trimmed = $trimmed -replace "^如果您是在确认产品靠不靠谱[^。！？!?]*[，,]\s*", ""
    $trimmed = $trimmed -replace "^如果您是在看适不适合自己这个空间[^。！？!?]*[，,]\s*", ""
    $trimmed = $trimmed -replace "^这个问题问得很关键[。！!]\s*", ""
    $trimmed = $trimmed -replace "^这个顾虑很正常[。！!]\s*", ""
    $trimmed = $trimmed -replace "^您好[，,。!！]?\s*", ""
    $trimmed = $trimmed -replace "如果需要具体的证书编号或检测报告原件，建议您转人工咨询，我可以帮您对接。", "如果您需要具体的证书编号或检测报告原件，我可以帮您对接人工继续确认。"
    $trimmed = $trimmed -replace "建议您转人工服务，我们会为您详细提供。", "如果您需要具体的证书编号或检测报告原件，我可以帮您对接人工继续确认。"
    $trimmed = $trimmed -replace "建议您转人工服务", "如果您需要更细的原件或参数，我可以帮您对接人工继续确认"
    $trimmed = $trimmed -replace "如果您需要具体的证书编号或检测报告原件，如果您需要更细的原件或参数，我可以帮您对接人工继续确认获取更详细的信息。", "如果您需要具体的证书编号或检测报告原件，我可以帮您对接人工继续确认。"
    $trimmed = $trimmed -replace "如果您需要具体的证书编号或检测报告原件，如果您需要更细的原件或参数，我可以帮您对接人工继续确认。", "如果您需要具体的证书编号或检测报告原件，我可以帮您对接人工继续确认。"
    $trimmed = $trimmed -replace "^建议转人工提供", "如果您需要更细的原件或参数，我们这边再安排人工继续跟进"
    $trimmed = $trimmed -replace "建议转人工提供", "如果您需要更细的原件或参数，我们这边再安排人工继续跟进"
    $trimmed = $trimmed -replace "建议您转人工咨询", "如果您需要更细的原件或参数，我可以帮您对接人工继续确认"
    $trimmed = $trimmed -replace "建议转人工咨询", "如果您需要更细的原件或参数，我可以帮您对接人工继续确认"
    $trimmed = $trimmed -replace "建议转人工报价", "具体报价这边建议让顾问结合实际需求继续跟进"
    $trimmed = $trimmed -replace "建议转人工", "这类细节更适合让顾问继续跟进"
    $trimmed = $trimmed -replace "我建议您", "您这边可以"
    $trimmed = $trimmed -replace "首先，", ""
    $trimmed = $trimmed -replace "此外，", ""
    $trimmed = $trimmed -replace "因此，", ""
    $trimmed = $trimmed -replace "所以，", ""
    $trimmed = $trimmed -replace "^我们公司的", ""
    $trimmed = $trimmed -replace "非常实用的材料", "比较实用的材料"
    $trimmed = $trimmed -replace "特别适合", "适合"
    $trimmed = $trimmed -replace "非常适用", "也适用"
    $trimmed = $trimmed -replace "请问您对什么方面比较感兴趣呢？我可以为您提供更多相关信息。", ""
    $trimmed = $trimmed -replace "如果有更多具体需求或者需要进一步了解，欢迎随时咨询我们。我们会为您提供更详细的信息和建议。", ""
    $trimmed = $trimmed -replace "您可以详细介绍一下您想要制作的柜体的具体情况吗？这样我可以更好地为您提供建议。", ""
    $trimmed = $trimmed -replace "您可以给我一些时间，让我去了解一下，好吗？", "目前资料能确认到这里。"
    $trimmed = $trimmed -replace "您还有其他问题需要我解答吗[？?]?", ""
    $trimmed = $trimmed -replace "还有其他问题需要我解答吗[？?]?", ""
    $trimmed = $trimmed -replace "欢迎随时咨询(我们)?[。！!]?", ""
    $trimmed = $trimmed -replace "很高兴为您服务[。！!]?", ""
    $trimmed = $trimmed -replace "\s+", " "

    $lead = Get-ConcernLead -Question $Question -Answer $trimmed
    if ($lead) {
        $trimmed = "$lead$trimmed"
    }

    $sentences = New-Object System.Collections.Generic.List[string]
    foreach ($match in [regex]::Matches($trimmed, "[^。！？!?]+[。！？!?]?")) {
        $sentence = (($match.Value | Out-String).Trim())
        if (-not $sentence) {
            continue
        }
        if ($sentence -match "进一步了解我们的产品|咨询我们的专业设计师|为您提供更详细的建议|欢迎随时咨询|更好地为您提供建议") {
            continue
        }
        $sentences.Add($sentence)
        if ($sentences.Count -ge 4) {
            break
        }
    }

    if ($sentences.Count -gt 0) {
        $trimmed = ($sentences.ToArray() -join "")
    }

    return $trimmed
}

function New-ChatAnswerResult {
    param(
        [string]$Question,
        [string]$Answer,
        [string]$Mode,
        [hashtable]$Metadata = $null
    )

    $result = [ordered]@{
        answer = Format-CustomerServiceAnswer -Question $Question -Answer $Answer -Mode $Mode
        mode = $Mode
    }

    if ($Metadata) {
        foreach ($key in $Metadata.Keys) {
            $result[$key] = $Metadata[$key]
        }
    }

    return $result
}

function Get-RelevantFacts {
    param(
        [string]$Question,
        [object[]]$FaqEntries,
        [System.Collections.Generic.List[string]]$KnowledgeRecords,
        [int]$MaxFacts = 6
    )

    $ranked = New-Object System.Collections.Generic.List[object]
    $intentPatterns = New-Object System.Collections.Generic.List[string]
    $specificSeriesPattern = "硅藻蜂窝板|硅藻抗菌板|硅藻储能发光板|硅藻多孔消音隔热板|硅藻素板"
    $isSpecificSeriesQuestion = $Question -match $specificSeriesPattern
    $isGenericSceneQuestion = $Question -match "这个板材|这款板材|硅藻板.*适合|主要适合|适合什么场景|哪些场景|适用场景" -and -not $isSpecificSeriesQuestion

    if ($Question -match "介绍|产品|做什么|是什么|核心") {
        $intentPatterns.Add("核心产品|核心功能|适用场景|企业定位|做什么|净化空气|防霉|调湿")
    }
    if ($Question -match "公司|企业|地址|在哪|哪里|成立|注册资金") {
        $intentPatterns.Add("广西亿库光养硅藻环保科技有限公司|位于|北海|海洋产业科技园区|成立于|注册资金|企业定位|主营")
    }
    if ($Question -match "新房|装修|入住|家装") {
        $intentPatterns.Add("新房|入住|适合|通风|检测|无甲醛|无胶水|无油漆|环保性|家装")
    }
    if ($Question -match "除味|除醛|甲醛|异味|空气") {
        $intentPatterns.Add("净化空气|甲醛|除醛|异味|除味|吸附|有害物质|无甲醛|味道大吗")
    }
    if ($Question -match "价格|报价|多少钱|怎么卖") {
        $intentPatterns.Add("价格|报价|多少钱|规格厚度|使用面积|项目城市|交付要求|公开价")
    }
    if ($Question -match "柜体|橱柜|衣柜|书柜|家具|吊顶|移门") {
        $intentPatterns.Add("柜体|橱柜|衣柜|书柜|家具|吊顶|移门|内装饰板|可贴纸|可切割")
    }
    if ($Question -match "硅藻蜂窝板") {
        $intentPatterns.Add("硅藻蜂窝板")
    } elseif ($Question -match "硅藻抗菌板") {
        $intentPatterns.Add("硅藻抗菌板")
    } elseif ($Question -match "硅藻储能发光板") {
        $intentPatterns.Add("硅藻储能发光板")
    } elseif ($Question -match "硅藻多孔消音隔热板") {
        $intentPatterns.Add("硅藻多孔消音隔热板")
    } elseif ($Question -match "硅藻素板") {
        $intentPatterns.Add("硅藻素板")
    } elseif ($Question -match "适合|场景|哪里用|用在哪|用途") {
        $intentPatterns.Add("硅藻板适合哪些家装和工装场所|家庭装修|办公|病房|实验室|无菌室|学校|宾馆|剧院|商务大楼|会所|海滨项目")
    }

    foreach ($pattern in $intentPatterns) {
        foreach ($entry in $FaqEntries) {
            $questionText = ($entry.question | Out-String).Trim()
            $answerText = ($entry.answer | Out-String).Trim()
            $fact = "问题：$questionText`n回答：$answerText"
            if ($isGenericSceneQuestion -and $fact -match $specificSeriesPattern) {
                continue
            }
            if ($fact -match $pattern) {
                $ranked.Add([pscustomobject]@{
                    score = 20
                    text = $fact
                })
            }
        }
    }

    foreach ($entry in $FaqEntries) {
        $questionText = ($entry.question | Out-String).Trim()
        $answerText = ($entry.answer | Out-String).Trim()
        if (-not $questionText -or -not $answerText) {
            continue
        }

        $fact = "问题：$questionText`n回答：$answerText"
        if ($isGenericSceneQuestion -and $fact -match $specificSeriesPattern) {
            continue
        }
        $score = Get-TextMatchScore -Question $Question -Candidate $fact
        if ($score -ge 2) {
            $ranked.Add([pscustomobject]@{
                score = $score
                text = $fact
            })
        }
    }

    foreach ($record in $KnowledgeRecords) {
        $score = Get-TextMatchScore -Question $Question -Candidate $record
        if ($score -ge 2) {
            $ranked.Add([pscustomobject]@{
                score = $score
                text = $record
            })
        }
    }

    $facts = New-Object System.Collections.Generic.List[string]
    $seen = @{}
    foreach ($item in $ranked | Sort-Object score -Descending) {
        if ($facts.Count -ge $MaxFacts) {
            break
        }

        if ($seen.ContainsKey($item.text)) {
            continue
        }

        $seen[$item.text] = $true
        $facts.Add($item.text)
    }

    return $facts
}

function Get-BusinessGuardAnswer {
    param([string]$Question)

    if (-not $Question) {
        return $null
    }

    if ($Question -match "代理|经销|加盟|合作") {
        return "合作这类问题可以聊，不过具体政策、报价和推进流程，一般都要结合城市、合作方式和预估规模来确认。您如果方便，可以告诉我们所在城市、想做的合作方向和大概体量，我们再安排顾问按实际情况跟您对接，这样会更准确。"
    }

    if ($Question -match "报价|多少钱|价格|怎么卖") {
        return "价格这块一般不是一个固定口径，要结合产品型号、使用面积、项目场景和所在城市一起看，当前资料里也没有统一公开价。您如果愿意，可以直接告诉我们大概面积、使用场景和所在城市，我们再让顾问按实际需求给您报价。"
    }

    if ($Question -match "合同|施工|工期|勘测|设计方案|定制方案|现场") {
        return "这类问题通常要结合项目现场和具体需求来确认，当前资料里没有固定合同条款或统一施工工期可以直接套用。您可以先说一下项目城市、空间类型和大概需求，我们再安排顾问继续跟进会更稳妥。"
    }

    return $null
}

function Get-CompanyProfileAnswer {
    param([string]$Question)

    if (-not $Question) {
        return $null
    }

    $asksCompany = $Question -match "公司|企业|厂家"
    $asksProduct = $Question -match "产品|板材|做什么|主营"
    $asksEffect = $Question -match "效果|作用|功能"
    $asksQuality = $Question -match "质量|靠不靠谱|行不行|怎么样"
    $asksLocation = $Question -match "在哪|哪里|地址"

    if ($asksCompany -and $asksLocation) {
        return "公司地址资料里显示在广西北海海洋产业科技园区。您是想确认到访地址，还是想先了解产品适不适合您的项目？"
    }

    if ($asksCompany -and (($asksProduct -and $asksLocation) -or ($asksEffect -and $asksQuality) -or ($asksProduct -and $asksEffect))) {
        return "您如果是想先整体判断这家公司和产品靠不靠谱，可以先看这几个关键信息。广西亿库光养硅藻环保科技有限公司是一家做环保功能性板材相关业务的企业，主营的是功能性硅藻板，主要面向室内建筑装饰应用。就产品卖点来看，这款板材主打环保、调湿、防霉、净化空气、吸音和隔热，适合家装、办公、学校、病房、宾馆等室内空间。就目前资料来看，它强调无胶水、无油漆、无甲醛，同时具备抗菌防霉、保温隔热和吸音等特点。公司地址资料里显示在广西北海海洋产业科技园区。"
    }

    return $null
}

function Get-GuidedAnswer {
    param(
        [string]$Question,
        [object[]]$FaqEntries
    )

    if ($Question -match "新房|装修|入住|家装") {
        return "这款板材是适合新房和家装场景的。就目前资料来看，它无胶水、无油漆，不含甲醛等挥发性有害物质，安装后基本无明显异味，同时还有净化空气、调湿和防霉这些功能。更稳妥一点的话，新房入住前还是建议配合正常通风和检测一起看。"
    }

    if ($Question -match "除味|除醛|甲醛|异味|空气") {
        return "它可以在一定程度上帮助减轻异味、改善空气环境。就目前资料来看，这款硅藻板可吸附并净化甲醛、苯、甲苯、二甲苯和氨等有害物质，也能帮助减轻烟味、宠物味和厨房异味残留。更稳妥的做法还是配合日常通风一起使用。"
    }

    if ($Question -match "柜体|橱柜|衣柜|书柜|家具|吊顶|移门") {
        return "可以往这个方向用。资料里提到硅藻板可用于吊顶、橱柜、移门、内装饰板，也能做书桌、书柜、衣柜、床等家具；具体到柜体，还要结合承重、饰面和安装方式确认。"
    }

    if ($Question -match "介绍|产品|做什么|是什么") {
        return "这款产品是亿库光养的功能性硅藻板，核心卖点是环保、调湿、防霉、净化空气、隔热和更舒适的室内体验。就目前资料来看，它还具备防水阻燃、降噪吸音、抗菌防霉、保温隔热等特点，适用于家庭装修、办公、学校、病房、宾馆和会所等室内空间。"
    }

    return $null
}

function Get-ScenarioAwareAnswer {
    param(
        [string]$Question,
        $UserProfile,
        $ConversationState
    )

    if (-not $Question) {
        return $null
    }

    if ($Question -match "硅藻蜂窝板" -and $Question -match "适合|场景|哪里用|用在哪") {
        return "硅藻蜂窝板更适合同时看重结构稳定、防潮和装饰效果的空间。资料里提到的方向有装饰门板、墙板、吊顶、浴室、家具、地下室和客舱。"
    }

    if ($Question -match "硅藻抗菌板" -and $Question -match "适合|场景|哪里用|用在哪") {
        return "硅藻抗菌板更偏卫生和空气质量要求高的空间。资料里比较对口的是学校、医院、实验室这类场景，重点是抗菌、防霉和室内环境体验。"
    }

    if ($Question -match "硅藻储能发光板" -and $Question -match "适合|场景|哪里用|用在哪") {
        return "硅藻储能发光板更偏特殊用途，不是常规家装主材。资料里提到海岛设施、户外栈道、夜间场景，以及需要夜间发光提示的指示标识。"
    }

    if ($Question -match "硅藻多孔消音隔热板" -and $Question -match "适合|场景|哪里用|用在哪") {
        return "硅藻多孔消音隔热板更适合看重防火、隔热和吸音的项目。资料里提到被动房、冷库、高层建筑、高速公路、地铁，也包括电视中心、影剧院、体育馆这类声学场景。"
    }

    if ($Question -match "硅藻素板" -and $Question -match "适合|场景|哪里用|用在哪") {
        return "硅藻素板适用范围比较广，更偏兼顾装饰效果和综合功能的基础板材。资料里提到高端装配式内装、高档别墅、酒店、学校、商务大楼、豪华客船，也能用在车辆、门厂、家具厂和吊顶墙板等应用上。"
    }

    if ($Question -match "主要适合什么场景|适合什么场景|哪些场景|适用场景|用在哪|哪里用") {
        return "简单说，它不是只给单一场景用，家装和工装都能覆盖。资料里比较明确的方向有家庭装修、办公、学校、病房、宾馆、会所，也包括海滨项目；如果是医院、实验室、无菌室这类更看重空气质量和卫生条件的空间，也比较对口。"
    }

    $isSoundScenario = $Question -match "车流|噪音|噪声|吵醒|午睡|睡觉|隔音板推荐|隔音推荐|吸音板推荐|隔音板"
    $soundContextActive = $UserProfile.intent_primary -eq "sound_insulation" -or $ConversationState.current_topic -eq "sound_insulation"

    if ($isSoundScenario) {
        return "您这个更像外部车流噪声，不建议只靠一层装饰板解决。优先看窗户密封、中空窗和门缝；板材只做墙面时，吸音板偏改善室内反射，隔音毡加石膏板这类复合做法更接近墙体隔声。您先判断声音主要从窗进来，还是墙和门这边更明显，我再帮您缩小方案。"
    }

    if ($soundContextActive -and $Question -match "卧室更适合哪种|哪种更适合|推荐哪种|那用哪种") {
        return "如果重点是卧室午睡和外部车流噪声，优先顺序通常还是窗、门缝、墙面一起看。单说板材的话，卧室里更适合把吸音板当辅助优化，降低室内反射和刺耳感；如果墙体本身传声比较明显，再考虑隔音毡加石膏板这类复合做法，实际隔声会更靠谱。要是您想兼顾效果和施工复杂度，我建议先确认噪声主要从窗户进来还是墙面进来。"
    }

    if ($soundContextActive -and $Question -match "甲醛|异味|味道|环保") {
        return "如果您现在是在隔音需求之外，也担心甲醛和味道，这个顾虑很正常。就卧室场景来说，环保和味道要单独确认，但它和隔音不是一回事，不能把环保板材直接当成隔音主方案。更稳妥的做法是先按隔音路径判断窗、门缝和墙面，再在可选板材里优先挑味道和环保表现更稳的类型。"
    }

    return $null
}

function Test-AnswerNeedsGuidance {
    param(
        [string]$Question,
        [string]$Answer
    )

    if (-not $Answer) {
        return $true
    }

    $trimmed = $Answer.Trim()
    if (-not $trimmed) {
        return $true
    }

    if ($trimmed -match "硅酸钙板|硅藻泥板|广西安吉") {
        return $true
    }

    if ($trimmed -match "^(您好|你好).*(请问|想了解).*" -or $trimmed -match "^(请问)?您(是)?想(了解|问)" -or $trimmed -match "请具体说明|我会尽快为您提供帮助") {
        return $true
    }

    if ($Question -match "介绍|产品|做什么|是什么|材料" -and $trimmed -notmatch "硅藻板|功能性|调湿|防霉|净化空气") {
        return $true
    }

    if ($Question -match "新房|装修|入住|家装" -and $trimmed -notmatch "新房|入住|通风|检测|无胶水|无油漆|甲醛|异味") {
        return $true
    }

    if ($Question -match "除味|除醛|甲醛|异味|空气" -and $trimmed -notmatch "甲醛|异味|净化空气|吸附|有害物质|通风") {
        return $true
    }

    if ($Question -match "柜体|橱柜|衣柜|书柜|家具|吊顶|移门" -and $trimmed -notmatch "柜|橱柜|衣柜|书柜|家具|吊顶|移门|内装饰板") {
        return $true
    }

    if ($Question -match "硅藻蜂窝板" -and $trimmed -notmatch "蜂窝|装饰门板|墙板|吊顶|浴室|家具|地下室|客舱") {
        return $true
    }

    if ($Question -notmatch "船|海洋|海边|滨海|码头|客舱|海洋牧场" -and $trimmed -match "船舶内装|海洋牧场") {
        return $true
    }

    return $false
}

function Get-DemoFacts {
    param(
        [string]$Question,
        [System.Collections.Generic.List[string]]$KnowledgeRecords
    )

    $facts = New-Object System.Collections.Generic.List[string]
    $knowledgeText = ($KnowledgeRecords | Select-Object -First 24) -join "`n"

    if ($Question -match "odor|smell" -or $knowledgeText -match "odor absorption|assist odor absorption") {
        $facts.Add("这款材料在合适场景下可以辅助吸附异味。")
    }
    if ($Question -match "new house|house|home" -or $knowledgeText -match "home and commercial spaces") {
        $facts.Add("资料里提到它适用于家庭和商业室内空间。")
    }
    if ($Question -match "ventilation|inspection|new house" -or $knowledgeText -match "ventilation and inspection") {
        $facts.Add("如果是新房场景，仍建议结合正常通风和检测一起判断。")
    }
    if ($facts.Count -eq 0) {
        $facts.Add("当前演示知识更适合回答产品介绍、使用场景和咨询跟进类问题。")
    }

    return $facts
}

function Get-ChatBackendMode {
    param([hashtable]$EnvMap)

    $rawMode = ""
    if ($EnvMap.ContainsKey("CHAT_BACKEND")) {
        $rawMode = (($EnvMap["CHAT_BACKEND"] | Out-String).Trim()).ToLowerInvariant()
    }

    switch ($rawMode) {
        "fastgpt" { return "fastgpt" }
        "fastgpt_prefer" { return "fastgpt_prefer" }
        "direct" { return "direct" }
        default { return "direct" }
    }
}

function Test-GuidedAnswerEnabled {
    param([hashtable]$EnvMap)

    $rawValue = ""
    if ($EnvMap.ContainsKey("DEMO_GUIDED_ANSWER")) {
        $rawValue = (($EnvMap["DEMO_GUIDED_ANSWER"] | Out-String).Trim()).ToLowerInvariant()
    }

    switch ($rawValue) {
        "off" { return $false }
        "false" { return $false }
        "0" { return $false }
        default { return $true }
    }
}

function Test-IsWeakFastGPTAnswer {
    param(
        [string]$Question,
        [string]$Answer
    )

    if (-not $Answer) {
        return $true
    }

    $trimmed = $Answer.Trim()
    if (-not $trimmed) {
        return $true
    }

    if ($trimmed -match "How can I help you today|Feel free to ask anything|I can help") {
        return $true
    }

    if ($trimmed -match "抱歉.*没有检索到" -or
        $trimmed -match "目前没有检索到" -or
        $trimmed -match "暂无相关信息" -or
        $trimmed -match "无法为您确认" -or
        $trimmed -match "^您好.*暂无" -or
        $trimmed -match "^(请问)?您(是)?想了解" -or
        $trimmed -match "^(请问)?您(是)?想问" -or
        $trimmed -match "请问您是想了解" -or
        $trimmed -match "请问您是用于" -or
        $trimmed -match "请问您指的是哪种产品" -or
        $trimmed -match "请问您需要了解的是哪个") {
        return $true
    }

    if (-not (Test-IsModelIdentityQuestion -Question $Question) -and (
        $trimmed -match "我是人工客服，不是智能机器人" -or
        $trimmed -match "不是智能机器人")) {
        return $true
    }

    if (-not (Test-IsModelIdentityQuestion -Question $Question) -and (
        $trimmed -match "^我是[^。！？!?]{0,40}(AI 顾问|AI顾问|客服顾问|在线顾问)" -or
        $trimmed -match "官网销售客服顾问" -or
        $trimmed -match "您还有其他问题需要我解答吗" -or
        $trimmed -match "欢迎随时咨询")) {
        return $true
    }

    if ($trimmed -match "未找到明确依据" -or $trimmed -match "当前知识库没有足够依据") {
        return $false
    }

    if ($Question -and (Test-AnswerNeedsGuidance -Question $Question -Answer $trimmed) -and ($trimmed -match "请问" -or $trimmed -match "^您(是)?想")) {
        return $true
    }

    return $false
}

function Invoke-FastGPTAppChat {
    param(
        [string]$Question,
        [string]$ImageUrl,
        [hashtable]$EnvMap,
        [string]$ChatId = "",
        [string]$ContextBundleText = "",
        [string]$KnowledgeText = "",
        [string]$RagPromptTemplateText = ""
    )

    $apiUrl = ""
    if ($EnvMap.ContainsKey("FASTGPT_APP_API_URL")) {
        $apiUrl = (($EnvMap["FASTGPT_APP_API_URL"] | Out-String).Trim())
    }
    if (-not $apiUrl) {
        $apiUrl = "http://127.0.0.1:3100/api/v1/chat/completions"
    }

    $apiKey = ""
    if ($EnvMap.ContainsKey("FASTGPT_APP_API_KEY")) {
        $apiKey = (($EnvMap["FASTGPT_APP_API_KEY"] | Out-String).Trim())
    }
    if (-not $apiKey) {
        return $null
    }

    $imageContext = if ($ImageUrl) { "当前用户附带了一张图片，请结合图片内容一起判断。" } else { "" }
    $userPrompt = Build-GroundedUserPrompt -Question $Question -ContextBundleText $ContextBundleText -KnowledgeText $KnowledgeText -RagPromptTemplateText $RagPromptTemplateText -ImageSummary $imageContext

    $messageContent = if ($ImageUrl) {
        @(
            @{
                type = "text"
                text = $userPrompt
            },
            @{
                type = "image_url"
                image_url = @{
                    url = $ImageUrl
                }
            }
        )
    } else {
        $userPrompt
    }

    $payload = @{
        chatId = if ($ChatId) { $ChatId } else { "demo-" + [guid]::NewGuid().ToString("N").Substring(0, 12) }
        stream = $false
        variables = @{}
        messages = @(
            @{
                role = "user"
                content = $messageContent
            }
        )
    } | ConvertTo-Json -Depth 10

    try {
        $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers @{
            Authorization = "Bearer $apiKey"
        } -ContentType "application/json; charset=utf-8" -Body ([System.Text.Encoding]::UTF8.GetBytes($payload)) -TimeoutSec 25

        $answer = $response.choices[0].message.content
        if (Test-IsWeakFastGPTAnswer -Question $Question -Answer $answer) {
            return $null
        }

        return @{
            answer = $answer
            mode = if ($ImageUrl) { "fastgpt_vision_app" } else { "fastgpt_app" }
        }
    } catch {
        return $null
    }
}

function Save-ImageDataUrlToPublicStorage {
    param(
        [string]$ImageDataUrl,
        [string]$ImageName = ""
    )

    if (-not (Test-HasImagePayload -ImageDataUrl $ImageDataUrl)) {
        return $null
    }

    $match = [regex]::Match($ImageDataUrl, '^data:image/(?<format>png|jpeg|jpg|webp);base64,(?<data>.+)$')
    if (-not $match.Success) {
        return $null
    }

    $format = $match.Groups['format'].Value.ToLowerInvariant()
    $base64Data = $match.Groups['data'].Value
    $extension = if ($format -eq 'jpeg') { 'jpg' } else { $format }
    $safeName = if ($ImageName) { [System.IO.Path]::GetFileNameWithoutExtension($ImageName) } else { 'chat_image' }
    $safeName = ($safeName -replace '[^A-Za-z0-9_-]+', '_').Trim('_')
    if (-not $safeName) {
        $safeName = 'chat_image'
    }

    $tempDir = Join-Path $PSScriptRoot "..\tmp"
    if (-not (Test-Path -LiteralPath $tempDir)) {
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    }

    $tempFile = Join-Path $tempDir ("upload_" + [guid]::NewGuid().ToString("N") + "_" + $safeName + "." + $extension)
    $uploadScript = Join-Path $PSScriptRoot "upload_minio_public.py"
    if (-not (Test-Path -LiteralPath $uploadScript)) {
        return $null
    }

    try {
        [System.IO.File]::WriteAllBytes($tempFile, [Convert]::FromBase64String($base64Data))
        if (-not $script:PythonExe) {
            $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
            if ($pythonCmd) {
                $script:PythonExe = $pythonCmd.Source
            }
        }
        if (-not $script:PythonExe) {
            return $null
        }

        $output = & $script:PythonExe $uploadScript $tempFile --prefix "chat-images" 2>$null
        $url = (($output | Out-String).Trim() -split "`r?`n" | Select-Object -Last 1)
        if ($url -and $url -match '^https?://') {
            return $url
        }
    } catch {
    } finally {
        Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
    }

    return $null
}

function Test-HasImagePayload {
    param([string]$ImageDataUrl)

    if (-not $ImageDataUrl) {
        return $false
    }

    return $ImageDataUrl -match "^data:image\/(png|jpeg|jpg|webp);base64,"
}

function Invoke-VisionModelChat {
    param(
        [string]$Question,
        [string]$ImageDataUrl,
        [string]$ImageName,
        [string]$SystemPrompt,
        [string]$Knowledge,
        [hashtable]$EnvMap
    )

    if (-not (Test-HasImagePayload -ImageDataUrl $ImageDataUrl)) {
        return $null
    }

    $baseUrl = ""
    if ($EnvMap.ContainsKey("OPENAI_BASE_URL")) {
        $baseUrl = (($EnvMap["OPENAI_BASE_URL"] | Out-String).Trim())
    }

    $apiKey = ""
    if ($EnvMap.ContainsKey("CHAT_API_KEY")) {
        $apiKey = (($EnvMap["CHAT_API_KEY"] | Out-String).Trim())
    }

    if (-not $baseUrl -or -not $apiKey -or $apiKey -match "__REPLACE_WITH_REAL") {
        return $null
    }

    $hasExplicitQuestion = -not [string]::IsNullOrWhiteSpace($Question)
    $questionText = if ($hasExplicitQuestion) {
        $Question
    } else {
        "请只总结这张图片里能明确看到的内容，控制在 3 到 6 条，不要猜测看不清的细节，也不要补充图片外的信息。"
    }

    $knowledgeText = if ($Knowledge) {
        $Knowledge
    } else {
        "- 当前没有额外命中的知识片段，请只依据图片和问题中能确认的内容回答。"
    }

    $imageHint = if ($ImageName) {
        "图片文件名：$ImageName"
    } else {
        "图片文件名：未提供"
    }

    $userPrompt = @"
用户问题：$questionText
$imageHint

你是亿库硅藻板的销售顾问。请仔细查看用户发来的图片，然后：
1. 先描述图片里能明确看到的内容（场景、环境、人物、物品等）
2. 结合用户的问题，直接给出回答。如果问题涉及硅藻板是否适用，就根据图片场景给出专业判断
3. 如果图片信息不足以给出完整答案，诚实说明哪里看不清，并追问一个最关键的信息
4. 回答要自然、口语化，像微信里跟客户聊天一样。控制在 3-6 句
5. 不要编造图片里没有的内容

已知产品事实：
$knowledgeText
"@

    $payloadObject = @{
        model = Get-VisionModel -EnvMap $EnvMap
        stream = $false
        temperature = 0.1
        messages = @(
            @{
                role = "system"
                content = $SystemPrompt
            },
            @{
                role = "user"
                content = @(
                    @{
                        type = "text"
                        text = $userPrompt
                    },
                    @{
                        type = "image_url"
                        image_url = @{
                            url = $ImageDataUrl
                        }
                    }
                )
            }
        )
    }

    $payload = $payloadObject | ConvertTo-Json -Depth 10
    $payloadBytes = [System.Text.Encoding]::UTF8.GetBytes($payload)

    try {
        $chatUrl = $baseUrl.TrimEnd("/") + "/chat/completions"
        $response = Invoke-JsonApiRequest -Uri $chatUrl -Headers @{
            Authorization = "Bearer $apiKey"
        } -BodyBytes $payloadBytes -TimeoutSec 90

        $answer = $response.choices[0].message.content
        if (-not $answer -or -not $answer.Trim() -or (Test-IsLowQualityAnswer -Text $answer)) {
            return $null
        }

        return @{
            answer = $answer
            mode = "vision_model"
        }
    } catch {
        return $null
    }
}

function Invoke-DirectGroundedTextChat {
    param(
        [string]$Question,
        [string]$SystemPrompt,
        [string]$Knowledge,
        [string]$ImageSummary,
        [hashtable]$EnvMap,
        [string]$ContextBundleText = "",
        [string]$RagPromptTemplateText = "",
        [string]$DirectTextModel = "",
        [double]$Temperature = 0.1
    )

    $providerConfig = Get-DirectTextProviderConfig -EnvMap $EnvMap -Override $DirectTextModel
    $baseUrl = $providerConfig.base_url
    $apiKey = $providerConfig.api_key

    if (-not $baseUrl -or -not $apiKey -or $apiKey -match "__REPLACE_WITH_REAL") {
        return $null
    }

    $userContent = Build-GroundedUserPrompt -Question $Question -ContextBundleText $ContextBundleText -KnowledgeText $Knowledge -RagPromptTemplateText $RagPromptTemplateText -ImageSummary $ImageSummary

    $payloadMap = [ordered]@{
        model = $providerConfig.model
        stream = $false
        temperature = $Temperature
        messages = @(
            @{
                role = "system"
                content = $SystemPrompt
            },
            @{
                role = "user"
                content = $userContent
            }
        )
    }
    if ($providerConfig.provider -eq "deepseek") {
        $payloadMap["thinking"] = @{
            type = "disabled"
        }
    }
    $payload = $payloadMap | ConvertTo-Json -Depth 8

    try {
        $chatUrl = $baseUrl.TrimEnd("/") + "/chat/completions"
        $response = Invoke-JsonApiRequest -Uri $chatUrl -Headers @{
            Authorization = "Bearer $apiKey"
        } -BodyBytes ([System.Text.Encoding]::UTF8.GetBytes($payload)) -TimeoutSec 60

        $answer = $response.choices[0].message.content
        if ($answer -and $answer.Trim() -and -not (Test-IsLowQualityAnswer -Text $answer)) {
            return $answer
        }
    } catch {
    }

    return $null
}

function Finalize-ChatResult {
    param(
        [string]$Channel,
        [string]$ExternalUserId,
        [string]$ConversationId,
        [string]$SessionId,
        [string]$Question,
        [bool]$HasImage,
        $RawResult,
        $UserProfile,
        $ConversationState
    )

    $ConversationState.session_id = $SessionId
    $answerForMemory = if ((Test-MapContainsKey -Map $RawResult -Key "display_text") -and $RawResult.display_text) {
        $RawResult.display_text
    } else {
        $RawResult.answer
    }

    Update-UserProfile -UserProfile $UserProfile -Question $Question -Answer $answerForMemory -HasImage $HasImage
    Update-ConversationMemory -ConversationState $ConversationState -Question $Question -Answer $answerForMemory -HasImage $HasImage

    if (-not (Test-MapContainsKey -Map $RawResult -Key "handoff")) {
        $RawResult["handoff"] = @{
            handoff_readiness = $UserProfile.handoff_readiness
            lead_capture_needed = $UserProfile.handoff_readiness -in @("medium", "high")
            suggested_next_action = if ($UserProfile.handoff_readiness -eq "high") {
                "建议转人工继续跟进价格、施工或联系方式。"
            } elseif ($UserProfile.handoff_readiness -eq "medium") {
                "建议继续确认城市、面积或具体方案，再视情况转人工。"
            } else {
                "当前可继续由 AI 承接基础咨询。"
            }
        }
    }

    Save-SessionStores

    return Build-ChannelResponse -Channel $Channel -RawResult $RawResult
}

function Get-ChatAnswer {
    param(
        [string]$Channel,
        [string]$ExternalUserId,
        [string]$ConversationId,
        [string]$SessionId,
        [string]$Question,
        [object[]]$History,
        [string]$ImageDataUrl,
        [string]$ImageName,
        [string]$ModelOverride,
        [string]$EnvFilePath,
        [object[]]$FaqEntries,
        [object[]]$ImageCatalogEntries,
        [System.Collections.Generic.List[string]]$KnowledgeRecords,
        [string]$PromptTemplateText,
        [string]$RagPromptTemplateText,
        [string]$VisionPromptTemplateText,
        [bool]$IsLoggedIn = $false
    )

    $channelName = if ($Channel) { $Channel } else { "web" }
    $externalId = if ($ExternalUserId) { $ExternalUserId } else { "anonymous-web-user" }
    $conversationIdValue = if ($ConversationId) { $ConversationId } else { "default-conversation" }
    $sessionIdValue = if ($SessionId) { $SessionId } else { "default-session" }
    $hasImage = Test-HasImagePayload -ImageDataUrl $ImageDataUrl

    $userProfile = Get-Or-CreateUserProfile -Channel $channelName -ExternalUserId $externalId
    $conversationState = Get-Or-CreateConversationState -Channel $channelName -ExternalUserId $externalId -ConversationId $conversationIdValue -SessionId $sessionIdValue

    if (-not $IsLoggedIn) {
        $key = Get-ChannelProfileKey -Channel $channelName -ExternalUserId $externalId
        if ($script:SessionProfiles.ContainsKey($key)) {
            $script:SessionProfiles[$key] = Normalize-UserProfile -Record $null -Channel $channelName -ExternalUserId $externalId
            $userProfile = $script:SessionProfiles[$key]
        }
        $convKey = Get-ConversationStoreKey -Channel $channelName -ExternalUserId $externalId -ConversationId $conversationIdValue
        if ($script:SessionHistories.ContainsKey($convKey)) {
            $script:SessionHistories[$convKey] = Normalize-ConversationState -Record $null -Channel $channelName -ExternalUserId $externalId -ConversationId $conversationIdValue -SessionId $sessionIdValue
            $conversationState = $script:SessionHistories[$convKey]
        }
    }
    if ($conversationState.turns.Count -eq 0 -and $History) {
        foreach ($item in @($History | Select-Object -Last 6)) {
            $role = (($item.role | Out-String).Trim())
            $text = if ($item.text) { [string]$item.text } elseif ($item.content) { [string]$item.content } else { "" }
            if (-not $role -or -not $text) {
                continue
            }
            $conversationState.turns += @(
                [ordered]@{
                    role = $role
                    text = New-TrimmedText -Text $text -MaxLength 200
                    has_image = $false
                }
            )
        }
    }

    $envMap = Get-EnvMap -Path $EnvFilePath
    $chatBackendMode = Get-ChatBackendMode -EnvMap $envMap
    $fastgptAttempted = $false
    $baseUrl = $envMap["OPENAI_BASE_URL"]
    $apiKey = $envMap["CHAT_API_KEY"]
    $contextBundle = Build-ContextBundle -Channel $channelName -ExternalUserId $externalId -ConversationId $conversationIdValue -Question $Question
    $conversationCacheScope = Get-ConversationStoreKey -Channel $channelName -ExternalUserId $externalId -ConversationId $conversationIdValue

    if (Test-IsModelDiagnosticsCode -Question $Question) {
        $diagnostics = Get-ModelDiagnosticsAnswer -EnvMap $envMap -ChatBackendMode $chatBackendMode
        $result = @{
            answer = $diagnostics.answer
            mode = "model_diagnostics"
            backend_model = $diagnostics.backend_model
        }
        return Finalize-ChatResult -Channel $channelName -ExternalUserId $externalId -ConversationId $conversationIdValue -SessionId $sessionIdValue -Question $Question -HasImage $hasImage -RawResult $result -UserProfile $userProfile -ConversationState $conversationState
    }

    if (Test-IsModelIdentityQuestion -Question $Question) {
        $result = @{
            answer = Get-ModelIdentityAnswer
            mode = "identity_guard"
        }
        return Finalize-ChatResult -Channel $channelName -ExternalUserId $externalId -ConversationId $conversationIdValue -SessionId $sessionIdValue -Question $Question -HasImage $hasImage -RawResult $result -UserProfile $userProfile -ConversationState $conversationState
    }

    $questionForRetrieval = if ($Question) {
        $Question
    } elseif ($ImageName) {
        $ImageName
    } else {
        "图片咨询"
    }
    if ($conversationState.current_board_type -and $Question -match "这款|这张|这个|有图吗|参考图吗|实拍图吗") {
        $boardInfo = Get-BoardTypeInfo -BoardType $conversationState.current_board_type
        if ($boardInfo.title) {
            $questionForRetrieval = "$Question $($boardInfo.title)"
        }
    }

    $relevantFacts = Get-RelevantFacts -Question $questionForRetrieval -FaqEntries $FaqEntries -KnowledgeRecords $KnowledgeRecords -MaxFacts 6
    $knowledge = if ($relevantFacts.Count -gt 0) {
        ($relevantFacts | ForEach-Object { "- $_" }) -join "`n"
    } else {
        ""
    }
    $modelContextText = if ($contextBundle.text) {
        $contextBundle.text
    } else {
        ""
    }
    $systemPrompt = if ($PromptTemplateText) {
        $PromptTemplateText.Replace("{KNOWLEDGE_SNIPPETS}", $(if ($knowledge) { $knowledge } else { "- 当前未检索到足够相关的知识事实，优先追问澄清，不要直接大段介绍产品。" }))
    } else {
        "你是广西亿库光养硅藻环保科技有限公司的官网销售客服顾问。请优先回答用户实际问题，逐项覆盖并保持自然专业，只根据已知资料回答。`n已知事实：`n$knowledge"
    }
    $visionSystemPrompt = if ($VisionPromptTemplateText) {
        $VisionPromptTemplateText.Replace("{KNOWLEDGE_SNIPPETS}", $(if ($knowledge) { $knowledge } else { "- 当前没有额外命中的知识片段，请优先依据图片和用户问题回答。" }))
    } else {
        "你是广西亿库官网销售客服顾问。请先识别图片中能确认的内容，再结合用户问题回答，只依据图片和已知事实作答。"
    }
    $businessGuardAnswer = Get-BusinessGuardAnswer -Question $Question
    $companyProfileAnswer = Get-CompanyProfileAnswer -Question $Question
    $clarifyingAnswer = if ((Test-IsGreetingOrLowIntent -Question $Question) -or $relevantFacts.Count -eq 0) {
        Get-ClarifyingAnswer -Question $Question
    } else {
        $null
    }
    $scenarioAwareAnswer = Get-ScenarioAwareAnswer -Question $Question -UserProfile $userProfile -ConversationState $conversationState
    $guidedAnswerEnabled = Test-GuidedAnswerEnabled -EnvMap $envMap
    $guidedAnswer = if ($guidedAnswerEnabled) {
        Get-GuidedAnswer -Question $Question -FaqEntries $FaqEntries
    } else {
        $null
    }
    $bestFaqAnswer = Get-BestFaqAnswer -Question $Question -FaqEntries $FaqEntries
    $uploadedImageUrl = if ($hasImage) {
        Save-ImageDataUrlToPublicStorage -ImageDataUrl $ImageDataUrl -ImageName $ImageName
    } else {
        $null
    }
    $boardImageAnswer = Get-BoardImageAnswer -Question $Question -ImageCatalogEntries $ImageCatalogEntries -ConversationState $conversationState

    if ($boardImageAnswer) {
        $metadata = @{}
        foreach ($key in $boardImageAnswer.Keys) {
            if ($key -ne "answer") {
                $metadata[$key] = $boardImageAnswer[$key]
            }
        }
        $result = New-ChatAnswerResult -Question $Question -Answer $boardImageAnswer.answer -Mode "board_image_catalog" -Metadata $metadata
        return Finalize-ChatResult -Channel $channelName -ExternalUserId $externalId -ConversationId $conversationIdValue -SessionId $sessionIdValue -Question $Question -HasImage $hasImage -RawResult $result -UserProfile $userProfile -ConversationState $conversationState
    }

    if ($hasImage) {
        if ($chatBackendMode -in @("fastgpt", "fastgpt_prefer") -and $uploadedImageUrl) {
            $fastgptVisionAnswer = Invoke-FastGPTAppChat -Question $Question -ImageUrl $uploadedImageUrl -EnvMap $envMap -ChatId $conversationState.fastgpt_chat_id -ContextBundleText $modelContextText -KnowledgeText $knowledge -RagPromptTemplateText $RagPromptTemplateText
            if ($fastgptVisionAnswer) {
                $result = New-ChatAnswerResult -Question $questionForRetrieval -Answer $fastgptVisionAnswer.answer -Mode $fastgptVisionAnswer.mode
                return Finalize-ChatResult -Channel $channelName -ExternalUserId $externalId -ConversationId $conversationIdValue -SessionId $sessionIdValue -Question $Question -HasImage $hasImage -RawResult $result -UserProfile $userProfile -ConversationState $conversationState
            }
        }

        $visionAnswer = Invoke-VisionModelChat -Question $Question -ImageDataUrl $ImageDataUrl -ImageName $ImageName -SystemPrompt $visionSystemPrompt -Knowledge $knowledge -EnvMap $envMap
        if ($visionAnswer) {
            $visionResponse = ($visionAnswer.answer | Out-String).Trim()
            $result = New-ChatAnswerResult -Question $Question -Answer $visionResponse -Mode "vision_direct"
            return Finalize-ChatResult -Channel $channelName -ExternalUserId $externalId -ConversationId $conversationIdValue -SessionId $sessionIdValue -Question $Question -HasImage $hasImage -RawResult $result -UserProfile $userProfile -ConversationState $conversationState
        }    }

    if ($chatBackendMode -in @("fastgpt", "fastgpt_prefer")) {
        $cachedFastGptAnswer = Get-CachedFastGptAnswer -Question $Question -Scope $conversationCacheScope
        if ($cachedFastGptAnswer) {
            $result = New-ChatAnswerResult -Question $Question -Answer $cachedFastGptAnswer -Mode "fastgpt_cache"
            return Finalize-ChatResult -Channel $channelName -ExternalUserId $externalId -ConversationId $conversationIdValue -SessionId $sessionIdValue -Question $Question -HasImage $hasImage -RawResult $result -UserProfile $userProfile -ConversationState $conversationState
        }

        $fastgptAttempted = $true
        $fastgptAnswer = Invoke-FastGPTAppChat -Question $Question -EnvMap $envMap -ChatId $conversationState.fastgpt_chat_id -ContextBundleText $modelContextText -KnowledgeText $knowledge -RagPromptTemplateText $RagPromptTemplateText
        if ($fastgptAnswer) {
            $formattedFastGptAnswer = Format-CustomerServiceAnswer -Question $Question -Answer $fastgptAnswer.answer -Mode $fastgptAnswer.mode
            Set-CachedFastGptAnswer -Question $Question -Answer $formattedFastGptAnswer -Scope $conversationCacheScope
            $result = @{
                answer = $formattedFastGptAnswer
                mode = $fastgptAnswer.mode
            }
            return Finalize-ChatResult -Channel $channelName -ExternalUserId $externalId -ConversationId $conversationIdValue -SessionId $sessionIdValue -Question $Question -HasImage $hasImage -RawResult $result -UserProfile $userProfile -ConversationState $conversationState
        }

        if ($chatBackendMode -eq "fastgpt") {
            $result = New-ChatAnswerResult -Question $Question -Answer "我这边刚刚没从知识库应用里拿到稳定结果。您可以换一种更具体的问法，比如适不适合新房、会不会有味道、公司在哪里，我再继续帮您确认。" -Mode "fastgpt_unavailable"
            return Finalize-ChatResult -Channel $channelName -ExternalUserId $externalId -ConversationId $conversationIdValue -SessionId $sessionIdValue -Question $Question -HasImage $hasImage -RawResult $result -UserProfile $userProfile -ConversationState $conversationState
        }
    }

    if ($apiKey -and $baseUrl -and $apiKey -notmatch "__REPLACE_WITH_REAL") {
        $candidate = Invoke-DirectGroundedTextChat -Question $Question -SystemPrompt $systemPrompt -Knowledge $knowledge -ImageSummary "" -EnvMap $envMap -ContextBundleText $modelContextText -RagPromptTemplateText $RagPromptTemplateText -DirectTextModel $ModelOverride -Temperature 0.22
        if ($candidate) {
            $answer = $candidate
            $mode = "api_rag"
        }
    }

    if (-not $answer) {
        if ($hasImage) {
            $answer = "当前图片咨询通道稍忙，我这次没拿到稳定结果。您可以稍后再试，或先换一张更清晰的图片重新发我。"
        } else {
            $answer = "当前咨询通道稍忙，您可以稍后再试，或先留下联系方式，我们会尽快与您联系。"
        }
        $mode = "live_unavailable"
    }

    $result = New-ChatAnswerResult -Question $Question -Answer $answer -Mode $mode
    return Finalize-ChatResult -Channel $channelName -ExternalUserId $externalId -ConversationId $conversationIdValue -SessionId $sessionIdValue -Question $Question -HasImage $hasImage -RawResult $result -UserProfile $userProfile -ConversationState $conversationState
}

function Get-ContentType {
    param([string]$Path)

    switch ([System.IO.Path]::GetExtension($Path).ToLowerInvariant()) {
        ".html" { "text/html; charset=utf-8" }
        ".css" { "text/css; charset=utf-8" }
        ".js" { "application/javascript; charset=utf-8" }
        ".json" { "application/json; charset=utf-8" }
        ".png" { "image/png" }
        ".jpg" { "image/jpeg" }
        ".jpeg" { "image/jpeg" }
        ".svg" { "image/svg+xml" }
        default { "text/plain; charset=utf-8" }
    }
}

function Get-StaticFilePath {
    param(
        [string]$Root,
        [string]$RequestPath
    )

    $relativePath = if ([string]::IsNullOrWhiteSpace($RequestPath) -or $RequestPath -eq "/") {
        "index.html"
    } else {
        $RequestPath.TrimStart("/").Replace("/", "\")
    }

    $fullPath = [System.IO.Path]::GetFullPath((Join-Path $Root $relativePath))
    if (-not $fullPath.StartsWith($Root, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $null
    }
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        return $null
    }

    return $fullPath
}

function Read-HttpRequest {
    param([System.IO.Stream]$Stream)

    $headerBytes = New-Object System.Collections.Generic.List[byte]
    $matched = 0
    $delimiter = [byte[]](13, 10, 13, 10)

    while ($true) {
        $value = $Stream.ReadByte()
        if ($value -lt 0) {
            break
        }

        $byteValue = [byte]$value
        $headerBytes.Add($byteValue)

        if ($byteValue -eq $delimiter[$matched]) {
            $matched += 1
            if ($matched -eq 4) {
                break
            }
        } else {
            $matched = if ($byteValue -eq $delimiter[0]) { 1 } else { 0 }
        }
    }

    $headerText = [System.Text.Encoding]::ASCII.GetString($headerBytes.ToArray())
    $headerLines = $headerText -split "`r`n"
    $requestLine = $headerLines[0]
    $headers = @{}

    foreach ($line in $headerLines[1..($headerLines.Length - 1)]) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $idx = $line.IndexOf(":")
        if ($idx -gt 0) {
            $name = $line.Substring(0, $idx).Trim()
            $value = $line.Substring($idx + 1).Trim()
            $headers[$name] = $value
        }
    }

    $body = ""
    if ($headers.ContainsKey("Content-Length")) {
        $contentLength = [int]$headers["Content-Length"]
        if ($contentLength -gt 0) {
            $buffer = New-Object byte[] $contentLength
            $offset = 0
            while ($offset -lt $contentLength) {
                $read = $Stream.Read($buffer, $offset, $contentLength - $offset)
                if ($read -le 0) {
                    break
                }
                $offset += $read
            }
            $body = [System.Text.Encoding]::UTF8.GetString($buffer, 0, $offset)
        }
    }

    return @{
        RequestLine = $requestLine
        Headers = $headers
        Body = $body
    }
}

function Write-BytesResponse {
    param(
        [System.IO.Stream]$Stream,
        [int]$StatusCode,
        [string]$ContentType,
        [byte[]]$BodyBytes
    )

    $statusText = switch ($StatusCode) {
        200 { "OK" }
        404 { "Not Found" }
        500 { "Internal Server Error" }
        default { "OK" }
    }

    $header = "HTTP/1.1 $StatusCode $statusText`r`n" +
        "Content-Type: $ContentType`r`n" +
        "Content-Length: $($BodyBytes.Length)`r`n" +
        "Connection: close`r`n`r`n"
    $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
    $Stream.Write($headerBytes, 0, $headerBytes.Length)
    $Stream.Write($BodyBytes, 0, $BodyBytes.Length)
    $Stream.Flush()
}

function Write-TextResponse {
    param(
        [System.IO.Stream]$Stream,
        [int]$StatusCode,
        [string]$ContentType,
        [string]$Text
    )

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    Write-BytesResponse -Stream $Stream -StatusCode $StatusCode -ContentType $ContentType -BodyBytes $bytes
}

$resolvedWebRoot = (Resolve-Path -LiteralPath $WebRoot).Path
$resolvedEnvFile = (Resolve-Path -LiteralPath $EnvFile).Path
$resolvedPromptTemplate = Resolve-Path -LiteralPath $PromptTemplate -ErrorAction SilentlyContinue
$promptTemplateText = if ($resolvedPromptTemplate) {
    Get-TextFileContent -Path $resolvedPromptTemplate.Path
} else {
    ""
}
$resolvedRagPromptTemplate = Resolve-Path -LiteralPath $RagPromptTemplate -ErrorAction SilentlyContinue
$ragPromptTemplateText = if ($resolvedRagPromptTemplate) {
    Get-TextFileContent -Path $resolvedRagPromptTemplate.Path
} else {
    ""
}
$resolvedVisionPromptTemplate = Resolve-Path -LiteralPath $VisionPromptTemplate -ErrorAction SilentlyContinue
$visionPromptTemplateText = if ($resolvedVisionPromptTemplate) {
    Get-TextFileContent -Path $resolvedVisionPromptTemplate.Path
} else {
    ""
}
$resolvedKnowledgeDir = Resolve-Path -LiteralPath $KnowledgeDir -ErrorAction SilentlyContinue
$knowledgePath = if ($resolvedKnowledgeDir) { $resolvedKnowledgeDir.Path } else { $KnowledgeDir }
$resolvedImageCatalogPath = Resolve-Path -LiteralPath $ImageCatalogPath -ErrorAction SilentlyContinue
$imageCatalogResolvedPath = if ($resolvedImageCatalogPath) { $resolvedImageCatalogPath.Path } else { $ImageCatalogPath }
$resolvedLeadLogPath = Resolve-ProjectRelativePath -ConfiguredPath $LeadLogPath
$resolvedHandoffLogPath = Resolve-ProjectRelativePath -ConfiguredPath $HandoffLogPath
$faqCsvPath = Resolve-FaqCsvPath -ConfiguredPath $FaqCsv
$faqEntries = Get-FaqEntries -Path $faqCsvPath
$imageCatalogEntries = Get-ImageCatalogEntries -Path $imageCatalogResolvedPath
$knowledgeRecords = Get-KnowledgeRecords -Root $knowledgePath
Initialize-SessionStores
$script:SkipPersistence = $false


# ====== Rate limit initialization ======
$resolvedRateLimitPath = Resolve-ProjectRelativePath -ConfiguredPath $RateLimitPath

# ====== Auth state (in-memory) ======
$script:AuthUsers = @{}          # email -> @{id, email, password_hash, nickname, company, phone, created_at, last_login, verified}
$script:AuthCodes = @{}          # email -> @{code, expires_at}
$script:AuthSessions = @{}       # token -> @{email, created_at, expires_at, ip, user_agent}
$script:AuthEmailCooldown = @{}  # email -> DateTime (last send time, to rate-limit email sending)
$script:AuthUserIdCounter = 0

# ====== Device rate limit state (in-memory + file persisted) ======
$script:DeviceRateLimits = @{}

function Initialize-DeviceRateLimits {
    param([string]$FilePath)

    $script:RateLimitFilePath = $FilePath
    $parent = Split-Path -Parent $FilePath
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    if (Test-Path -LiteralPath $FilePath) {
        try {
            $json = Get-Content -LiteralPath $FilePath -Raw -Encoding UTF8
            $data = $json | ConvertFrom-Json
            $now = [DateTime]::UtcNow
            foreach ($entry in $data.PSObject.Properties) {
                $val = $entry.Value
                $firstTime = [DateTime]$val.first_request_time
                if (($now - $firstTime).TotalHours -lt 24) {
                    $script:DeviceRateLimits[$entry.Name] = @{
                        count = [int]$val.count
                        first_request_time = $firstTime
                        blocked = [bool]$val.blocked
                    }
                }
            }
        } catch {
            $script:DeviceRateLimits = @{}
        }
    }
}

Initialize-DeviceRateLimits -FilePath $resolvedRateLimitPath

function Save-DeviceRateLimits {
    if (-not $script:RateLimitFilePath) { return }
    try {
        $data = @{}
        foreach ($key in $script:DeviceRateLimits.Keys) {
            $data[$key] = $script:DeviceRateLimits[$key]
        }
        $json = $data | ConvertTo-Json -Depth 5
        Set-Content -LiteralPath $script:RateLimitFilePath -Value $json -Encoding UTF8
    } catch {
        # Silently ignore save errors
    }
}

function Test-DeviceRateLimit {
    param([string]$ExternalUserId, [string]$UserAgent, [string]$ClientIP)

    $fingerprintRaw = "$UserAgent|$ClientIP"
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($fingerprintRaw))
    $fingerprint = [System.BitConverter]::ToString($hashBytes).Replace("-", "").ToLowerInvariant()
    $sha256.Dispose()

    $now = [DateTime]::UtcNow

    if ($script:DeviceRateLimits.ContainsKey($fingerprint)) {
        $entry = $script:DeviceRateLimits[$fingerprint]
        # Reset if 24 hours have passed since first request
        if (($now - $entry.first_request_time).TotalHours -ge 24) {
            $entry.count = 1
            $entry.first_request_time = $now
            $entry.blocked = $false
        } else {
            $entry.count += 1
        }
        if ($entry.count -gt 5) {
            $entry.blocked = $true
        }
    } else {
        $script:DeviceRateLimits[$fingerprint] = @{
            count = 1
            first_request_time = $now
            blocked = $false
        }
    }

    Save-DeviceRateLimits

    $entry = $script:DeviceRateLimits[$fingerprint]
    return @{
        Blocked = $entry.blocked
        Count = $entry.count
        Remaining = [Math]::Max(0, 5 - $entry.count)
    }
}

function Get-AuthSecret {
    return "yiku-demo-auth-secret-2024"
}

function Get-PasswordHash {
    param([string]$Password)

    $secret = [System.Text.Encoding]::UTF8.GetBytes((Get-AuthSecret))
    $hmac = New-Object System.Security.Cryptography.HMACSHA256
    $hmac.Key = $secret
    $hash = $hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Password))
    return [System.Convert]::ToBase64String($hash)
}

function Test-IsValidEmail {
    param([string]$Email)

    if (-not $Email) {
        return $false
    }

    return $Email -match '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
}

function New-VerificationCode {
    return (Get-Random -Minimum 100000 -Maximum 999999).ToString()
}

function Send-VerificationEmail {
    param([string]$ToEmail, [string]$Code)

    # Rate limit: 60s cooldown per email address
    if ($script:AuthEmailCooldown.ContainsKey($ToEmail)) {
        $elapsed = (Get-Date) - $script:AuthEmailCooldown[$ToEmail]
        if ($elapsed.TotalSeconds -lt 60) {
            $waitSeconds = [math]::Ceiling(60 - $elapsed.TotalSeconds)
            Write-Host "[EMAIL] 频率限制: $ToEmail 需等待 ${waitSeconds}s" -ForegroundColor DarkYellow
            return @{ sent = $false; reason = "rate_limited"; wait_seconds = $waitSeconds }
        }
    }
    $script:AuthEmailCooldown[$ToEmail] = Get-Date

    $smtpServer  = $env:SMTP_SERVER
    $smtpPort    = if ($env:SMTP_PORT) { [int]$env:SMTP_PORT } else { 465 }
    $smtpUser    = $env:SMTP_USER
    $smtpPass    = $env:SMTP_PASS
    $fromEmail   = if ($env:SMTP_FROM) { $env:SMTP_FROM } else { $smtpUser }
    $fromName    = if ($env:SMTP_FROM_NAME) { $env:SMTP_FROM_NAME } else { "广西亿库硅藻板" }

    # SMTP not configured → fall back to console log
    if (-not $smtpServer -or -not $smtpUser -or -not $smtpPass) {
        Write-Host "===== [AUTH] 验证码（$ToEmail）：$Code =====" -ForegroundColor Yellow
        Write-Host "[EMAIL] SMTP 未配置，验证码已输出到控制台" -ForegroundColor DarkYellow
        return @{ sent = $false; reason = "smtp_not_configured" }
    }

    try {
        $mail = New-Object System.Net.Mail.MailMessage
        $mail.From = New-Object System.Net.Mail.MailAddress($fromEmail, $fromName)
        $mail.To.Add($ToEmail)
        $mail.Subject = "邮箱验证码 - 广西亿库硅藻板"
        $mail.Body = @"
您好！

您的验证码是：$Code

该验证码 10 分钟内有效。如非本人操作，请忽略此邮件。

——
广西亿库光养硅藻环保科技有限公司
"@
        $mail.BodyEncoding = [System.Text.Encoding]::UTF8
        $mail.SubjectEncoding = [System.Text.Encoding]::UTF8
        $mail.IsBodyHtml = $false

        $smtp = New-Object System.Net.Mail.SmtpClient($smtpServer, $smtpPort)
        $smtp.EnableSsl = $true
        $smtp.DeliveryMethod = [System.Net.Mail.SmtpDeliveryMethod]::Network
        $smtp.Credentials = New-Object System.Net.NetworkCredential($smtpUser, $smtpPass)
        $smtp.Timeout = 10000
        $smtp.Send($mail)

        $mail.Dispose()
        $smtp.Dispose()

        Write-Host "[EMAIL] 验证码已发送至 $ToEmail" -ForegroundColor Green
        return @{ sent = $true }
    }
    catch {
        Write-Host "[EMAIL] 发送失败: $_" -ForegroundColor Red
        Write-Host "===== [AUTH] 验证码（$ToEmail）：$Code =====" -ForegroundColor Yellow
        return @{ sent = $false; reason = $_.Exception.Message }
    }
}

function New-AuthToken {
    return [guid]::NewGuid().ToString("N")
}

function Get-AuthUserByToken {
    param([string]$Token)

    if (-not $Token -or -not $script:AuthSessions.ContainsKey($Token)) {
        return $null
    }

    $session = $script:AuthSessions[$Token]
    if ((Get-Date).ToUniversalTime() -gt [DateTime]$session.expires_at) {
        $script:AuthSessions.Remove($Token)
        return $null
    }

    $email = $session.email
    if (-not $script:AuthUsers.ContainsKey($email)) {
        return $null
    }

    return $script:AuthUsers[$email]
}

function Get-AuthHeaderValue {
    param($Headers)

    if ($Headers.ContainsKey("Authorization")) {
        return $Headers["Authorization"]
    }
    if ($Headers.ContainsKey("authorization")) {
        return $Headers["authorization"]
    }
    return ""
}

function Write-AuthJsonResponse {
    param(
        [System.IO.Stream]$Stream,
        [int]$StatusCode,
        [string]$Json
    )

    $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($Json)
    $statusText = switch ($StatusCode) {
        200 { "OK" }
        201 { "Created" }
        400 { "Bad Request" }
        401 { "Unauthorized" }
        default { "OK" }
    }

    $header = "HTTP/1.1 $StatusCode $statusText`r`n" +
        "Content-Type: application/json; charset=utf-8`r`n" +
        "Content-Length: $($bodyBytes.Length)`r`n" +
        "Access-Control-Allow-Origin: *`r`n" +
        "Access-Control-Allow-Methods: GET, POST, OPTIONS`r`n" +
        "Access-Control-Allow-Headers: Content-Type, Authorization`r`n" +
        "Connection: close`r`n`r`n"
    $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
    $Stream.Write($headerBytes, 0, $headerBytes.Length)
    $Stream.Write($bodyBytes, 0, $bodyBytes.Length)
    $Stream.Flush()
}

$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Parse("127.0.0.1"), $Port)
$listener.Start()
Write-Output "Demo server listening at http://127.0.0.1:$Port/"

while ($true) {
    $client = $listener.AcceptTcpClient()

    try {
        $stream = $client.GetStream()
        $request = Read-HttpRequest -Stream $stream
        $requestLine = $request.RequestLine
        if (-not $requestLine) {
            $client.Close()
            continue
        }

        $parts = $requestLine.Split(" ")
        $method = $parts[0]
        $path = $parts[1]

        if ($method -eq "POST" -and $path -eq "/api/ai/chat") {
            $payload = if ($request.Body) { $request.Body | ConvertFrom-Json } else { $null }
            $channel = if ($payload -and $payload.channel) { [string]$payload.channel } else { "web" }
            $externalUserId = if ($payload -and $payload.externalUserId) { [string]$payload.externalUserId } else { "anonymous-web-user" }
            $conversationId = if ($payload -and $payload.conversationId) { [string]$payload.conversationId } else { "default-conversation" }
            $sessionId = if ($payload -and $payload.sessionId) { [string]$payload.sessionId } else { "default-session" }
            $question = if ($payload -and $payload.question) { [string]$payload.question } else { "" }
            $history = if ($payload -and $payload.history) { @(ConvertTo-Hashtable -Value $payload.history) } else { @() }
            $imageDataUrl = if ($payload -and $payload.imageDataUrl) { [string]$payload.imageDataUrl } else { "" }
            $imageName = if ($payload -and $payload.imageName) { [string]$payload.imageName } else { "" }
            $modelOverride = if ($payload -and $payload.modelOverride) { [string]$payload.modelOverride } else { "" }

            # ====== Device rate limit for unauthenticated users ======
            $authHeader = Get-AuthHeaderValue -Headers $request.Headers
            $isLoggedIn = $false
            if ($authHeader -match "^Bearer\s+(.+)$") {
                $authToken = $Matches[1]
                $authUser = Get-AuthUserByToken -Token $authToken
                if ($authUser) {
                    $isLoggedIn = $true
                }
            }

            if (-not $isLoggedIn) {
                $userAgent = if ($request.Headers.ContainsKey("User-Agent")) { $request.Headers["User-Agent"] } else { "unknown" }
                $clientIP = ""
                if ($request.Headers.ContainsKey("X-Forwarded-For")) {
                    $clientIP = ($request.Headers["X-Forwarded-For"] -split ",")[0].Trim()
                } elseif ($request.Headers.ContainsKey("X-Real-IP")) {
                    $clientIP = $request.Headers["X-Real-IP"]
                } else {
                    $clientIP = "127.0.0.1"
                }

                $rateResult = Test-DeviceRateLimit -ExternalUserId $externalUserId -UserAgent $userAgent -ClientIP $clientIP
                if ($rateResult.Blocked) {
                    $rateLimitJson = (@{
                        error = "login_required"
                        message = "免费咨询次数已用完，请登录后继续"
                        remaining = 0
                    } | ConvertTo-Json)
                    Write-TextResponse -Stream $stream -StatusCode 200 -ContentType "application/json; charset=utf-8" -Text $rateLimitJson
                    $client.Close()
                    continue
                }
            }
            # ====== End rate limit check ======

            $script:SkipPersistence = (-not $isLoggedIn)

            $chat = Get-ChatAnswer -Channel $channel -ExternalUserId $externalUserId -ConversationId $conversationId -SessionId $sessionId -Question $question -History $history -ImageDataUrl $imageDataUrl -ImageName $imageName -ModelOverride $modelOverride -EnvFilePath $resolvedEnvFile -FaqEntries $faqEntries -ImageCatalogEntries $imageCatalogEntries -KnowledgeRecords $knowledgeRecords -PromptTemplateText $promptTemplateText -RagPromptTemplateText $ragPromptTemplateText -VisionPromptTemplateText $visionPromptTemplateText -IsLoggedIn $isLoggedIn
            $json = $chat | ConvertTo-Json -Depth 8
            Write-TextResponse -Stream $stream -StatusCode 200 -ContentType "application/json; charset=utf-8" -Text $json
            $client.Close()
            continue
        }

        if ($method -eq "GET" -and $path -eq "/api/admin/runtime-config") {
            $envMap = Get-EnvMap -Path $resolvedEnvFile
            $json = (Get-AdminRuntimeConfigResponse -EnvMap $envMap) | ConvertTo-Json -Depth 6
            Write-TextResponse -Stream $stream -StatusCode 200 -ContentType "application/json; charset=utf-8" -Text $json
            $client.Close()
            continue
        }

        if ($method -eq "POST" -and $path -eq "/api/ai/lead") {
            $payload = if ($request.Body) { ConvertTo-Hashtable -Value ($request.Body | ConvertFrom-Json) } else { @{} }
            $json = (New-RequestCaptureResponse -Kind "lead" -Payload $payload -LogPath $resolvedLeadLogPath) | ConvertTo-Json -Depth 6
            Write-TextResponse -Stream $stream -StatusCode 200 -ContentType "application/json; charset=utf-8" -Text $json
            $client.Close()
            continue
        }

        if ($method -eq "POST" -and $path -eq "/api/ai/handoff") {
            $payload = if ($request.Body) { ConvertTo-Hashtable -Value ($request.Body | ConvertFrom-Json) } else { @{} }
            $json = (New-RequestCaptureResponse -Kind "handoff" -Payload $payload -LogPath $resolvedHandoffLogPath) | ConvertTo-Json -Depth 6
            Write-TextResponse -Stream $stream -StatusCode 200 -ContentType "application/json; charset=utf-8" -Text $json
            $client.Close()
            continue
        }

        # ====== Auth routes ======

        # CORS preflight for auth routes
        if ($method -eq "OPTIONS") {
            $corsHeaders = "HTTP/1.1 204 No Content`r`n" +
                "Access-Control-Allow-Origin: *`r`n" +
                "Access-Control-Allow-Methods: GET, POST, OPTIONS`r`n" +
                "Access-Control-Allow-Headers: Content-Type, Authorization`r`n" +
                "Connection: close`r`n`r`n"
            $corsBytes = [System.Text.Encoding]::ASCII.GetBytes($corsHeaders)
            $stream.Write($corsBytes, 0, $corsBytes.Length)
            $stream.Flush()
            $client.Close()
            continue
        }

        # POST /api/auth/register
        if ($method -eq "POST" -and $path -eq "/api/auth/register") {
            $body = if ($request.Body) { $request.Body | ConvertFrom-Json } else { $null }
            $email = if ($body -and $body.email) { [string]$body.email } else { "" }
            $password = if ($body -and $body.password) { [string]$body.password } else { "" }
            $nickname = if ($body -and $body.nickname) { [string]$body.nickname } else { "" }

            if (-not (Test-IsValidEmail -Email $email)) {
                $json = (@{ok = $false; message = "邮箱格式不正确"} | ConvertTo-Json -Compress)
                Write-AuthJsonResponse -Stream $stream -StatusCode 400 -Json $json
                $client.Close()
                continue
            }

            if ($password.Length -lt 6) {
                $json = (@{ok = $false; message = "密码至少 6 位"} | ConvertTo-Json -Compress)
                Write-AuthJsonResponse -Stream $stream -StatusCode 400 -Json $json
                $client.Close()
                continue
            }

            # Re-register: if already registered and verified, reject; if unverified, resend code
            if ($script:AuthUsers.ContainsKey($email)) {
                $existing = $script:AuthUsers[$email]
                if ($existing.verified) {
                    $json = (@{ok = $false; message = "该邮箱已注册"} | ConvertTo-Json -Compress)
                    Write-AuthJsonResponse -Stream $stream -StatusCode 400 -Json $json
                } else {
                    $code = New-VerificationCode
                    $script:AuthCodes[$email] = @{
                        code = $code
                        expires_at = (Get-Date).ToUniversalTime().AddMinutes(10)
                    }
                    $script:AuthUsers[$email].password_hash = Get-PasswordHash -Password $password
                    if ($nickname) { $script:AuthUsers[$email].nickname = $nickname }
                    $sendResult = Send-VerificationEmail -ToEmail $email -Code $code
                    if ($sendResult.sent) {
                        $json = (@{ok = $true; message = "验证码已重新发送至您的邮箱"} | ConvertTo-Json -Compress)
                    } elseif ($sendResult.reason -eq "rate_limited") {
                        $json = (@{ok = $false; message = "发送太频繁，请 $($sendResult.wait_seconds) 秒后再试"} | ConvertTo-Json -Compress)
                    } else {
                        $json = (@{ok = $true; message = "验证码已重新发送（查看服务器日志）"} | ConvertTo-Json -Compress)
                    }
                    Write-AuthJsonResponse -Stream $stream -StatusCode 200 -Json $json
                }
                $client.Close()
                continue
            }

            # New user
            $script:AuthUserIdCounter += 1
            $code = New-VerificationCode
            $now = Get-NowIsoString
            $userRecord = @{
                id = $script:AuthUserIdCounter
                email = $email
                password_hash = Get-PasswordHash -Password $password
                nickname = if ($nickname) { $nickname } else { "" }
                company = ""
                phone = ""
                created_at = $now
                last_login = $null
                verified = $false
            }
            $script:AuthUsers[$email] = $userRecord
            $script:AuthCodes[$email] = @{
                code = $code
                expires_at = (Get-Date).ToUniversalTime().AddMinutes(10)
            }
            $sendResult = Send-VerificationEmail -ToEmail $email -Code $code
            if ($sendResult.sent) {
                $json = (@{ok = $true; message = "验证码已发送至您的邮箱，请查收"} | ConvertTo-Json -Compress)
            } elseif ($sendResult.reason -eq "rate_limited") {
                $json = (@{ok = $false; message = "发送太频繁，请 $($sendResult.wait_seconds) 秒后再试"} | ConvertTo-Json -Compress)
            } else {
                $json = (@{ok = $true; message = "验证码已发送（查看服务器日志）"} | ConvertTo-Json -Compress)
            }
            Write-AuthJsonResponse -Stream $stream -StatusCode 200 -Json $json
            $client.Close()
            continue
        }

        # POST /api/auth/verify
        if ($method -eq "POST" -and $path -eq "/api/auth/verify") {
            $body = if ($request.Body) { $request.Body | ConvertFrom-Json } else { $null }
            $email = if ($body -and $body.email) { [string]$body.email } else { "" }
            $code = if ($body -and $body.code) { [string]$body.code } else { "" }

            if (-not $email -or -not $script:AuthUsers.ContainsKey($email)) {
                $json = (@{ok = $false; message = "该邮箱未注册"} | ConvertTo-Json -Compress)
                Write-AuthJsonResponse -Stream $stream -StatusCode 400 -Json $json
                $client.Close()
                continue
            }

            if (-not $script:AuthCodes.ContainsKey($email)) {
                $json = (@{ok = $false; message = "请先获取验证码"} | ConvertTo-Json -Compress)
                Write-AuthJsonResponse -Stream $stream -StatusCode 400 -Json $json
                $client.Close()
                continue
            }

            $stored = $script:AuthCodes[$email]
            if ((Get-Date).ToUniversalTime() -gt [DateTime]$stored.expires_at) {
                $script:AuthCodes.Remove($email)
                $json = (@{ok = $false; message = "验证码已过期，请重新获取"} | ConvertTo-Json -Compress)
                Write-AuthJsonResponse -Stream $stream -StatusCode 400 -Json $json
                $client.Close()
                continue
            }

            if ($stored.code -ne $code) {
                $json = (@{ok = $false; message = "验证码错误"} | ConvertTo-Json -Compress)
                Write-AuthJsonResponse -Stream $stream -StatusCode 400 -Json $json
                $client.Close()
                continue
            }

            # Activate user and create session
            $user = $script:AuthUsers[$email]
            $user.verified = $true
            $user.last_login = Get-NowIsoString
            $script:AuthCodes.Remove($email)

            $token = New-AuthToken
            $script:AuthSessions[$token] = @{
                email = $email
                created_at = Get-NowIsoString
                expires_at = (Get-Date).ToUniversalTime().AddDays(7)
                ip = ""
                user_agent = ""
            }

            $json = (@{
                ok = $true
                token = $token
                user = @{email = $user.email; nickname = $user.nickname}
            } | ConvertTo-Json -Compress)
            Write-AuthJsonResponse -Stream $stream -StatusCode 200 -Json $json
            $client.Close()
            continue
        }

        # POST /api/auth/login
        if ($method -eq "POST" -and $path -eq "/api/auth/login") {
            $body = if ($request.Body) { $request.Body | ConvertFrom-Json } else { $null }
            $email = if ($body -and $body.email) { [string]$body.email } else { "" }
            $password = if ($body -and $body.password) { [string]$body.password } else { "" }

            if (-not $email -or -not $script:AuthUsers.ContainsKey($email)) {
                $json = (@{ok = $false; message = "邮箱或密码错误"} | ConvertTo-Json -Compress)
                Write-AuthJsonResponse -Stream $stream -StatusCode 401 -Json $json
                $client.Close()
                continue
            }

            $user = $script:AuthUsers[$email]
            if (-not $user.verified) {
                $json = (@{ok = $false; message = "请先验证邮箱"} | ConvertTo-Json -Compress)
                Write-AuthJsonResponse -Stream $stream -StatusCode 401 -Json $json
                $client.Close()
                continue
            }

            $hash = Get-PasswordHash -Password $password
            if ($hash -ne $user.password_hash) {
                $json = (@{ok = $false; message = "邮箱或密码错误"} | ConvertTo-Json -Compress)
                Write-AuthJsonResponse -Stream $stream -StatusCode 401 -Json $json
                $client.Close()
                continue
            }

            $user.last_login = Get-NowIsoString
            $token = New-AuthToken
            $script:AuthSessions[$token] = @{
                email = $email
                created_at = Get-NowIsoString
                expires_at = (Get-Date).ToUniversalTime().AddDays(7)
                ip = ""
                user_agent = ""
            }

            $json = (@{
                ok = $true
                token = $token
                user = @{email = $user.email; nickname = $user.nickname}
            } | ConvertTo-Json -Compress)
            Write-AuthJsonResponse -Stream $stream -StatusCode 200 -Json $json
            $client.Close()
            continue
        }

        # GET /api/auth/me
        if ($method -eq "GET" -and $path -eq "/api/auth/me") {
            $authHeader = Get-AuthHeaderValue -Headers $request.Headers
            $token = ""
            if ($authHeader -match "^Bearer\s+(.+)$") {
                $token = $Matches[1]
            }

            if (-not $token) {
                $json = (@{ok = $false; message = "未提供 token"} | ConvertTo-Json -Compress)
                Write-AuthJsonResponse -Stream $stream -StatusCode 401 -Json $json
                $client.Close()
                continue
            }

            $user = Get-AuthUserByToken -Token $token
            if (-not $user) {
                $json = (@{ok = $false; message = "token 无效或已过期"} | ConvertTo-Json -Compress)
                Write-AuthJsonResponse -Stream $stream -StatusCode 401 -Json $json
                $client.Close()
                continue
            }

            $json = (@{
                ok = $true
                user = @{
                    email = $user.email
                    nickname = $user.nickname
                    company = $user.company
                    phone = $user.phone
                    created_at = $user.created_at
                }
            } | ConvertTo-Json -Compress)
            Write-AuthJsonResponse -Stream $stream -StatusCode 200 -Json $json
            $client.Close()
            continue
        }

        if ($method -eq "GET" -and $path.StartsWith("/api/media?", [System.StringComparison]::OrdinalIgnoreCase)) {
            $media = Get-ProxiedMediaResponse -RequestPath $path -EnvMap (Get-EnvMap -Path $resolvedEnvFile)
            if ($media.ContainsKey("Bytes")) {
                Write-BytesResponse -Stream $stream -StatusCode $media.StatusCode -ContentType $media.ContentType -BodyBytes $media.Bytes
            } else {
                Write-TextResponse -Stream $stream -StatusCode $media.StatusCode -ContentType $media.ContentType -Text $media.Text
            }
            $client.Close()
            continue
        }

        $staticFile = Get-StaticFilePath -Root $resolvedWebRoot -RequestPath $path
        if ($null -eq $staticFile) {
            Write-TextResponse -Stream $stream -StatusCode 404 -ContentType "text/plain; charset=utf-8" -Text "Not Found"
            $client.Close()
            continue
        }

        $bytes = [System.IO.File]::ReadAllBytes($staticFile)
        Write-BytesResponse -Stream $stream -StatusCode 200 -ContentType (Get-ContentType -Path $staticFile) -BodyBytes $bytes
        $client.Close()
    } catch {
        try {
            if ($client.Connected) {
                Write-TextResponse -Stream $client.GetStream() -StatusCode 500 -ContentType "text/plain; charset=utf-8" -Text $_.Exception.Message
            }
        } catch {
        }
        $client.Close()
    }
}
