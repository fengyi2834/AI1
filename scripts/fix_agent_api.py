"""改进 conversations API：返回更多字段 + 新增消息详情 API"""

with open("/opt/AI1/scripts/demo-server.ps1", "r") as f:
    content = f.read()

# 1. 改进 conversations 路由，返回更多信息
old_conv = '''            $convs = @()
            foreach ($key in $script:SessionHistories.Keys) {
                $state = $script:SessionHistories[$key]
                $lastMsg = ""
                if ($state.turns.Count -gt 0) {
                    $lastTurn = $state.turns[-1]
                    $lastMsg = $lastTurn.text.Substring(0, [Math]::Min(50, $lastTurn.text.Length))
                }
                $convs += @{
                    id = $key
                    channel = $state.channel
                    userId = $state.external_user_id
                    messageCount = $state.turns.Count
                    preview = $lastMsg
                }
            }'''

new_conv = '''            $convs = @()
            foreach ($key in $script:SessionHistories.Keys) {
                $state = $script:SessionHistories[$key]
                $lastMsg = ""
                $lastRole = ""
                if ($state.turns.Count -gt 0) {
                    $lastTurn = $state.turns[-1]
                    $lastMsg = $lastTurn.text.Substring(0, [Math]::Min(80, $lastTurn.text.Length))
                    $lastRole = $lastTurn.role
                }
                $displayName = $state.external_user_id
                if ($displayName.Length -gt 16) { $displayName = $displayName.Substring(0, 14) + ".." }
                $convs += @{
                    id = $key
                    channel = $state.channel
                    userId = $state.external_user_id
                    displayName = $displayName
                    messageCount = $state.turns.Count
                    preview = $lastMsg
                    lastRole = $lastRole
                }
            }'''

content = content.replace(old_conv, new_conv)

# 2. 在 me 和 conversations 之间插入消息详情路由
old_detail = '''            $client.Close()
            continue
        }

        # GET /api/agent/conversations'''

new_detail = '''            $client.Close()
            continue
        }

        # GET /api/agent/conversation-messages?key=xxx
        if ($method -eq "GET" -and $path.StartsWith("/api/agent/conversation-messages")) {
            $token = (Get-AuthHeaderValue -Headers $request.Headers) -replace "^Bearer ", ""
            if (-not $script:AgentSessions.ContainsKey($token)) {
                $json = (@{ ok = $false; message = "未登录" } | ConvertTo-Json -Compress)
                Write-AuthJsonResponse -Stream $stream -StatusCode 401 -Json $json
                $client.Close()
                continue
            }
            $queryKey = ""
            if ($path -match "key=(.+)") { $queryKey = [System.Uri]::UnescapeDataString($Matches[1]) }
            if (-not $script:SessionHistories.ContainsKey($queryKey)) {
                $json = (@{ ok = $false; message = "会话不存在或已过期" } | ConvertTo-Json -Compress)
                Write-AuthJsonResponse -Stream $stream -StatusCode 404 -Json $json
                $client.Close()
                continue
            }
            $state = $script:SessionHistories[$queryKey]
            $msgs = @()
            foreach ($turn in $state.turns) {
                $msgs += @{
                    role = $turn.role
                    text = $turn.text
                }
            }
            $json = (@{
                ok = $true
                conversationId = $queryKey
                userId = $state.external_user_id
                messages = @($msgs)
            } | ConvertTo-Json -Compress)
            Write-AuthJsonResponse -Stream $stream -StatusCode 200 -Json $json
            $client.Close()
            continue
        }

        # GET /api/agent/conversations'''

content = content.replace(old_detail, new_detail)

with open("/opt/AI1/scripts/demo-server.ps1", "w") as f:
    f.write(content)
print("done")
