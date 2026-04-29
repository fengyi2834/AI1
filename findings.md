# Findings

## FastGPT Current State

- A local FastGPT app already exists: `Guangxi Yiku AI Customer Service`
- App ID: `s69e0562ea67193262b8de666`
- App OpenAPI key exists: `fgtest-001`
- Current real endpoint: `http://127.0.0.1:3100/api/v1/chat/completions`

## Dataset State

- The app references dataset ID `s69e03880d9b607f9459582d6`
- Dataset name: `gx-yiku-faq`
- The dataset exists and is not empty
- Current `dataset_datas` granularity is weak because many FAQ items were stored as large Markdown-table blocks
- Current `dataset_data_texts` content is too coarse for stable FAQ retrieval

## Web Layer State

- `web-demo/js/app.js` sends requests to `/api/ai/chat`
- `scripts/demo-server.ps1` owns the actual chat routing logic
- The web layer already supports `CHAT_BACKEND=fastgpt_prefer`
- Current intended behavior is: try the real FastGPT app first, then fall back to the direct model path only if FastGPT fails

## Verified Behavior

- Low-intent greeting questions are clarified first instead of immediately dumping product details
- The current question "is it suitable for a new house" can still return `live_model_fallback`
- That proves the website is attempting the FastGPT app path, but FastGPT is still not stable enough

## Documentation Structure Findings

- The token problem came from repeated context spread across `README.md`, planning notes, and long reference docs
- A stable four-file startup path is now available for future sessions
- Historical planning and checklist material was moved under `docs/archive/` so it stays available without being in the default read path

## FastGPT Import Findings

- The latest external export bundle was under `C:\Users\Administrator\Desktop\资料\outputs\fastgpt_import`
- The original FAQ outputs mixed page-level labels, trailing product names, and some cross-product answer contamination
- The source slides/pages appear to use a trailing-topic layout in several places, so topic names often come after the feature/application text
- After script refinement, the current final package contains 10 FAQ rows and 98 document chunks for import
- The safest import path is to use FAQ plus document chunks together, and quickly review the `page=10~12` items before production use

## 2026-04-24 RAG Stabilization Findings

- The earlier dataset rebuild path had a hidden encoding bug: piping UTF-8 Mongo scripts from PowerShell into `docker exec mongosh` turned Chinese FAQ content into `?` in `dataset_datas`
- After changing those maintenance scripts to copy `.js` files into the container first, the same dataset rebuild preserved Chinese questions and answers correctly
- FastGPT `searchTest` shows the current FAQ dataset can answer exact FAQ-style questions well with `fullTextRecall`, but natural-language paraphrases such as `新房适合用吗` still need either alias rows or a stronger semantic index
- Published app behavior remains weaker than the local website fallback for several high-frequency sales questions, especially when the app answers with apology-style or follow-up-heavy text
- The most practical website-side stabilization is to keep `fastgpt_prefer`, but classify weak FastGPT replies as non-production and replace them with local FAQ-backed answers using a distinct `faq_override` mode

## 2026-04-24 Doc Chunk Import Findings

- Reviewed `doc_chunks.csv` is now imported into the same FastGPT dataset through OpenAPI, under virtual collection `gx-yiku-doc-chunks-reviewed`
- After changing imported chunk `q` values from raw locator titles to semantic chunk text, `searchTest` top hits became much more usable for questions like `硅藻板环保吗`, `硅藻素板适用范围是什么`, and `硅藻储能发光板适合什么场景`
- Similar-question expansion is practical here: alias rows work well for the website-facing `faq_override` path and are much cheaper than continuing to wait on FastGPT app direct generation to become stable
- The main remaining blocker is the FastGPT app workflow itself: recent `llm_request_records` still show the model often behaving as if retrieved knowledge was not injected into the final prompt, or spending output budget on `reasoningText` while leaving `answerText` empty
- Current conclusion: the knowledge layer is materially stronger now, but the website override layer is still required for production-like stability

## 2026-04-27 Startup Validation Findings

- `scripts/start-local.ps1` starts cleanly once the Docker Desktop service `com.docker.service` is running
- `scripts/start-demo.ps1` serves the demo successfully on `http://127.0.0.1:8099/`
- `http://127.0.0.1:3100/` and `http://127.0.0.1:8099/` both returned HTTP 200 during this validation run
- Demo chat for `你好` returned mode `clarify`, which matches the intended low-intent guardrail behavior
- Demo chat for `新房适合用吗？` and `产品有专利和检测报告吗？` both returned mode `faq_override`, not `fastgpt_app`
- Direct FastGPT app calls to `http://127.0.0.1:3100/api/v1/chat/completions` with key `fgtest-001` still returned empty `choices[0].message.content`
- The user-visible demo is usable, but the real FastGPT app path is still not healthy enough to count as stable RAG
- The sampled demo fallback path is noticeably slow: the two measured requests took about `14.6s` and `28.7s`

## 2026-04-27 RAG Repair Findings

- The FastGPT dataset search node was already returning non-empty `quoteList`, so retrieval itself was not the root failure
- The real root cause was in the chat node configuration: retrieved knowledge was not being injected into the final model prompt, even when retrieval succeeded
- A second issue compounded the failure: the chat node was effectively running with the old `glm-5` runtime config until `fastgpt-app` was restarted, so the model spent output budget in `reasoningText` while `answerText` stayed empty
- After updating the chat node to use a valid `quoteQA` reference, an explicit `quoteTemplate`, an explicit `quotePrompt`, and the non-reasoning model `glm-4-flash-250414`, the direct FastGPT app path began returning real answers again
- After the restart, `chat_item_responses` showed `historyPreview` now includes the retrieved knowledge block and the AI node returns `answerText` with `finishReason: stop`
- Demo verification now shows common questions can return mode `fastgpt_app` instead of dropping to `faq_override`
- Upstream model overload can still happen. One captured FastGPT run failed with `429 该模型当前访问量过大，请您稍后再试`, which explains why some demo requests still fall back even though the workflow is now configured correctly
- To reduce repeated waits and lower fallback frequency, the demo server now caches successful FastGPT answers by normalized question and can serve repeat hits as `fastgpt_cache`

## 2026-04-27 DOCX FAQ Import Findings

- Source file `C:\Users\Administrator\Desktop\资料\亿库公司资料(3)\亿库公司资料\客户最常问的10-50问题及标准回答.docx` was converted into a clean FAQ CSV with 31 `question,answer` rows
- The new reusable conversion script is `scripts/build_docx_faq_csv.py`
- The new reusable FastGPT import script is `scripts/import-fastgpt-faq-csv.ps1`
- The imported FAQ collection name is `gx-yiku-customer-top-10-50-docx`
- The new collection was added into dataset `69e03880d9b607f9459582d6` as virtual collection `69eec926fe467f0f1a5311b1`
- Direct FastGPT verification succeeded after import:
- `亿库硅藻板防霉等级是多少？` -> `0级`
- `硅藻板对宠物友好吗？` -> returned the new pet-friendly FAQ answer from the DOCX material
- 
## 2026-04-27 Knowledge Base Prompt Handoff Findings

- `docs/tasks/KNOWLEDGE_BASE_TASK_PROMPT.md` formalizes the current scope, classification rules, and output contract for knowledge-base curation under `C:\Users\Administrator\Desktop\资料`
- The required class model is explicit: each candidate should be judged as FAQ, document chunk, exclude from the public customer-service KB, or needs manual review
- The expected deliverables are `faq.csv`, `faq_with_sources.csv`, `doc_chunks.csv`, `product_knowledge.md`, `review_notes.md`, and optionally `excluded_files.md`
- The repository already contains reusable scripts named in the prompt, including `scripts/build_docx_faq_csv.py`, `scripts/import-fastgpt-faq-csv.ps1`, `scripts/import-fastgpt-doc-chunks.ps1`, `tools/knowledge_ingest/ingest.py`, and `tools/fastgpt_kb/build_fastgpt_kb.py`
- Current top-level source items under `C:\Users\Administrator\Desktop\资料` are 2 directories plus 4 files
- `客户跟踪表-伍国涛2026.4.22.xls` is a clear exclude candidate because it contains customer-tracking business data rather than public-facing product knowledge
- The two FAQ DOCX files are byte-identical duplicates, so only one should be treated as the primary source of truth
- The safest public doc-chunk candidates in the current source set are `亿库简介(3).pdf`, `功能性硅藻板材20241024.pptx`, and `硅藻板宣传册.pptx`
- `河南青丰.pdf` currently extracts as empty pages, so it should stay in `needs_review` until OCR or a better source file is available

## 2026-04-27 FAQ Second-Pass Refinement Findings

- The first-round FAQ cleanup removed the most obvious script tone, but many rows still sounded like edited standard answers rather than natural sales-consultant speech
- The most efficient maintenance path is not direct CSV hand-editing; it is a reusable generator with batch-level style rules plus high-frequency question overrides
- The 71-row FAQ set now works better when grouped into five rewrite batches: company basics, core capabilities, user experience, application scenarios, and credential/commercial questions
- Re-importing the refreshed curated FAQ set into FastGPT materially improves the base wording of retrieved answers, but FastGPT generation still sometimes adds extra consultant-like filler or redundant human-handoff phrasing
- Because of that remaining generation variance, the website-side `Format-CustomerServiceAnswer` cleanup layer is still useful even after the FAQ source text becomes stronger
- The refreshed final package under `C:\Users\Administrator\Desktop\资料\outputs\fastgpt_import\final_for_import` contains 20 stable FAQ rows, 31 audited FAQ rows, 118 doc chunks, review notes, and an exclusion ledger

## 2026-04-28 Knowledge-Base Cleanup Findings

- The company-provided `C:\Users\Administrator\Desktop\zi liao` package did not reveal a large missing public source set; the bigger issue was that usable public knowledge was mixed together with contracts, price sheets, customer tracking, and internal sales/ops material
- The audited `faq_with_sources.csv` is a much safer source of truth than the raw DOCX FAQ export because it already separates `keep`, `needs_review`, and `exclude`
- The 20 `keep` FAQ rows from that audited file were already present in the raw `customer_top_10_50_docx.csv` source set, but the raw set also contained risky claims about price, allergy, odor, signal shielding, and health effects
- Splitting public doc chunks by risk rules reduced the active reviewed chunk set from 118 rows to 82 rows, with 36 rows moved into a separate review-only file
- `河南青丰.pdf` is currently a 2-page image-only PDF with zero extractable text via PyMuPDF, and there is no OCR engine installed locally, so it cannot be responsibly imported yet
- Even after removing high-risk FAQ rows and deleting the stale coarse FAQ file collection, direct FastGPT generation can still infer unsupported answers from nearby context; this confirms that dataset cleanup alone is not enough and generation constraints still need tightening

## 2026-04-28 Model and Vision Benchmark Findings

- The current FastGPT customer-service chain is still text-only in practice: `web-demo/js/app.js` submits only `question` and `history`, while `scripts/demo-server.ps1` forwards only a text `messages` array to the FastGPT app endpoint
- The published FastGPT app workflow already contains a `userFiles` output and a `fileUrlList` input path, but the chat node is explicitly configured with `aiChatVision=false`, so image understanding is not active in the current app version
- FastGPT model metadata currently marks `glm-4-flash-250414` as `vision=false` and `reasoning=false`, while `glm-5` is registered as `vision=false` and `reasoning=true`
- Direct FastGPT app benchmarking on 2026-04-28 showed the current `glm-4-flash-250414` path returning usable answers in about `2.82s`, `4.07s`, and `3.09s` for three representative customer-service questions
- Repeating the same FastGPT workflow benchmark after switching only the chat model from `glm-4-flash-250414` to `glm-5` caused all three test requests to return empty answer content after about `8.35s`, `7.12s`, and `12.3s`
- The practical conclusion for this project is that `glm-5` cannot currently replace the main FastGPT customer-service answer model without additional workflow or provider-adapter changes
- Direct Zhipu image-understanding tests with the provided screenshot showed `glm-4v-flash` answering correctly in about `0.98s`, `glm-5v-turbo` answering correctly in about `7.44s`, and `glm-5` answering incorrectly (`gpt-4o`) after about `14.14s`
- The practical multimodal conclusion is that if the website needs real user image chat, the image-capable candidates should come from the vision family such as `glm-4v-flash` or `glm-5v-turbo`, not the text-only `glm-5`
- The current English system prompt and quote prompt are serviceable, but they are not ideal for a Chinese knowledge base plus Chinese customer-service workflow; the bigger blocker is still model and modality fit, not prompt language alone

## 2026-04-28 Image Chat Implementation Findings

- The safest near-term delivery path was not to rewire FastGPT internal vision workflow nodes immediately; it was to keep the published FastGPT text RAG path for normal questions and add a separate direct `glm-4v-flash` branch inside `scripts/demo-server.ps1` for image-bearing requests
- The updated demo client now sends optional `imageDataUrl` and `imageName` fields to `/api/ai/chat`, which is enough for a workable local multimodal demo without introducing multipart form parsing into the custom PowerShell HTTP server
- For screenshot-style visual questions, `glm-4v-flash` returned correct answers through the new demo-server path in about `3.07s`, which is fast enough for an interactive local customer-service demo
- For image-only requests, the vision path is materially more stable when the default instruction is narrowed to visible-content summarization only; broad no-question prompts encourage extra inference even on the vision model
- The published FastGPT app runtime now stores Chinese `quotePrompt` and `systemPrompt` values for the `gxChatNode`, so the configuration shown in the FastGPT admin UI is no longer English-only

## 2026-04-28 Vision Workflow and Storage Findings

- The local environment already has usable object storage for images: `fastgpt-minio` serves `fastgpt-public` and `fastgpt-private`, with `STORAGE_EXTERNAL_ENDPOINT=http://192.168.77.97:9100` and the FastGPT app itself using `STORAGE_S3_ENDPOINT=http://fastgpt-minio:9000`
- Multi-megabyte image storage is practical in the current stack. The running `fastgpt-app` container reports `UPLOAD_FILE_MAX_SIZE=1000` and `UPLOAD_FILE_MAX_AMOUNT=1000`, so the practical bottleneck for a few-megabyte real photo is much more likely to be frontend upload time or user download time than FastGPT storage itself
- FastGPT official OpenAPI supports multimodal chat through message content items like `image_url` and `file_url`, but it does not act as a raw binary file-upload endpoint; images must be uploaded to object storage first and then referenced by URL
- The new helper script `scripts/upload_minio_public.py` successfully uploads local images into the existing public MinIO bucket, producing URLs that were confirmed reachable from both the host and the local FastGPT environment
- The first attempt to switch the published FastGPT app workflow to `glm-4v-flash` failed with `404 The model glm-4v-flash does not exist or you do not have access to it`, even though the FastGPT workflow JSON and Mongo system-model metadata were correct
- The real root cause was `fastgpt-aiproxy`: the active `channels.models` allowlist for `zhipu-local` did not include `glm-4v-flash`, so FastGPT could never route that model successfully until the allowlist was updated
- After adding `glm-4v-flash` into the aiproxy channel model list and restarting `fastgpt-aiproxy` plus `fastgpt-app`, the direct FastGPT app endpoint began handling both text-only and image-bearing requests successfully
- Measured latency after the visual FastGPT upgrade remained acceptable for direct app use in this environment: about `3.72s` for a text-only request and about `2.63s` for a screenshot-based image question
- The richer two-stage `demo-server` image fusion path is slower because it performs extra work on purpose: local testing showed about `6.24s` for image + text fusion and about `4.92s` for image-only summarization

## 2026-04-28 Board Image Catalog Findings

- The folder `C:\Users\Administrator\Desktop\AI1\tu` contained four real board-photo assets: `背景墙.jpg`, `菜板.jpg`, `防火板.jpg`, and `隔音板.jpg`, each roughly `3.5MB` to `4.3MB`
- All four images were successfully uploaded into the existing public MinIO bucket and indexed in `data/image_catalog/board_images.json`
- A deterministic local image-answer branch is better than asking the model to decide which sample photo to send each time; it is faster, avoids hallucinated image references, and can return the exact stored URL reliably
- The new image branch now handles both specific and generic user intents:
- specific requests such as `防火板样板图` or `隔音板照片` return the single matching image
- generic requests such as `想看样板图` or `把四种板的实拍图都发我看看` return all four indexed images
- The returned image URLs currently use the local storage endpoint `http://192.168.77.97:9100/...`, which is suitable for the current local/LAN demo but will not be reachable to users outside that network unless a public domain or proxy is added later
