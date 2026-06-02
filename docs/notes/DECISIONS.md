# Decisions

## Active Decisions

- The website should not rely only on `demo-server.ps1` scripted retrieval. Prefer the real FastGPT app path.
- Keep the business guardrail layer for clarification, lead capture, transfer-to-human, and high-risk question handling.
- If the FastGPT app path fails, allow fallback to the direct model path so the page does not become unusable.
- Rebuild FAQ knowledge as one question and one answer per record. Do not keep using large Markdown-table chunks as the long-term dataset format.
- Treat `C:\Users\Administrator\Desktop\资料\outputs\fastgpt_import\final_for_import` as the current reviewed external-material import package unless a newer one is explicitly generated.

## Documentation Decisions

- Use `PROJECT_INDEX.md`, `CURRENT_STATE.md`, `DECISIONS.md`, and `NEXT_ACTION.md` as the default startup context for future sessions.
- Keep `task_plan.md`, `findings.md`, and `progress.md` as working memory for in-flight engineering detail.
- Move older long-form planning/checklist material into `docs/archive/` so it is available but not part of the default reading path.

## What To Avoid Repeating

- Do not re-open archived planning/checklist docs unless the current task really depends on them.
- Do not treat fallback success as proof that FastGPT RAG is healthy.
- Do not import FAQ content in oversized blocks if the goal is reliable retrieval.
- Do not assume the existing FastGPT app is production-ready just because it returns text for some questions.
