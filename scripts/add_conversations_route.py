"""在 demo-server.ps1 中插入 conversations 路由"""

with open("/opt/AI1/scripts/demo-server.ps1", "r") as f:
    content = f.read()

old = '''            $client.Close()
            continue
        }

        if ($method -eq "GET" -and $path.StartsWith("/api/media?"'''

new = '''            $client.Close()
            continue
        }

        # GET /api/agent/conversations
        if ($method -eq "GET" -and $path -eq "/api/agent/conversations") {
            $token = (Get-AuthHeaderValue -Headers $request.Headers) -replace "^Bearer ", ""
            if (-not $script:AgentSessions.ContainsKey($token)) {
                $json = (@{ ok = $false; message = "未登录" } | ConvertTo-Json -Compress)
                Write-AuthJsonResponse -Stream $stream -StatusCode 401 -Json $json
                $client.Close()
                continue
            }
            $convs = @()
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
            }
            $json = (@{ ok = $true; conversations = @($convs) } | ConvertTo-Json -Compress)
            Write-AuthJsonResponse -Stream $stream -StatusCode 200 -Json $json
            $client.Close()
            continue
        }

        if ($method -eq "GET" -and $path.StartsWith("/api/media?"'''

content = content.replace(old, new)
with open("/opt/AI1/scripts/demo-server.ps1", "w") as f:
    f.write(content)
print("done - conversations route added")
