# 进度日志

## 2026-04-13

### 已完成
- 识别到用户目标是为广西亿库光养硅藻环保科技有限公司规划 AI 客服技术栈
- 检查本地目录，确认已有 FAQ 数据文件
- 验证 FAQ 文件可正常读取，确认约 47 条问答
- 调研 FastGPT、Dify、OpenAI 模型与 Embedding 的官方资料
- 建立本次工作的规划文件
- 调研 ChatWiki 官方仓库定位与许可证
- 调研智谱 GLM-5、Embedding、内容安全与 GLM-4-Flash 官方资料
- 输出 FastGPT + 智谱 的部署清单
- 输出 FastGPT + 智谱 的配置项表
- 评估公司自用场景下的授权与商用风险
- 根据用户确认，重写文档中的 Agent 规划口径
- 明确区分“开发阶段多 Agent 提速”和“上线运行阶段少 Agent 提速”
- 根据用户新情况，把项目起点改为“只有 xlsx/docx 原始文档，知识库需从零整理”
- 补充“先本地 Docker 挂载跑通，再迁移服务器”的部署建议
- 初始化 Git 仓库并补充项目骨架
- 创建 `data/`、`docs/`、`README.md`、`.gitignore`
- 实现 `tools/knowledge_ingest/` 原始资料整理工具
- 实现 `tools/validate/` 基础校验脚本
- 实现 `web-demo/` 官网客服接入 Demo
- 实现 `infra/fastgpt/` 本地 Docker 脚手架与启动脚本
- 实现 `config/fastgpt/` 配置模板并完成主进程集成收敛
- 修复子代理返回的 2 个坏 JSON 模板

### 当前进行中
- 进行本地静态验证并整理交付说明

### 关键判断
- 当前最适合先做知识库型 AI 客服
- 平台优先选 FastGPT
- 模型要可替换，方便后续按成本和效果切换
- 如果主战场是微信生态，ChatWiki 会比 FastGPT 更强
- ChatWiki 的组织商用限制比 FastGPT 更严格
- 智谱技术栈可行，推荐 `GLM-5 + Embedding-3 + moderation + GLM-4-Flash 质检`
- 若使用智谱官方托管 API，通常按平台服务协议使用即可；“模型商用授权”更像开源模型下载/分发场景，需按具体方式区分
- 开发阶段建议 `4 到 6 个 Agent` 并行推进
- 上线运行阶段建议控制在 `1 个主 Agent + 2 个辅助节点`
- 当前更真实的起点不是“已有 FAQ 知识库”，而是“原始文档待整理”
- 当前本机缺少 `python` 启动器，Python 脚本还没法在本机做编译级验证

### 本轮验证
- `scripts/prepare-data-dirs.ps1` 可执行
- `tools/validate/check_raw_docs.ps1` 可执行
- `tools/validate/check_import_outputs.ps1` 可执行
- `config/fastgpt` 关键 JSON 模板已完成语法修复

### 错误与处理
- 问题：当前环境找不到 `python`
  - 处理：改用 PowerShell 和 JSON 静态校验继续推进，其余验证留待安装 Python 后执行
- 问题：子代理返回的 2 个 JSON 模板语法错误
  - 处理：主进程直接重写为可解析版本

### 待办
- 形成用户可直接使用的技术栈规划文档
- 后续如用户继续推进，可补充：
  - 知识库目录设计
  - 对话流程设计
  - 渠道接入建议
  - 最小可行版本实施清单
## 2026-04-22

### Startup Audit
- Confirmed the Docker-based FastGPT stack is already running from this repo and can also be brought up again with `scripts/start-local.ps1`.
- Verified the main app responds with HTTP 200 on `http://127.0.0.1:3100`.
- Verified the MinIO console responds with HTTP 200 on `http://127.0.0.1:9101`.
- Confirmed the reported `unhealthy` status for `fastgpt-code-sandbox` and `opensandbox-server` comes from a broken `curl` health check, not from a startup failure.
- Confirmed `tools/validate/check_raw_docs.ps1` and `tools/validate/check_import_outputs.ps1` work when launched with `-ExecutionPolicy Bypass`.
- Rebuilt `scripts/demo-server.ps1` so the demo server can parse and start again.
- Replaced `scripts/start-demo.ps1` with a foreground starter so demo startup is stable and visible from the terminal.
- Verified the demo wrapper by launching it in a child process on port `8104` and receiving HTTP 200.

### Remaining Risks
- The copied `.venv` is not usable on this machine because the embedded Python launcher points to a missing base interpreter.
- `tools/validate/check_config.ps1` still cannot parse `infra/fastgpt/.env.local` and needs a separate fix before it can be trusted.

## 2026-04-22

### Validation Repair
- Fixed `tools/validate/check_config.ps1` so it can correctly read and validate `infra/fastgpt/.env.local`.
- Updated `tools/validate/required_keys.txt` to match the actual FastGPT local stack used in this repo.
- Updated `tools/validate/run_all.ps1` so the default config path now points to `infra/fastgpt/.env.local`.
- Added `scripts/rebuild-venv.ps1` to rebuild `.venv`, upgrade `pip`, install `tools/knowledge_ingest/requirements.txt`, and verify core imports.
- Rebuilt the real `.venv` and confirmed `.\.venv\Scripts\python.exe` works with `openpyxl` and `python-docx`.

### Verification
- `powershell -ExecutionPolicy Bypass -File .\tools\validate\check_config.ps1 -ConfigPath .\infra\fastgpt\.env.local -RequiredKeys OPENAI_BASE_URL,CHAT_API_KEY,FASTGPT_PORT,MINIO_PORT`
- `powershell -ExecutionPolicy Bypass -File .\tools\validate\check_config.ps1 -ConfigPath .\missing.env`
- `powershell -ExecutionPolicy Bypass -File .\tools\validate\run_all.ps1`
- `powershell -ExecutionPolicy Bypass -File .\scripts\rebuild-venv.ps1`
- `.\.venv\Scripts\python.exe -c "import openpyxl, docx; print('MAIN_VENV_OK')"`

### Notes
- Two delegated workers were attempted, but both failed before execution due upstream model `503` availability errors. The main agent completed the repairs locally instead.

## 2026-04-22

### Repo Cleanup
- Appended a `Current Verified Commands` section to `README.md` so the repo now documents the validated startup, demo, venv rebuild, and validation commands.
- Moved root-level `tmp_*` investigation files into `tmp/root-archive-2026-04-22/` instead of deleting them.

### Verification
- Confirmed `README.md` contains the new command section.
- Confirmed the repository root no longer contains any `tmp_*` files.

## 2026-04-22

### Demo Polish
- Reworked the demo page presentation so the visible structure is closer to a customer-facing reception page instead of a raw technical demo.
- Updated the frontend chat rendering to soften broken or overly technical fallback responses into more presentation-friendly Chinese copy.
- Updated the demo server fallback flow so it prefers valid FAQ CSV data and ignores obviously corrupted imported JSON samples.
- Confirmed `http://127.0.0.1:8099` is reachable again after restarting the demo server.
