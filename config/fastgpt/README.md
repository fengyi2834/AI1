# FastGPT 配置模板（广西亿库 AI 客服）

本目录提供 FastGPT 侧的可执行模板，面向“广西亿库光养硅藻环保科技有限公司”AI 客服场景。

包含内容：
- `model.zhipu.template.json`: 智谱模型配置模板（GLM-5.1 + Embedding-3 + moderation + GLM-4-Flash 质检）。
- `kb_structure.md`: 知识库目录与资料整理模板（从 xlsx/docx 起步）。
- `prompts/system_prompt.md`: 系统提示词模板（客服口径与风险边界）。
- `workflows/cs_workflow.example.json`: 工作流/节点配置示例（可按 FastGPT 导入或手工搭建）。
- `nodes/node_templates.md`: 节点参数配置片段示例。

使用方式（与其他模块协作）：
1. 将 `model.zhipu.template.json` 的占位符替换为真实 API Key/URL，并导入 FastGPT 的模型配置。
2. 按 `kb_structure.md` 先把原始 `xlsx/docx` 资料清洗为 Markdown/FAQ，再导入知识库。
3. 把 `prompts/system_prompt.md` 贴到 FastGPT 的系统提示词或主客服节点提示词。
4. 按 `workflows/cs_workflow.example.json` 搭建工作流节点（或参考 `nodes/node_templates.md` 手工配置）。

注意：模板仅提供结构和字段示例，不包含任何真实密钥或生产路径。
