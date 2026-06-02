"""给 Demo Server 的用户注册数据加上 JSON 文件持久化"""

with open("/opt/AI1/scripts/demo-server.ps1", "r") as f:
    content = f.read()

# 1. AuthUsers 文件路径
old = "$script:AgentSessions = @{}  # agent后台登录session"
new = """$script:AuthUsersFile = "/opt/AI1/data/runtime/auth_users.json"
$script:AgentSessions = @{}  # agent后台登录session"""
content = content.replace(old, new)

# 2. 从文件加载用户数据（在 Initialize-DeviceRateLimits 之后）
old = "Initialize-DeviceRateLimits -FilePath $resolvedRateLimitPath"
new = """Initialize-DeviceRateLimits -FilePath $resolvedRateLimitPath

# === 从文件加载已注册用户 ===
$script:AuthUsers = @{}
if (Test-Path -LiteralPath $script:AuthUsersFile) {
    try {
        $raw = Get-Content $script:AuthUsersFile -Raw -Encoding UTF8
        $data = $raw | ConvertFrom-Json
        foreach ($prop in $data.PSObject.Properties) {
            $v = $prop.Value
            $script:AuthUsers[$prop.Name] = @{
                id = $v.id; email = $v.email; password_hash = $v.password_hash
                nickname = $v.nickname; company = $v.company; phone = $v.phone
                created_at = $v.created_at; last_login = $v.last_login; verified = $v.verified
            }
        }
    } catch { $script:AuthUsers = @{} }
}"""
content = content.replace(old, new)

# 3. 添加保存函数
save_func = """

# === 保存用户数据到文件 ===
function Save-AuthUsers {
    if (-not $script:AuthUsersFile) { return }
    try {
        $data = @{}
        foreach ($key in $script:AuthUsers.Keys) {
            $data[$key] = $script:AuthUsers[$key]
        }
        $dir = Split-Path -Parent $script:AuthUsersFile
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $json = $data | ConvertTo-Json -Depth 5
        Set-Content -LiteralPath $script:AuthUsersFile -Value $json -Encoding UTF8
    } catch { }
}
"""
content = content.replace("function Test-DeviceRateLimit {", save_func + "function Test-DeviceRateLimit {")

# 4. 在注册/修改密码后自动保存
content = content.replace(
    "$script:AuthUsers[$email] = $userRecord",
    "$script:AuthUsers[$email] = $userRecord; Save-AuthUsers"
)

with open("/opt/AI1/scripts/demo-server.ps1", "w") as f:
    f.write(content)
print("done")
