"""在 demo-server.ps1 中插入完整的人工接管系统"""

with open("/opt/AI1/scripts/demo-server.ps1", "r") as f:
    content = f.read()

# 1. 初始化 handoff 变量（在 AgentSessions 旁边）
old_init = "$script:AgentSessions = @{}  # agent后台登录session"
new_init = """$script:AgentSessions = @{}  # agent后台登录session
$script:HandoffQueue = @{}    # handoffId -> @{userId, conversationId, reason, messages, agent, status, createdAt}
$script:HandoffFile = "/opt/AI1/data/runtime/handoff_queue.json"
$script:WorkStart1 = "08:30"; $script:WorkEnd1 = "11:30"
$script:WorkStart2 = "13:30"; $script:WorkEnd2 = "17:30" """
content = content.replace(old_init, new_init)

# 2. 在 rate limits 初始化后加载 handoff 数据
old_rate = """if (Test-Path -LiteralPath $script:AuthUsersFile) {"""
new_rate = """# === 从文件加载 handoff 队列 ===
$script:HandoffQueue = @{}
if (Test-Path -LiteralPath $script:HandoffFile) {
    try {
        $raw = Get-Content $script:HandoffFile -Raw -Encoding UTF8
        $data = $raw | ConvertFrom-Json
        foreach ($prop in $data.PSObject.Properties) {
            $v = $prop.Value
            $script:HandoffQueue[$prop.Name] = @{
                userId = $v.userId; conversationId = $v.conversationId
                reason = $v.reason; messages = @($v.messages)
                agent = $v.agent; status = $v.status; createdAt = $v.createdAt
            }
        }
    } catch { $script:HandoffQueue = @{} }
}

if (Test-Path -LiteralPath $script:AuthUsersFile) {"""
content = content.replace(old_rate, new_rate)

# 3. Save-HandoffQueue 函数（在 Save-AuthUsers 之后）
old_save = "function Test-DeviceRateLimit {"
new_save = """function Save-HandoffQueue {
    if (-not $script:HandoffFile) { return }
    try {
        $data = @{}
        foreach ($key in $script:HandoffQueue.Keys) {
            $val = $script:HandoffQueue[$key]
            $data[$key] = @{
                userId = $val.userId; conversationId = $val.conversationId
                reason = $val.reason; messages = @($val.messages)
                agent = $val.agent; status = $val.status; createdAt = $val.createdAt
            }
        }
        $dir = Split-Path -Parent $script:HandoffFile
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $json = $data | ConvertTo-Json -Depth 6
        Set-Content -LiteralPath $script:HandoffFile -Value $json -Encoding UTF8
    } catch { }
}

# 判断是否工作时间
function Test-WorkHours {
    $now = [DateTime]::Now
    $day = $now.DayOfWeek
    if ($day -eq "Saturday" -or $day -eq "Sunday") { return $false }
    $t = $now.ToString("HH:mm")
    return ($t -ge $script:WorkStart1 -and $t -le $script:WorkEnd1) -or ($t -ge $script:WorkStart2 -and $t -le $script:WorkEnd2)
}

function Get-WorkHoursMessage {
    $now = [DateTime]::Now
    $t = $now.ToString("HH:mm")
    if ($now.DayOfWeek -eq "Saturday" -or $now.DayOfWeek -eq "Sunday") { return "今天是周末，顾问休息。工作日 8:30-11:30 / 13:30-17:30 在线，请工作时间再来，或拨打电话 0779-8525688。" }
    if ($t -lt $script:WorkStart1) { return "顾问 8:30 上班，请稍等一会儿，或拨打电话 0779-8525688。" }
    if ($t -gt $script:WorkEnd1 -and $t -lt $script:WorkStart2) { return "现在是午休时间，顾问 13:30 上班，请下午再来，或拨打电话 0779-8525688。" }
    if ($t -gt $script:WorkEnd2) { return "顾问已下班，工作日 8:30-11:30 / 13:30-17:30 在线，请明天再来，或拨打电话 0779-8525688。" }
    return ""
}

function Test-DeviceRateLimit {"""
content = content.replace(old_save, new_save)

# 4. 在 agent me API 后插入 handoff APIs
old_api = """        # GET /api/agent/conversations"""

new_api = """        # POST /api/ai/handoff（用户请求转人工）
        if ($method -eq "POST" -and $path -eq "/api/ai/handoff") {
            $body = if ($request.Body) { $request.Body | ConvertFrom-Json } else { $null }
            if (-not $body) { $json = (@{ ok = $false } | ConvertTo-Json -Compress); Write-AuthJsonResponse -Stream $stream -StatusCode 400 -Json $json; $client.Close(); continue }
            if (-not (Test-WorkHours)) {
                $msg = Get-WorkHoursMessage
                $json = (@{ ok = $false; offline = $true; message = $msg } | ConvertTo-Json -Compress)
                Write-AuthJsonResponse -Stream $stream -StatusCode 200 -Json $json; $client.Close(); continue
            }
            $hid = "handoff-" + [guid]::NewGuid().ToString("N").Substring(0, 12)
            $script:HandoffQueue[$hid] = @{
                userId = [string]$body.userId; conversationId = [string]$body.conversationId
                reason = [string]$body.reason; messages = @()
                agent = ""; status = "pending"; createdAt = [DateTime]::UtcNow.ToString("o")
            }
            Save-HandoffQueue
            $json = (@{ ok = $true; handoffId = $hid; message = "已通知顾问，请稍候。工作时间内通常 1-2 分钟响应。" } | ConvertTo-Json -Compress)
            Write-AuthJsonResponse -Stream $stream -StatusCode 200 -Json $json; $client.Close(); continue
        }

        # GET /api/ai/handoff-status?id=xxx（用户轮询是否被接入）
        if ($method -eq "GET" -and $path.StartsWith("/api/ai/handoff-status")) {
            $hid = ""; if ($path -match "id=([^&]+)") { $hid = $Matches[1] }
            if (-not $script:HandoffQueue.ContainsKey($hid)) { $json = (@{ ok = $false; message = "工单不存在" } | ConvertTo-Json -Compress); Write-AuthJsonResponse -Stream $stream -StatusCode 404 -Json $json; $client.Close(); continue }
            $h = $script:HandoffQueue[$hid]
            $json = (@{ ok = $true; status = $h.status; agent = $h.agent; messages = @($h.messages) } | ConvertTo-Json -Compress)
            Write-AuthJsonResponse -Stream $stream -StatusCode 200 -Json $json; $client.Close(); continue
        }

        # POST /api/ai/handoff-message（用户发消息到已接管的会话）
        if ($method -eq "POST" -and $path -eq "/api/ai/handoff-message") {
            $body = if ($request.Body) { $request.Body | ConvertFrom-Json } else { $null }
            if (-not $body -or -not $script:HandoffQueue.ContainsKey($body.handoffId)) { $json = (@{ ok = $false } | ConvertTo-Json -Compress); Write-AuthJsonResponse -Stream $stream -StatusCode 400 -Json $json; $client.Close(); continue }
            $h = $script:HandoffQueue[$body.handoffId]
            $imageUrl = ""
            if ($body.imageDataUrl) {
                $imageUrl = Save-ImageDataUrlToPublicStorage -ImageDataUrl ([string]$body.imageDataUrl) -ImageName ([string]$body.imageName)
                if (-not $imageUrl) { $imageUrl = "" }
            }
            $msg = @{ role = "user"; text = [string]$body.text; time = [DateTime]::UtcNow.ToString("HH:mm") }
            if ($imageUrl) { $msg["imageUrl"] = $imageUrl }
            $h.messages += $msg
            Save-HandoffQueue
            $json = (@{ ok = $true } | ConvertTo-Json -Compress); Write-AuthJsonResponse -Stream $stream -StatusCode 200 -Json $json; $client.Close(); continue
        }

        # GET /api/agent/handoff-queue（坐席看待接入列表）
        if ($method -eq "GET" -and $path -eq "/api/agent/handoff-queue") {
            $token = (Get-AuthHeaderValue -Headers $request.Headers) -replace "^Bearer ", ""
            if (-not $script:AgentSessions.ContainsKey($token)) { $json = (@{ ok = $false; message = "未登录" } | ConvertTo-Json -Compress); Write-AuthJsonResponse -Stream $stream -StatusCode 401 -Json $json; $client.Close(); continue }
            $queue = @()
            foreach ($key in $script:HandoffQueue.Keys) {
                $h = $script:HandoffQueue[$key]
                if ($h.status -eq "pending" -or $h.status -eq "active") {
                    $queue += @{ id = $key; userId = $h.userId; reason = $h.reason; status = $h.status; agent = $h.agent; messageCount = $h.messages.Count }
                }
            }
            $json = (@{ ok = $true; queue = @($queue); isWorkHours = (Test-WorkHours) } | ConvertTo-Json -Compress)
            Write-AuthJsonResponse -Stream $stream -StatusCode 200 -Json $json; $client.Close(); continue
        }

        # POST /api/agent/join（坐席接入）
        if ($method -eq "POST" -and $path -eq "/api/agent/join") {
            $token = (Get-AuthHeaderValue -Headers $request.Headers) -replace "^Bearer ", ""
            if (-not $script:AgentSessions.ContainsKey($token)) { $json = (@{ ok = $false; message = "未登录" } | ConvertTo-Json -Compress); Write-AuthJsonResponse -Stream $stream -StatusCode 401 -Json $json; $client.Close(); continue }
            $body = if ($request.Body) { $request.Body | ConvertFrom-Json } else { $null }
            if (-not $body -or -not $script:HandoffQueue.ContainsKey($body.handoffId)) { $json = (@{ ok = $false } | ConvertTo-Json -Compress); Write-AuthJsonResponse -Stream $stream -StatusCode 400 -Json $json; $client.Close(); continue }
            $h = $script:HandoffQueue[$body.handoffId]
            $agent = $script:AgentSessions[$token]
            $h.agent = $agent.name; $h.status = "active"
            $h.messages += @{ role = "system"; text = "坐席 " + $agent.name + " 已接入"; time = [DateTime]::UtcNow.ToString("HH:mm") }
            Save-HandoffQueue
            $json = (@{ ok = $true; messages = @($h.messages) } | ConvertTo-Json -Compress)
            Write-AuthJsonResponse -Stream $stream -StatusCode 200 -Json $json; $client.Close(); continue
        }

        # POST /api/agent/reply（坐席回复）
        if ($method -eq "POST" -and $path -eq "/api/agent/reply") {
            $token = (Get-AuthHeaderValue -Headers $request.Headers) -replace "^Bearer ", ""
            if (-not $script:AgentSessions.ContainsKey($token)) { $json = (@{ ok = $false; message = "未登录" } | ConvertTo-Json -Compress); Write-AuthJsonResponse -Stream $stream -StatusCode 401 -Json $json; $client.Close(); continue }
            $body = if ($request.Body) { $request.Body | ConvertFrom-Json } else { $null }
            if (-not $body -or -not $script:HandoffQueue.ContainsKey($body.handoffId)) { $json = (@{ ok = $false } | ConvertTo-Json -Compress); Write-AuthJsonResponse -Stream $stream -StatusCode 400 -Json $json; $client.Close(); continue }
            $h = $script:HandoffQueue[$body.handoffId]
            $imageUrl = ""
            if ($body.imageDataUrl) {
                $imageUrl = Save-ImageDataUrlToPublicStorage -ImageDataUrl ([string]$body.imageDataUrl) -ImageName ([string]$body.imageName)
                if (-not $imageUrl) { $imageUrl = "" }
            }
            $msg = @{ role = "agent"; text = [string]$body.text; time = [DateTime]::UtcNow.ToString("HH:mm") }
            if ($imageUrl) { $msg["imageUrl"] = $imageUrl }
            $h.messages += $msg
            Save-HandoffQueue
            $json = (@{ ok = $true } | ConvertTo-Json -Compress)
            Write-AuthJsonResponse -Stream $stream -StatusCode 200 -Json $json; $client.Close(); continue
        }

        # POST /api/agent/finish（坐席结束接管）
        if ($method -eq "POST" -and $path -eq "/api/agent/finish") {
            $token = (Get-AuthHeaderValue -Headers $request.Headers) -replace "^Bearer ", ""
            if (-not $script:AgentSessions.ContainsKey($token)) { $json = (@{ ok = $false } | ConvertTo-Json -Compress); Write-AuthJsonResponse -Stream $stream -StatusCode 401 -Json $json; $client.Close(); continue }
            $body = if ($request.Body) { $request.Body | ConvertFrom-Json } else { $null }
            if (-not $body -or -not $script:HandoffQueue.ContainsKey($body.handoffId)) { $json = (@{ ok = $false } | ConvertTo-Json -Compress); Write-AuthJsonResponse -Stream $stream -StatusCode 400 -Json $json; $client.Close(); continue }
            $script:HandoffQueue[$body.handoffId].status = "completed"
            Save-HandoffQueue
            $json = (@{ ok = $true } | ConvertTo-Json -Compress)
            Write-AuthJsonResponse -Stream $stream -StatusCode 200 -Json $json; $client.Close(); continue
        }

        # GET /api/agent/conversations"""

content = content.replace(old_api, new_api)

with open("/opt/AI1/scripts/demo-server.ps1", "w") as f:
    f.write(content)
print("done - handoff APIs inserted")
