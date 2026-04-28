# Knowledge Base Task Prompt

## Purpose

Use this document when opening a fresh conversation to continue整理 `C:\Users\Administrator\Desktop\资料` 里的知识库材料，并把结果整理成适合 FastGPT / RAG 导入和持续迭代的结构。

---

## 1. Task Scope

### Main source directory

- `C:\Users\Administrator\Desktop\资料`

### Current visible items under that directory

- `C:\Users\Administrator\Desktop\资料\1`
- `C:\Users\Administrator\Desktop\资料\亿库公司资料(3)`
- `C:\Users\Administrator\Desktop\资料\亿库硅藻板销售价格23年10月.docx`
- `C:\Users\Administrator\Desktop\资料\客户最常问的10-50问题及标准回答_20260427084321.docx`
- `C:\Users\Administrator\Desktop\资料\客户跟踪表-伍国涛2026.4.22.xls`
- `C:\Users\Administrator\Desktop\资料\河南青丰.pdf`

### Project workspace

- `C:\Users\Administrator\Desktop\AI1`

### Current project context

- FastGPT local endpoint: `http://127.0.0.1:3100/`
- Current dataset id: `69e03880d9b607f9459582d6`
- Current app id: `69e0562ea67193262b8de666`
- Existing reviewed import package location:
  - `C:\Users\Administrator\Desktop\资料\outputs\fastgpt_import\final_for_import\faq.csv`
  - `C:\Users\Administrator\Desktop\资料\outputs\fastgpt_import\final_for_import\doc_chunks.csv`
  - `C:\Users\Administrator\Desktop\资料\outputs\fastgpt_import\final_for_import\product_knowledge.md`

---

## 2. Main Goal

整理 `C:\Users\Administrator\Desktop\资料` 中与亿库产品、公司、适用场景、资质、FAQ、说明材料相关的内容，产出一套可持续维护、可审计、可导入 FastGPT 的知识库结构，优先服务真实 RAG，而不是临时演示。

重点不是“把所有文件都塞进知识库”，而是：

1. 识别哪些材料适合进入 FAQ
2. 识别哪些材料适合进入文档分块知识
3. 排除不适合进入公开客服知识库的内容
4. 让后续任何同事都能在此基础上继续迭代

---

## 3. Knowledge Base Organization Rules

### 3.1 必须区分的知识类型

把材料至少分成以下几类：

1. FAQ 类
   - 用户高频直接问法
   - 标准回答清晰、稳定、低歧义
   - 适合一问一答导入

2. 文档知识类
   - 产品功能说明
   - 适用场景
   - 公司介绍
   - 技术参数
   - 资质/专利/检测说明
   - 适合做 chunk 导入，不强行改成 FAQ

3. 敏感业务类
   - 报价
   - 客户跟踪
   - 合作进度
   - 内部业务表
   - 不应直接进入对外客服知识库

4. 待人工确认类
   - 信息冲突
   - 来源不清
   - 说法太绝对
   - 涉及法律、医疗、认证结论但证据不足

### 3.2 FAQ 整理标准

FAQ 必须满足：

1. 一条记录只表达一个清晰问题
2. 一条记录只给一个主回答，不要混多个主题
3. 问题要尽量贴近真实客户问法
4. 回答只能根据材料确认到的事实来写
5. 不要为了“更像客服”而补充材料里没有的承诺
6. 不要保留超长段落堆叠式回答
7. 如果问题本质上属于人工跟进范围，要在回答里明确边界

FAQ 输出格式优先：

- `question,answer`

### 3.3 文档 chunk 整理标准

文档 chunk 必须满足：

1. 一个 chunk 只围绕一个相对集中主题
2. 不要把整页 PPT / PDF 原样粗暴塞入
3. 去掉明显页眉页脚、页码、噪声行
4. 保留来源文件和来源位置，方便审计
5. 标题如果只是 `page=10` 或 `slide=4` 这类定位信息，不能直接拿来当知识问题
6. chunk 的 `q` 或主描述字段应优先使用语义化文本，而不是纯定位标题

### 3.4 不应进入公开客服知识库的内容

以下内容默认排除，除非明确要求：

1. 客户跟踪表
2. 内部销售进度
3. 个人联系方式、私密信息
4. 未确认的报价细节
5. 合作政策、返点、合同条款
6. 只适合内部运营查看的数据

例如：

- `客户跟踪表-伍国涛2026.4.22.xls`

这类文件应优先判定为“不入库”或“仅作内部资料，不进入对外客服知识库”。

### 3.5 去重与冲突处理

必须做：

1. 同义问题合并
2. 明显重复 chunk 去重
3. 相互冲突的答案单独列出
4. 不确定时写入 `needs_review` 或单独审核清单

### 3.6 输出质量要求

输出必须满足：

1. 可追溯
2. 可复用
3. 可持续追加
4. 不依赖当前对话记忆
5. 同事拿到输出后，能看懂来源和用途

---

## 4. Expected Deliverables

优先产出以下结果：

1. `faq.csv`
   - 仅保留稳定 FAQ

2. `faq_with_sources.csv`
   - 带来源文件、来源位置、是否待复核

3. `doc_chunks.csv`
   - 适合 FastGPT 文档导入

4. `product_knowledge.md`
   - 结构化知识总览，适合人工审阅

5. `review_notes.md`
   - 记录冲突、排除项、敏感项、待确认项

6. 如有必要：
   - `excluded_files.md`
   - 说明哪些文件不应纳入对外知识库，以及原因

---

## 5. Working Principles

### 必须遵守

1. 先读目录和样本，再决定处理方式
2. 不要默认所有文件都应该入库
3. 先保证正确分类，再追求数量
4. 遇到不确定内容，标记而不是编造
5. 优先生成可导入 FastGPT 的结构化结果
6. 所有重要发现要落盘，不要只停留在对话里

### 优先复用现有仓库能力

优先查看并复用这些脚本或思路：

- `scripts/build_docx_faq_csv.py`
- `scripts/import-fastgpt-faq-csv.ps1`
- `scripts/import-fastgpt-doc-chunks.ps1`
- `scripts/tune-fastgpt-rag-app.ps1`
- `tools/knowledge_ingest/ingest.py`
- `tools/fastgpt_kb/build_fastgpt_kb.py`

---

## 6. Should Skill Be Used?

### 建议：要用 skill

建议至少使用这些 skill：

1. `using-superpowers`
   - 开场必走，先对齐 skill 使用方式

2. `zh-project-coach`
   - 因为本任务需要中文解释、中文整理标准、中文复盘

3. `planning-with-files`
   - 因为这类知识库整理通常会超过 5 次工具调用，而且需要持续记录发现、进度、输出路径

### 什么时候再考虑别的 skill

如果新对话里明确还要做前端展示或可视化页面，再考虑：

- `frontend-design`

否则这次知识库整理本身不需要它。

---

## 7. Should Sub-Agents Be Used?

### 建议：可以用，但只在这些场景下用

如果平台允许并且当前模型支持子代理，建议只在“明确可并行”的情况下使用：

1. 一个子代理专门扫目录与文件分类
2. 一个子代理专门抽取 FAQ 候选
3. 一个子代理专门抽取 doc chunk 候选

### 不建议滥用子代理

以下情况不建议：

1. 任务刚开始，还没搞清目录结构
2. 输出格式和标准还没定
3. 多个子代理会同时改同一批文件

### 总结

- `skill`：建议用
- `子代理`：可用，但要在分类标准明确后再并行

---

## 8. Copy-Paste Prompt For a New Conversation

下面这段可以直接复制到新对话里：

```text
请先使用适合的 skill，再开始工作。当前任务是整理知识库材料，工作目录重点是：
C:\Users\Administrator\Desktop\资料

项目目录是：
C:\Users\Administrator\Desktop\AI1

请按下面要求执行：

1. 先检查 C:\Users\Administrator\Desktop\资料 的目录结构和文件类型，判断哪些适合进入 FAQ、哪些适合进入文档 chunk、哪些不应该进入公开客服知识库。
2. 目标是产出可持续维护的 FastGPT 知识库导入结果，而不是临时演示文件。
3. FAQ 必须整理成 one question + one answer 的稳定结构，避免大段混合回答。
4. 文档 chunk 必须去噪、可追溯、保留来源，不要把整页原样粗暴导入。
5. 客户跟踪表、内部销售信息、敏感业务信息默认不进入公开客服知识库。
6. 如果发现冲突、证据不足、描述过于绝对，要单独写 review notes，不要直接编造成标准答案。
7. 优先复用仓库现有工具和脚本，尤其是：
   - scripts/build_docx_faq_csv.py
   - scripts/import-fastgpt-faq-csv.ps1
   - scripts/import-fastgpt-doc-chunks.ps1
   - tools/knowledge_ingest/ingest.py
   - tools/fastgpt_kb/build_fastgpt_kb.py
8. 产出物至少包括：
   - faq.csv
   - faq_with_sources.csv
   - doc_chunks.csv
   - product_knowledge.md
   - review_notes.md
9. 全程用中文说明。
10. 如果适合并行，可以使用子代理，但必须先明确分类标准，再并行。

补充上下文：
- 当前 FastGPT 本地地址是 http://127.0.0.1:3100/
- 当前数据集 id 是 69e03880d9b607f9459582d6
- 当前 app id 是 69e0562ea67193262b8de666
- 已有 reviewed import package 位置在：
  C:\Users\Administrator\Desktop\资料\outputs\fastgpt_import\final_for_import

请先做目录审查和知识分类，不要一开始就盲目导入。
```

---

## 9. Recommended First-Step Checklist For the New Conversation

新对话一开始，建议先完成：

1. 读取 `C:\Users\Administrator\Desktop\资料` 顶层目录
2. 判断文件类型和用途
3. 明确“入 FAQ / 入 chunk / 排除 / 待确认”四类
4. 先产出一版分类结论
5. 再进入清洗和导入阶段

这样最稳，也最省后续返工。
