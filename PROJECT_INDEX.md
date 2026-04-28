# Project Index

## Default Startup Order

For a new session, read files in this order:

1. `PROJECT_INDEX.md`
2. `CURRENT_STATE.md`
3. `DECISIONS.md`
4. `NEXT_ACTION.md`

Only read `task_plan.md`, `findings.md`, and `progress.md` when continuing the current FastGPT/RAG implementation in detail.

## Project Goal

This repo is a practical FastGPT-based AI customer service project for Guangxi Yiku.

Near-term usable chain:

`source docs -> cleaned knowledge -> FastGPT dataset/app -> website demo -> validation`

## Repository Map

- `infra/fastgpt/`: local FastGPT deployment files
- `scripts/`: startup, rebuild, tuning, and helper scripts
- `config/fastgpt/`: prompts, workflow templates, model config templates
- `data/faq/`: customer-service FAQ source files
- `data/import_ready/`: import-ready knowledge assets and extracted source material
- `web-demo/`: website chat demo
- `tools/`: ingestion and validation tooling
- `docs/guides/`: restore and teammate setup guides
- `docs/tasks/`: reusable task prompts such as knowledge-base curation scope
- `docs/archive/`: historical planning, checklist, and older setup docs
- `C:\Users\Administrator\Desktop\资料\outputs\fastgpt_import\final_for_import`: latest reviewed external-material import package

## Useful Commands

Start local FastGPT stack:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-local.ps1
```

Start demo server:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-demo.ps1 -Port 8099
```

Rebuild local FAQ CSV:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\rebuild-fastgpt-faq.ps1
```

Rebuild FastGPT dataset records:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\rebuild-fastgpt-dataset.ps1
```

Tune FastGPT RAG app:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\tune-fastgpt-rag-app.ps1
```

## Notes

- Prefer this file plus the three other handoff docs over long historical materials.
- Treat `task_plan.md`, `findings.md`, and `progress.md` as engineering working memory, not default startup context.
