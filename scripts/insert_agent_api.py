"""在 demo-server.ps1 中插入坐席后台 API 路由"""

with open("/opt/AI1/scripts/demo-server.ps1", "r") as f:
    content = f.read()

# 找到插入位置：media 路由之前
insert_marker = 'if ($method -eq "GET" -and $path.StartsWith("/api/media?"'

agent_api_block = """        # ===== 坐席后台 API =====
        # POST /api/agent/login
        if ($method -eq "POST" -and $path -eq "/api/agent/login") {
            $body = if ($request.Body) { $request.Body | ConvertFrom-Json } else { $null }
            $authFile = "/opt/AI1/config/agent-auth.json"
            $authData = Get-Content $authFile -Raw -Encoding UTF8 | ConvertFrom-Json
            $user = $authData.users | Where-Object { $_.username -eq $body.username -and $_.password -eq $body.password }
            if ($user) {
                $token = "agent-" + [guid]::NewGuid().ToString("N")
                $sessionData = @{ username = $user.username; name = $user.name; created = [DateTime]::UtcNow }
                $script:AgentSessions[$token] = $sessionData
                $json = (@{ ok = $true; token = $token; name = $user.name } | ConvertTo-Json -Compress)
                Write-AuthJsonResponse -Stream $stream -StatusCode 200 -Json $json
            } else {
                $json = (@{ ok = $false; message = "账号或密码错误" } | ConvertTo-Json -Compress)
                Write-AuthJsonResponse -Stream $stream -StatusCode 401 -Json $json
            }
            $client.Close()
            continue
        }

        # GET /api/agent/me
        if ($method -eq "GET" -and $path -eq "/api/agent/me") {
            $token = (Get-AuthHeaderValue -Headers $request.Headers) -replace "^Bearer ", ""
            if (-not $script:AgentSessions.ContainsKey($token)) {
                $json = (@{ ok = $false; message = "未登录" } | ConvertTo-Json -Compress)
                Write-AuthJsonResponse -Stream $stream -StatusCode 401 -Json $json
                $client.Close()
                continue
            }
            $session = $script:AgentSessions[$token]
            $json = (@{ ok = $true; username = $session.username; name = $session.name } | ConvertTo-Json -Compress)
            Write-AuthJsonResponse -Stream $stream -StatusCode 200 -Json $json
            $client.Close()
            continue
        }

"""

# 在 insert_marker 前插入
content = content.replace(insert_marker, agent_api_block + "        " + insert_marker)

# 初始化全局 AgentSessions 变量
if "$script:AgentSessions = @{}" not in content:
    content = content.replace(
        "$script:DeviceRateLimits = @{}",
        "$script:DeviceRateLimits = @{}\n$script:AgentSessions = @{}  # agent后台登录session"
    )

with open("/opt/AI1/scripts/demo-server.ps1", "w") as f:
    f.write(content)

print("done - agent API routes inserted")
