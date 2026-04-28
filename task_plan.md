# Task Plan

## Goal

Move the current website AI customer service flow from a demo-style scripted retrieval path to a real, testable FastGPT RAG path, while keeping the business guardrail layer.

## Phases

| Phase | Status | Step |
|---|---|---|
| 1 | complete | Verify the current web demo, FastGPT app, dataset, and call path |
| 2 | in_progress | Repair or rebuild the FastGPT app and dataset so the real RAG path is testable |
| 3 | in_progress | Keep the web layer pointed at the real FastGPT app first, with fallback only when needed |
| 4 | in_progress | Re-test real Q&A behavior and summarize remaining blockers plus rollout steps |
| 5 | complete | Restructure project docs into a low-token startup path |
| 6 | complete | Convert external source materials into a FastGPT-ready QA/document import package |
| 7 | complete | Resume knowledge-base curation from `KNOWLEDGE_BASE_TASK_PROMPT.md` and classify `C:\Users\Administrator\Desktop\资料` by FAQ / doc chunk / exclude / needs review |
| 8 | complete | Produce refreshed deliverables and review notes for the latest source set under `C:\Users\Administrator\Desktop\资料` |
| 9 | complete | Refine the full 71-row FAQ set into more natural customer-service wording, then republish and verify |
| 10 | complete | Replace raw FAQ/doc imports with audited keep/safe versions and verify residual model risk |

## Decisions

- The website should not rely only on `demo-server.ps1` scripted retrieval. Prefer the real FastGPT app path.
- Keep the business guardrail layer for clarification, lead capture, transfer-to-human, and risky question handling.
- If the FastGPT app path is unstable, allow fallback to the direct model path so the website remains usable.
- Rebuild the FAQ knowledge base as one-question-one-answer records instead of large Markdown-table chunks.
- Use `PROJECT_INDEX.md`, `CURRENT_STATE.md`, `DECISIONS.md`, and `NEXT_ACTION.md` as the default startup context for future sessions.
- FAQ curation should now be maintained through `scripts/build_curated_faq.py` with batch-based humanization rules plus targeted high-frequency overrides, instead of one-off manual CSV edits.
- Contract, customer-tracking, quoting, order-pricing, and internal sales-process materials are now treated as permanent exclusions from the public customer-service knowledge base.

## Errors Encountered

| Error | Attempt | Resolution |
|---|---|---|
| FastGPT app workflow orphan edges | 1 | Rebuilt the `nodes` and `edges` structure |
| FastGPT app AI chat timeout | 2 | Narrowed the issue to model and workflow-node configuration layers; tuning continues |
| FAQ rebuild script encoding breakage | 1 | Rewrote the script path with ASCII-safe handling |
| FastGPT dataset rebuild wrote Chinese as `?` | 1 | Switched Mongo script execution from PowerShell piping to `docker cp` plus in-container `mongosh` execution |
| FastGPT app tune script broke on non-ASCII prompt strings | 1 | Switched app prompt literals in the tuning script to ASCII-safe strings before publishing |
| Demo startup check found Docker engine unavailable | 1 | Started `com.docker.service`, then reran the standard local startup script successfully |
| Real FastGPT app still returns empty chat content | 1 | Confirmed the website stays usable only because `faq_override` catches weak or empty FastGPT replies |
| FastGPT retrieval succeeded but chat prompt still had no injected knowledge | 1 | Added explicit `quoteTemplate` plus `quotePrompt`, then restarted `fastgpt-app` so runtime loaded the repaired workflow |
| Demo requests still fell back after the RAG repair | 1 | Traced the remaining fallback cases to upstream `429` model overload, then added a successful-answer cache in the demo server for repeat questions |

## 2026-04-24 Documentation Restructure

- Added a low-token handoff layer: `PROJECT_INDEX.md`, `CURRENT_STATE.md`, `DECISIONS.md`, `NEXT_ACTION.md`
- Archived older long-form docs into `docs/archive/`
- Changed the root `README.md` into a short navigation page

## 2026-04-24 FastGPT Import Package

- Inspected materials under `C:\Users\Administrator\Desktop\资料\outputs`
- Improved `tools/fastgpt_kb/build_fastgpt_kb.py` to better handle trailing topic names and avoid low-quality page-title FAQ rows
- Generated a final import package under `C:\Users\Administrator\Desktop\资料\outputs\fastgpt_import\final_for_import`

## 2026-04-24 RAG Stabilization

- Fixed `scripts/rebuild-fastgpt-dataset.ps1`, `scripts/register-fastgpt-chat-model.ps1`, and `scripts/tune-fastgpt-rag-app.ps1` to execute Mongo scripts through `docker cp` so UTF-8 content survives end to end
- Rebuilt the FastGPT dataset and confirmed Chinese FAQ rows now persist correctly in Mongo
- Added high-frequency natural-language FAQ aliases such as new-house, odor, environment, and home-decoration questions through `scripts/build_curated_faq.py`
- Retuned the published FastGPT app to use broader FAQ-oriented retrieval settings and republished the workflow
- Hardened `scripts/demo-server.ps1` so weak FastGPT answers now downgrade into `faq_override` instead of leaking low-confidence answers to the website

## 2026-04-24 Doc Chunk Import

- Added `scripts/import-fastgpt-doc-chunks.ps1` to import reviewed `doc_chunks.csv` into the existing FastGPT dataset through official OpenAPI endpoints
- Imported 98 reviewed document chunks into FastGPT virtual collection `gx-yiku-doc-chunks-reviewed`
- Adjusted imported doc-chunk `q` fields to prefer semantic chunk content instead of raw `pdf page=x` or `pptx slide=x` locator titles
- Expanded FAQ aliases further for patent/testing, `硅藻素板`, and `硅藻储能发光板` natural-language phrasings
- Tightened local FAQ matching in `scripts/demo-server.ps1` so exact question matches win before loose overlap matching
 
## 2026-04-27 Knowledge Base Curation Resume

- Continue in the current workspace because planning files and reusable scripts already exist here
- Use `KNOWLEDGE_BASE_TASK_PROMPT.md` as the active scope and output contract for the next knowledge-base pass
- Top-level source items currently visible under `C:\Users\Administrator\Desktop\资料` are `1`, `亿库公司资料(3)`, `亿库硅藻板销售价格23年10月.docx`, `客户最常问的10-50问题及标准回答_20260427084321.docx`, `客户跟踪表-伍国涛2026.4.22.xls`, and `河南青丰.pdf`
- `客户跟踪表-伍国涛2026.4.22.xls` is an immediate exclude candidate because it is customer-tracking business data rather than public customer-service knowledge
- Final refreshed deliverables were assembled under `C:\Users\Administrator\Desktop\资料\outputs\fastgpt_import\final_for_import`
- The final package keeps 20 stable public FAQ rows, flags 10 FAQ rows as `needs_review`, excludes 1 price-related FAQ row, and includes 118 document chunks plus supporting review notes
