# Guangxi Yiku AI Customer Service

This repository now uses a low-token startup layout.

## Read First

1. `PROJECT_INDEX.md`
2. `CURRENT_STATE.md`
3. `DECISIONS.md`
4. `NEXT_ACTION.md`

These four files are the default handoff path for new sessions.

## Purpose

The project is building a practical FastGPT-based AI customer service flow for Guangxi Yiku:

`source docs -> cleaned knowledge -> FastGPT dataset/app -> website demo -> validation`

## Main Areas

- `infra/fastgpt/`: local FastGPT deployment
- `scripts/`: startup and rebuild helpers
- `config/fastgpt/`: prompts, templates, workflow assets
- `data/`: knowledge assets
- `tools/`: ingest and validation tooling
- `web-demo/`: website integration demo
- `docs/guides/`: teammate handoff and restore guides
- `docs/tasks/`: reusable task prompts
- `docs/archive/`: older detailed docs

## Useful Commands

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-local.ps1
```

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-demo.ps1 -Port 8099
```

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\validate\run_all.ps1
```
