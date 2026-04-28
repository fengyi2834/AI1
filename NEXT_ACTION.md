# Next Action

## Default Startup

Use this as the default restart prompt:

```text
先读 PROJECT_INDEX.md、CURRENT_STATE.md、DECISIONS.md、NEXT_ACTION.md，
再按当前任务需要决定是否继续读 task_plan.md / findings.md / progress.md。
```

## Immediate Engineering Tasks

1. Import or verify the package under `C:\Users\Administrator\Desktop\资料\outputs\fastgpt_import\final_for_import`.
2. Re-test the real FastGPT app path with real questions instead of relying on fallback.
3. Decide whether to keep tuning the existing app or rebuild a clean FastGPT app using the new package.
4. Keep the website/demo verification flow able to distinguish `fastgpt_app` from fallback behavior.

## Canonical Scripts

- `scripts/rebuild-fastgpt-faq.ps1`
- `scripts/rebuild-fastgpt-dataset.ps1`
- `scripts/tune-fastgpt-rag-app.ps1`
- `scripts/register-fastgpt-chat-model.ps1`
- `scripts/extract_ppt_pdf_knowledge.py`
- `scripts/build_curated_faq.py`
- `scripts/demo-server.ps1`
- `scripts/start-local.ps1`
- `scripts/start-demo.ps1`

## Session Hygiene

- When a phase is finished, add a short summary before switching topics.
- If the conversation becomes long, start a fresh session using the startup prompt above.
- Read archived docs only for deep reference, not by default.
