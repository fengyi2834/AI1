"""修复 demo-server.ps1: ConvertFrom-Json 加深度 + handoff 带历史"""
import re

PATH = "/opt/AI1/scripts/demo-server.ps1"
with open(PATH, "r") as f:
    content = f.read()

# 1. 所有 ConvertFrom-Json 加 -Depth 10
content = content.replace("ConvertFrom-Json", "ConvertFrom-Json -Depth 10")
print("Depth fix applied")

# 2. Handoff 创建时带历史
old = 'reason = [string]$body.reason; messages = @()\n                agent = ""; status = "pending"; createdAt = [DateTime]::UtcNow.ToString("o")\n            }\n            Save-HandoffQueue'
new = '''reason = [string]$body.reason; messages = @()
                agent = ""; status = "pending"; createdAt = [DateTime]::UtcNow.ToString("o")
            }
            # === 聊天历史带入工单 ===
            if ($body.history) {
                foreach ($hmsg in $body.history) {
                    $entry = @{ role = [string]$hmsg.role; text = [string]$hmsg.text; time = [DateTime]::UtcNow.ToString("HH:mm") }
                    if ($hmsg.imageUrl) { $entry["imageUrl"] = [string]$hmsg.imageUrl }
                    $script:HandoffQueue[$hid].messages += $entry
                }
            }
            Save-HandoffQueue'''
c = content.count(old)
content = content.replace(old, new)
print(f"History patch: {c} places")

with open(PATH, "w") as f:
    f.write(content)
print("Done")
