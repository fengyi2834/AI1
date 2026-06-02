"""改进 conversations API：匹配注册用户显示昵称"""

with open("/opt/AI1/scripts/demo-server.ps1", "r") as f:
    content = f.read()

old = '''            $convs = @()
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

new = '''            $convs = @()
            foreach ($key in $script:SessionHistories.Keys) {
                $state = $script:SessionHistories[$key]
                $lastMsg = ""
                $lastRole = ""
                if ($state.turns.Count -gt 0) {
                    $lastTurn = $state.turns[-1]
                    $lastMsg = $lastTurn.text.Substring(0, [Math]::Min(80, $lastTurn.text.Length))
                    $lastRole = $lastTurn.role
                }
                $rawId = $state.external_user_id
                # 尝试匹配注册用户昵称
                $displayName = ""
                $isRegistered = $false
                foreach ($userEmail in $script:AuthUsers.Keys) {
                    $u = $script:AuthUsers[$userEmail]
                    if ($rawId -eq $userEmail -or $rawId -eq $u.id) {
                        if ($u.nickname) { $displayName = $u.nickname } else { $displayName = $userEmail.Split("@")[0] }
                        $isRegistered = $true
                        break
                    }
                }
                if (-not $displayName) {
                    if ($rawId.StartsWith("anon")) {
                        $short = $rawId.Replace("anon-", "").Replace("anon", "")
                        if ($short.Length -gt 8) { $short = $short.Substring(0, 8) }
                        $displayName = "匿名-" + $short
                    } elseif ($rawId.Contains("@")) {
                        $displayName = $rawId.Split("@")[0]
                    } else {
                        if ($rawId.Length -gt 14) { $displayName = $rawId.Substring(0, 12) + ".." }
                        else { $displayName = $rawId }
                    }
                }
                $convs += @{
                    id = $key
                    channel = $state.channel
                    userId = $rawId
                    displayName = $displayName
                    isRegistered = $isRegistered
                    messageCount = $state.turns.Count
                    preview = $lastMsg
                    lastRole = $lastRole
                }
            }'''

content = content.replace(old, new)
with open("/opt/AI1/scripts/demo-server.ps1", "w") as f:
    f.write(content)
print("done")
