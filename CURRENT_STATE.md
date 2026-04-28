# Current State

## Mission

Move the project from a demo-style scripted retrieval flow to a real, testable FastGPT RAG chain while keeping business guardrails and website integration.

## Verified State

- A local FastGPT app already exists: `广西亿库AI客服`
- App ID: `69e0562ea67193262b8de666`
- App OpenAPI key exists: `fgtest-001`
- Current real endpoint: `http://127.0.0.1:3100/api/v1/chat/completions`
- Referenced dataset exists: `gx-yiku-faq`
- Dataset ID: `69e03880d9b607f9459582d6`
- Web demo calls `/api/ai/chat`
- `scripts/demo-server.ps1` handles actual chat routing
- The web layer supports `CHAT_BACKEND=fastgpt_prefer`
- `http://127.0.0.1:3100/` and `http://127.0.0.1:8099/` are reachable
- The latest reviewed import package is under:
  - `C:\Users\Administrator\Desktop\资料\outputs\fastgpt_import\final_for_import\faq.csv`
  - `C:\Users\Administrator\Desktop\资料\outputs\fastgpt_import\final_for_import\doc_chunks.csv`
  - `C:\Users\Administrator\Desktop\资料\outputs\fastgpt_import\final_for_import\product_knowledge.md`

## What Is Working

- The website layer can try a real FastGPT app first.
- The business shell already avoids blindly dumping product info for low-intent greetings.
- Local FAQ rebuild tooling exists.
- External PPT/PDF source materials have already been converted into a reviewed FastGPT import package.

## Main Problem Now

- The FastGPT app is still not stable enough to fully replace the scripted fallback.
- Website fallback can hide FastGPT regressions unless both paths are tested explicitly.
- The current app can return text, but real RAG behavior is still inconsistent.
- Some FastGPT answers are still too generic or too inferential for production use.

## Current Priority

1. Import or verify the package under `C:\Users\Administrator\Desktop\资料\outputs\fastgpt_import\final_for_import`.
2. Re-test the real FastGPT app path with real questions.
3. Decide whether to keep tuning the existing app or rebuild a clean FastGPT app using the new package.
4. Keep the website on `fastgpt_prefer` so the demo remains usable during tuning.

## Known Risk

If FastGPT is unstable, the web layer may still fall back to the direct model path. That protects usability, but it can hide RAG regressions unless we test both paths explicitly.
