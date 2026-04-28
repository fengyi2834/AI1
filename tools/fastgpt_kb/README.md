# FastGPT 知识库材料整理工具

目标：把 PPTX/PDF 原始材料提取为可审计文本，并生成 FastGPT 可一遍导入就可用的 FAQ CSV 与结构化知识文档。

## 运行方式（PowerShell）

```powershell
.\.venv\Scripts\python.exe tools\fastgpt_kb\build_fastgpt_kb.py `
  --input-dir "C:\Users\Administrator\Desktop\资料\1" `
  --output-dir "C:\Users\Administrator\Desktop\AI1\outputs\fastgpt_import"
```

输出会落到 `outputs\fastgpt_import\run_YYYYMMDD_HHMMSS\` 目录。

## 产物说明

- `faq.csv`：仅两列 `question,answer`，适合直接导入 FAQ。
- `faq_with_sources.csv`：附加 `source_file/source_loc` 与 `needs_review`，用于溯源与复核。
- `product_knowledge.md`：按页/页码结构化的原文摘录，适合当作文档类知识补充导入。
- `cleaned_chunks.jsonl` / `extracted_chunks.jsonl`：审计用中间结果，便于追查“问答从哪里来的”。

