"""给 auth 系统加硬盘持久化"""
PATH = "/opt/AI1/scripts/demo-server.ps1"
with open(PATH, "r") as f:
    content = f.read()

# 1. 加 AuthUsersFile 路径变量和初始化函数
old1 = '$script:AuthUserIdCounter = 0'
new1 = '''$script:AuthUsersFile = "/opt/AI1/data/runtime/auth_users.json"
$script:AuthUserIdCounter = 0

function Initialize-AuthUsers {
    param([string]$FilePath)
    $script:AuthUsersFile = $FilePath
    $parent = Split-Path -Parent $FilePath
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    if (Test-Path -LiteralPath $FilePath) {
        try {
            $raw = Get-Content $FilePath -Raw -Encoding UTF8
            $data = $raw | ConvertFrom-Json -Depth 10
            if ($data.users) {
                foreach ($u in $data.users) {
                    $script:AuthUsers[$u.email] = @{
                        id = [int]$u.id; email = [string]$u.email
                        password_hash = [string]$u.password_hash
                        nickname = [string]$u.nickname; company = [string]$u.company
                        phone = [string]$u.phone; created_at = [string]$u.created_at
                        last_login = if ($u.last_login) { [string]$u.last_login } else { $null }
                        verified = [bool]$u.verified
                    }
                    if ([int]$u.id -gt $script:AuthUserIdCounter) { $script:AuthUserIdCounter = [int]$u.id }
                }
            }
        } catch { $script:AuthUsers = @{} }
    }
}

function Save-AuthUsers {
    if (-not $script:AuthUsersFile) { return }
    try {
        $users = @()
        foreach ($email in $script:AuthUsers.Keys) {
            $u = $script:AuthUsers[$email]
            $users += @{
                id = $u.id; email = $u.email; password_hash = $u.password_hash
                nickname = $u.nickname; company = $u.company; phone = $u.phone
                created_at = $u.created_at; last_login = $u.last_login; verified = $u.verified
            }
        }
        $data = @{ users = @($users) } | ConvertTo-Json -Depth 8
        Set-Content -LiteralPath $script:AuthUsersFile -Value $data -Encoding UTF8
    } catch { }
}'''
content = content.replace(old1, new1)
print("Fix 1: Auth persistence functions added")

# 2. 初始化时调用 Load
old2 = '$script:DeviceRateLimits = @{}'
new2 = '''$script:DeviceRateLimits = @{}
Initialize-AuthUsers -FilePath $script:AuthUsersFile'''
content = content.replace(old2, new2)
print("Fix 2: Auth load on startup")

# 3. 注册/验证后调用 Save
# 注册新用户后
old3 = '            $script:AuthUsers[$email] = $userRecord'
new3 = '''            $script:AuthUsers[$email] = $userRecord
            Save-AuthUsers'''
content = content.replace(old3, new3)
print("Fix 3: Save after register")

# 重新发送验证码时也保存
old4 = '                    $script:AuthUsers[$email].password_hash = Get-PasswordHash -Password $password'
new4 = '''                    $script:AuthUsers[$email].password_hash = Get-PasswordHash -Password $password
                    Save-AuthUsers'''
content = content.replace(old4, new4)
print("Fix 4: Save after re-register")

# 验证成功后保存
old5 = '            $script:AuthUsers[$email].verified = $true'
new5 = '''            $script:AuthUsers[$email].verified = $true
            Save-AuthUsers'''
content = content.replace(old5, new5)
print("Fix 5: Save after verify")

with open(PATH, "w") as f:
    f.write(content)
# 6. 验证码打印到日志（没 SMTP 也能看到）
old6 = "            $sendResult = Send-VerificationEmail -ToEmail $email -Code $code"
new6 = """            Write-Host "[AUTH] 验证码: $code -> $email"
            $sendResult = Send-VerificationEmail -ToEmail $email -Code $code"""
content = content.replace(old6, new6)
print("Fix 6: Log verification codes")

with open(PATH, "w") as f:
    f.write(content)
print("Done")
