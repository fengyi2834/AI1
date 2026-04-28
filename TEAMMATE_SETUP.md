# Teammate Setup Guide

## Goal

This guide is for a teammate who will prepare their own local environment and then rebuild the Guangxi Yiku FastGPT demo on top of the repository code.

This path does **not** depend on your private runtime state, local database files, or account login session.

## What You Should Send to a Teammate

Send these items:

1. The Git repository URL and branch name
2. The source FAQ Word file:
   - `客户最常问的10-50问题及标准回答.docx`
3. If you want them to skip the DOCX conversion step, also send:
   - `data/faq/customer_top_10_50_docx.csv`
4. If they also need the reviewed document-chunk knowledge, send the import package files:
   - `doc_chunks.csv`
   - optional related source materials used to produce it
5. If they need the exact external business materials, send the original PPT/PDF/Word source folder separately through a private file transfer channel

Do **not** send:

- `infra/fastgpt/runtime/`
- Mongo or Postgres data folders
- Docker volumes
- browser login state
- your local `.env.local` unless you intentionally want to share private keys

## What a Teammate Must Prepare Locally

They should prepare:

- Docker Desktop
- Python 3.12 with `py`
- Their own model API key
- Their own local FastGPT env file

## Recommended Local Setup

### 1. Clone the repository

```powershell
git clone <repo-url>
cd AI1
git checkout <branch-name>
```

### 2. Create the local env file

Copy:

- `infra/fastgpt/.env.example`

to:

- `infra/fastgpt/.env.local`

Then fill at least:

- `OPENAI_BASE_URL`
- `CHAT_API_KEY`
- `CHAT_BACKEND=fastgpt_prefer`
- `FASTGPT_APP_API_URL=http://127.0.0.1:3100/api/v1/chat/completions`
- `FASTGPT_APP_API_KEY=fgtest-001`

If they do not want to use your exact test key name, they can change it, but then the demo-side config must stay consistent.

### 3. Build the Python venv

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\rebuild-venv.ps1
```

### 4. Start the local FastGPT stack

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-local.ps1
```

Wait until FastGPT is reachable at:

- `http://127.0.0.1:3100/`

### 5. Register the chat model

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\register-fastgpt-chat-model.ps1
```

### 6. Import the FAQ from the DOCX file

If they only received the Word file, first convert it:

```powershell
.\.venv\Scripts\python.exe .\scripts\build_docx_faq_csv.py `
  --input "<path-to-docx>\客户最常问的10-50问题及标准回答.docx" `
  --output ".\data\faq\customer_top_10_50_docx.csv"
```

Then import it:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\import-fastgpt-faq-csv.ps1 `
  -SourceCsv ".\data\faq\customer_top_10_50_docx.csv" `
  -CollectionName "gx-yiku-customer-top-10-50-docx"
```

If they already received the generated CSV, they can skip the conversion step and only run the import step.

### 7. Optional: import reviewed doc chunks

If they received a reviewed `doc_chunks.csv`, import it with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\import-fastgpt-doc-chunks.ps1 `
  -DocChunksCsv "<path-to-doc_chunks.csv>"
```

### 8. Apply the current RAG workflow

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\tune-fastgpt-rag-app.ps1
```

This step is important because it applies the current:

- dataset search node settings
- quote injection format
- final chat model selection
- RAG prompt wiring

### 9. Start the demo site

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-demo.ps1 -Port 8099
```

Demo URL:

- `http://127.0.0.1:8099/`

## Quick Verification

They should test these questions first:

- `新房适合用吗？`
- `产品有专利和检测报告吗？`
- `亿库硅藻板防霉等级是多少？`
- `硅藻板对宠物友好吗？`

Expected result:

- FastGPT should return direct Chinese answers
- The RAG path should be usable even if the exact wording is not identical to the FAQ source

## Fast Iteration Workflow

For day-to-day collaboration:

1. Share code changes through Git
2. Share new source knowledge files separately
3. Let each teammate rebuild their own FastGPT state locally
4. After pulling code, rerun only the needed scripts

Typical update cases:

- Workflow changed:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\tune-fastgpt-rag-app.ps1
```

- New FAQ Word file arrived:

```powershell
.\.venv\Scripts\python.exe .\scripts\build_docx_faq_csv.py --input "<docx>" --output ".\data\faq\<name>.csv"
powershell -ExecutionPolicy Bypass -File .\scripts\import-fastgpt-faq-csv.ps1 -SourceCsv ".\data\faq\<name>.csv" -CollectionName "<collection-name>"
```

- New doc chunk package arrived:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\import-fastgpt-doc-chunks.ps1 -DocChunksCsv "<doc_chunks.csv>"
```

## Practical Advice

If your teammate wants the least friction, send:

- repository branch
- the FAQ Word file
- the already-generated FAQ CSV
- any reviewed `doc_chunks.csv`

That is usually enough for them to rebuild a usable local knowledge base without needing your private machine state.
