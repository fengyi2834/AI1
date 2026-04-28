# Restore Bundle Guide

## Goal

Use a private restore bundle so a teammate can recover a FastGPT environment close to the current project state without depending on your live account session.

## Recommended Workflow

1. On your machine, export a restore bundle.
2. Send the generated zip file to your teammate through a private channel.
3. Your teammate pulls the repository code.
4. Your teammate runs the restore bootstrap script against the bundle.

## What the Bundle Contains

- A private Mongo archive of the `fastgpt` database
- Project-side knowledge files under `data/faq` and `data/import_ready` when present
- Optional private env file if you export with `-IncludeEnvLocal`
- Metadata about the bundle creation time and git commit

## Security Warning

This bundle is private infrastructure state.

- Do not commit the bundle to Git.
- Do not upload the bundle to a public location.
- Treat the bundle like a private handoff package.
- If you include `.env.local`, the bundle may contain real API keys.

## Export on Your Machine

From the project root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\export-fastgpt-restore-bundle.ps1
```

If you also want to include your private `.env.local`:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\export-fastgpt-restore-bundle.ps1 -IncludeEnvLocal
```

Output:

- bundle directory: `.\restore_bundles\fastgpt_restore_bundle_YYYYMMDD_HHMMSS\`
- zip file: `.\restore_bundles\fastgpt_restore_bundle_YYYYMMDD_HHMMSS.zip`

## Restore on a Teammate Machine

Requirements:

- Docker Desktop installed
- This repository cloned locally
- A private restore bundle zip from you

Basic restore:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap_restore.ps1 -BundlePath .\restore_bundles\fastgpt_restore_bundle_YYYYMMDD_HHMMSS.zip
```

Restore and also start the demo site:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap_restore.ps1 -BundlePath .\restore_bundles\fastgpt_restore_bundle_YYYYMMDD_HHMMSS.zip -StartDemo
```

If the teammate also needs a local Python venv for the ingest tools:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap_restore.ps1 -BundlePath .\restore_bundles\fastgpt_restore_bundle_YYYYMMDD_HHMMSS.zip -RebuildVenv
```

## What the Restore Script Does

1. Ensures Docker is running
2. Starts the local FastGPT stack
3. Copies a bundled env file when available and local env is missing
4. Restores the private Mongo archive into the local `fastgpt` database
5. Restarts `fastgpt-app`
6. Copies bundled knowledge files back into the local project `data` directory
7. Re-registers the chat model
8. Re-applies the current RAG workflow tuning script
9. Optionally starts the demo server on port `8099`

## Fast Iteration Advice

For the least friction:

- Share code changes through Git
- Share environment state through the private restore bundle
- When your workflow or scripts change significantly, export a fresh bundle
- When only code changes, a teammate can usually just `git pull` and rerun:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\tune-fastgpt-rag-app.ps1
```

## Known Tradeoff

This B-plan is optimized for convenience and fidelity, not for public portability.

It is intentionally teammate-friendly:

- faithful to your current app and dataset ids
- easy to hand off with one zip
- low setup burden on the other side

But it depends on a private bundle, not Git alone.
