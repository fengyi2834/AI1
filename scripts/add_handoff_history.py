"""在 handoff 创建时带入聊天历史（含图片）"""
import re

with open("/opt/AI1/scripts/demo-server.ps1", "r") as f:
    content = f.read()

# 匹配: messages = @()\n                agent = ""...
old = 'reason = [string]$body.reason; messages = @()\n                agent = ""; status = "pending"; createdAt = [DateTime]::UtcNow.ToString("o")\n            }\n            Save-HandoffQueue'

new = '''reason = [string]$body.reason; messages = @()
                agent = ""; status = "pending"; createdAt = [DateTime]::UtcNow.ToString("o")
            }
            # === 将聊天历史（含图片）带入工单 ===
            if ($body.history) {
                foreach ($hmsg in $body.history) {
                    $entry = @{ role = [string]$hmsg.role; text = [string]$hmsg.text; time = [DateTime]::UtcNow.ToString("HH:mm") }
                    if ($hmsg.imageUrl) { $entry["imageUrl"] = [string]$hmsg.imageUrl }
                    $script:HandoffQueue[$hid].messages += $entry
                }
            }
            Save-HandoffQueue'''

count = content.count(old)
content = content.replace(old, new)
print(f"替换了 {count} 处 (预期 2)")

with open("/opt/AI1/scripts/demo-server.ps1", "w") as f:
    f.write(content)
print("done")
