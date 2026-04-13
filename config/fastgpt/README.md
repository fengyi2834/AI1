# FastGPT 模板配置

这里放的是“适合广西亿库当前阶段”的 FastGPT 模板。

说明：
- 这些文件优先作为“人工配置模板”和“工作流蓝图”使用
- 不保证所有 JSON 都能直接一键导入 FastGPT
- 但可以直接指导后台模型配置、知识库整理和工作流搭建

## 文件说明

- `model.zhipu.template.json`
  智谱模型配置模板
- `kb_structure.md`
  知识库目录与切片建议
- `prompts/system_prompt.md`
  主客服系统提示词模板
- `workflows/cs_workflow.example.json`
  客服工作流蓝图
- `nodes/node_templates.md`
  常用节点配置片段

## 使用顺序

1. 先按 `kb_structure.md` 整理 `xlsx/docx`
2. 在 FastGPT 后台按 `model.zhipu.template.json` 配模型
3. 把 `prompts/system_prompt.md` 用到主客服应用
4. 按 `workflows/cs_workflow.example.json` 搭完整流程
5. 参考 `nodes/node_templates.md` 做节点微调
