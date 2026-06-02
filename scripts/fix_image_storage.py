"""修复 Finalize-ChatResult: 加上 ImageDataUrl 参数，存储图片 URL"""
PATH = "/opt/AI1/scripts/demo-server.ps1"
with open(PATH, "r") as f:
    content = f.read()

# 1. 函数签名加参数
old1 = """    param(
        [string]$Channel,
        [string]$ExternalUserId,
        [string]$ConversationId,
        [string]$SessionId,
        [string]$Question,
        [bool]$HasImage,
        $RawResult,
        $UserProfile,
        $ConversationState
    )"""
new1 = """    param(
        [string]$Channel,
        [string]$ExternalUserId,
        [string]$ConversationId,
        [string]$SessionId,
        [string]$Question,
        [bool]$HasImage,
        [string]$ImageDataUrl,
        $RawResult,
        $UserProfile,
        $ConversationState
    )"""
content = content.replace(old1, new1)
print("Fix 1: Added ImageDataUrl param")

# 2. 所有调用处加 -ImageDataUrl $ImageDataUrl
old2 = "-HasImage $hasImage -RawResult"
new2 = "-HasImage $hasImage -ImageDataUrl $ImageDataUrl -RawResult"
count = content.count(old2)
content = content.replace(old2, new2)
print(f"Fix 2: Updated {count} call sites")

with open(PATH, "w") as f:
    f.write(content)
print("Done")
