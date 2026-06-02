"""为 demo-server.ps1 添加 /api/agent/join-conversation 路由"""
PATH = "/opt/AI1/scripts/demo-server.ps1"
with open(PATH, "r") as f:
    content = f.read()

# 在 POST /api/agent/join 之前插入新路由
old = "        # POST /api/agent/join（坐席接入）"
new = """        # POST /api/agent/join-conversation（坐席主动接入会话）
        if ($method -eq "POST" -and $path -eq "/api/agent/join-conversation") {
            $token = (Get-AuthHeaderValue -Headers $request.Headers) -replace "^Bearer ", ""
            if (-not $script:AgentSessions.ContainsKey($token)) { $json = (@{ ok = $false; message = "未登录" } | ConvertTo-Json -Compress); Write-AuthJsonResponse -Stream $stream -StatusCode 401 -Json $json; $client.Close(); continue }
            $body = if ($request.Body) { $request.Body | ConvertFrom-Json -Depth 10 } else { $null }
            if (-not $body -or -not $body.conversationId) { $json = (@{ ok = $false } | ConvertTo-Json -Compress); Write-AuthJsonResponse -Stream $stream -StatusCode 400 -Json $json; $client.Close(); continue }
            $hid = "handoff-" + [guid]::NewGuid().ToString("N").Substring(0, 12)
            $agent = $script:AgentSessions[$token]
            $script:HandoffQueue[$hid] = @{
                userId = [string]$body.conversationId; conversationId = [string]$body.conversationId
                reason = "坐席主动接入"; messages = @()
                agent = $agent.name; status = "active"; createdAt = [DateTime]::UtcNow.ToString("o")
            }
            # 带聊天历史
            if ($body.history) {
                foreach ($hmsg in $body.history) {
                    $entry = @{ role = [string]$hmsg.role; text = [string]$hmsg.text; time = [DateTime]::UtcNow.ToString("HH:mm") }
                    if ($hmsg.imageUrl) { $entry["imageUrl"] = [string]$hmsg.imageUrl }
                    $script:HandoffQueue[$hid].messages += $entry
                }
            }
            $script:HandoffQueue[$hid].messages += @{ role = "system"; text = "坐席 " + $agent.name + " 已接入"; time = [DateTime]::UtcNow.ToString("HH:mm") }
            Save-HandoffQueue
            $json = (@{ ok = $true; handoffId = $hid; messages = @($script:HandoffQueue[$hid].messages) } | ConvertTo-Json -Compress)
            Write-AuthJsonResponse -Stream $stream -StatusCode 200 -Json $json; $client.Close(); continue
        }

        # POST /api/agent/join（坐席接入）"""

content = content.replace(old, new)
print(f"Inserted: {1 if old in content else 0}")
with open(PATH, "w") as f:
    f.write(content)
print("Done")
