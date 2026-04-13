# 节点配置片段示例

以下为常用节点的最小配置片段，便于在 FastGPT 中手工搭建。

## 输入审核（moderation）
```json
{
  "type": "moderation",
  "config": {
    "model": "moderation",
    "onBlock": "n_output_blocked"
  }
}
```

## 知识库检索（kb_retrieval）
```json
{
  "type": "kb_retrieval",
  "config": {
    "embeddingModel": "embedding-3",
    "topK": 5,
    "scoreThreshold": 0.35,
    "maxTokens": 1200
  }
}
```

## 主客服回答（llm）
```json
{
  "type": "llm",
  "config": {
    "model": "glm-5.1",
    "systemPromptRef": "prompts/system_prompt.md",
    "temperature": 0.2,
    "maxOutputTokens": 600
  }
}
```

## 质检复核（llm）
```json
{
  "type": "llm",
  "config": {
    "model": "glm-4-flash-250414",
    "temperature": 0.1,
    "maxOutputTokens": 400,
    "instruction": "检查是否超出知识库、是否夸大宣传、是否需要转人工。"
  }
}
```

## 留资/转人工路由（rule_router）
```json
{
  "type": "rule_router",
  "config": {
    "conditions": [
      { "if": "needs_handoff == true", "to": "n_handoff" },
      { "if": "risk_level == 'high'", "to": "n_handoff" }
    ],
    "default": "n_output"
  }
}
```
