"""两个修复:
1. 给 conversation turns 存 image_url
2. 加 /api/agent/conversation-messages 路由
"""
PATH = "/opt/AI1/scripts/demo-server.ps1"
with open(PATH, "r") as f:
    content = f.read()

# Fix 1: 在 Finalize-ChatResult 中存储 image_url
old1 = "has_image = $HasImage"
new1 = "has_image = $HasImage; image_url = if ($ImageDataUrl) { [string]$ImageDataUrl } else { \"\" }"
if old1 in content:
    content = content.replace(old1, new1)
    print("Fix 1: image_url stored in turns")
else:
    print("Fix 1 FAILED - marker not found")

# Fix 2: 加 /api/agent/conversation-messages 路由
old2 = "        # GET /api/agent/conversations"
new2 = """        # GET /api/agent/conversation-messages?key=xxx
        if ($method -eq "GET" -and $path.StartsWith("/api/agent/conversation-messages")) {
            $token = (Get-AuthHeaderValue -Headers $request.Headers) -replace "^Bearer ", ""
            if (-not $script:AgentSessions.ContainsKey($token)) { $json = (@{ ok = $false; message = "未登录" } | ConvertTo-Json -Compress); Write-AuthJsonResponse -Stream $stream -StatusCode 401 -Json $json; $client.Close(); continue }
            $key = ""; if ($path -match "key=([^&]+)") { $key = $Matches[1] }
            $msgs = @()
            if ($script:SessionHistories.ContainsKey($key)) {
                $state = $script:SessionHistories[$key]
                foreach ($turn in $state.turns) {
                    $msg = @{ role = [string]$turn.role; text = [string]$turn.text }
                    if ($turn.image_url) { $msg["imageUrl"] = [string]$turn.image_url }
                    $msgs += $msg
                }
            }
            $json = (@{ ok = $true; messages = @($msgs) } | ConvertTo-Json -Depth 8 -Compress)
            Write-AuthJsonResponse -Stream $stream -StatusCode 200 -Json $json; $client.Close(); continue
        }

        # GET /api/agent/conversations"""

content = content.replace(old2, new2)
print(f"Fix 2: conversation-messages route added")

with open(PATH, "w") as f:
    f.write(content)
print("Done")
