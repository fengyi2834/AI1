# AI客服项目调研结论

## 一、业务侧现状
- 当前项目目录中存在 `广西亿库光养硅藻板知识库FAQ.csv`
- 该 CSV 已确认可正常以 UTF-8 读取
- 数据规模约 47 条 FAQ，字段为 `question`、`answer`
- 已抽样确认内容覆盖：
  - 公司介绍
  - 成立时间、注册资金、地址
  - 企业定位
  - 核心产品说明
  - 产品功能说明

结论：
- 现有数据更适合先做“知识库问答型客服”
- 第一阶段可直接服务官网访客、微信咨询和销售前置问答
- 还不适合直接做复杂售后工单流转或强业务决策 Agent

## 二、平台候选调研

### 1. FastGPT
结论摘要：
- FastGPT 官方文档说明其定位是基于大语言模型的知识库问答系统，并结合可视化工作流
- 支持标准 API 接入，支持多种主流模型，适合知识库客服快速搭建
- 对现有 FAQ、文档、PDF 等知识资料较友好

适合本项目的原因：
- 中文生态更友好
- 知识库问答是它的强项
- 可视化工作流适合后续把“问答 + 留资 + 人工转接”串起来
- 对中小企业来说，上线速度快，维护成本较低

参考来源：
- https://doc.fastgpt.cn/
- https://doc.fastgpt.cn/en/docs/introduction

### 2. Dify
结论摘要：
- Dify 官方文档显示它是一个开源 AI 工作流平台，支持工作流、Chatflow、知识库、API 和 Web 发布
- 它更偏“通用 AI 应用平台”，适合后续扩展复杂工作流

适合本项目的程度：
- 能做，但第一阶段未必比 FastGPT 更省心
- 如果后续要做更多内部 AI 应用，Dify 也值得保留为备选

参考来源：
- https://docs.dify.ai/en/introduction
- https://docs.dify.ai/en/use-dify/getting-started/key-concepts
- https://docs.dify.ai/en/guides/knowledge-base/readme
- https://docs.dify.ai/en/use-dify/publish/README

## 三、模型层调研

### 1. OpenAI GPT-5 mini
结论摘要：
- OpenAI 当前文档将 GPT-5 mini 描述为适合低延迟、高并发、成本敏感场景
- 对客服问答、结构化输出、工具调用都比较合适

参考来源：
- https://developers.openai.com/api/docs/models/gpt-5-mini
- https://developers.openai.com/api/docs/models

### 2. OpenAI GPT-4.1 mini
结论摘要：
- 价格更低，适合成本敏感场景
- 也支持较长上下文和工具调用
- 可作为更便宜的备用模型

参考来源：
- https://developers.openai.com/api/docs/models/gpt-4.1-mini
- https://openai.com/index/gpt-4-1/

### 3. 向量模型
结论摘要：
- OpenAI 官方文档显示 `text-embedding-3-small` 成本较低，适合做知识检索
- 对中小知识库场景性价比较高

参考来源：
- https://platform.openai.com/docs/models/text-embedding-3-small
- https://platform.openai.com/docs/guides/embeddings/embedding-models%20.class

## 四、对本项目的判断
- 如果用户输入的 `flshGPT` 指的是 `FastGPT`，那么它是当前最适合本项目的第一阶段平台
- 推荐采用“三层结构”：
  - 平台层：FastGPT
  - 模型层：默认主模型 + 备用模型
  - 渠道层：官网、微信公众号/企业微信、后续再扩展其他渠道
- 第一阶段先把 80% 重复咨询自动化，不追求一次做成全能机器人

## 五、建议的第一阶段功能边界
- 公司介绍与品牌问答
- 产品介绍与卖点问答
- 常见应用场景问答
- 基础招商/合作问答
- 留资收集
- 转人工

暂不建议第一阶段就做：
- 复杂报价自动生成
- 售后工单全流程自动化
- 多系统深度打通
- 语音客服

## 六、FastGPT 与 ChatWiki 的差异

### 1. FastGPT
官方文档与仓库显示：
- FastGPT 重点是通用型知识库问答、RAG 检索、可视化工作流和标准 API 接入
- 支持通过 API 接入企业官网、企微、飞书等多种渠道
- 更适合“官网 AI 客服”“企业知识库问答”“可控扩展的业务流程”

适合本项目的点：
- 官网场景更自然
- 平台相对通用，不被微信生态绑定
- 适合先做轻量问答 + 留资 + 转人工

参考来源：
- https://doc.fastgpt.cn/
- https://github.com/labring/FastGPT

### 2. ChatWiki
官方仓库 README 显示：
- ChatWiki 产品定位更偏“微信生态工作流自动化平台”
- 深度集成公众号私信、留言、关注/取关、菜单点击等触发器
- 支持人机协同客服、问答知识库、未知问题聚类、从人工对话总结 FAQ
- 技术栈包含 `golang + python + PostgreSQL16 + pgvector + zhparser`

适合本项目的点：
- 如果未来重心在公众号、微信客服、微信小店客服，ChatWiki 会更强
- 如果希望“微信生态获客 + AI 回复 + 人工客服协同”一体化，它比 FastGPT 更贴微信业务

参考来源：
- https://github.com/zhimaAi/chatwiki

### 3. 当前判断
- 如果广西亿库第一阶段主战场是官网客服，优先 `FastGPT`
- 如果第一阶段主战场是微信公众号/微信客服，并且要深度自动化运营，`ChatWiki` 值得重点考虑
- 如果你们后续两边都要，技术上可以采用：
  - 平台主线：FastGPT
  - 微信运营增强：ChatWiki
  但这会明显增加维护复杂度，不建议第一阶段就双平台并行

## 七、商用与版权/许可注意事项

### 1. FastGPT 许可
FastGPT 官方开源协议说明：
- 基于 Apache 2.0，但附加条件
- 允许作为后台服务直接商用
- 未经授权不得做类似官方云服务的多租户 SaaS
- 未经商业授权，商用服务需保留相关版权信息和 LOGO

参考来源：
- https://doc.fastgpt.cn/docs/agreement/open-source/
- https://github.com/labring/FastGPT

### 2. ChatWiki 许可
ChatWiki 官方仓库 LICENSE 明确写到：
- 基于 Apache License 2.0，但带附加条件
- 个人可免费商用
- 公司/组织用于商业目的时，需要向出品方获取商业许可
- 未经书面授权，不允许用源码运营多租户 SaaS
- 如果使用其前端组件，不得移除或修改 ChatWiki 的 logo、商标或版权信息

参考来源：
- https://github.com/zhimaAi/chatwiki/blob/main/LICENSE

### 3. 业务资料版权风险
就企业 AI 客服本身而言，通常最容易踩坑的不是模型，而是“你喂给模型的数据”：
- 公司自有 FAQ、产品资料、招商资料：通常风险最低
- 转载的竞品文案、行业报告、图片、视频、宣传册：需要确认使用权
- 微信文章、官网抓取、第三方案例：要确认是否有转载和商用权
- 品牌 logo、商标、专利图片：要确认是否为自有或已获授权

### 4. 模型服务条款
使用智谱 API 时，还需要遵守其开放平台服务协议和内容安全规则。

参考来源：
- https://docs.bigmodel.cn/cn/terms/service-agreement
- https://docs.bigmodel.cn/cn/guide/platform/securityaudit

说明：
- 这部分属于通用合规提醒，不等同于正式法律意见

## 八、智谱模型选型结论

### 1. 主模型
截至 2026-04-13，智谱官方文档已提供 `GLM-5`。

我的判断：
- 如果你希望中文理解、复杂问答、流程扩展能力更强，`GLM-5` 可以作为主模型
- 对广西亿库这种企业客服场景，它是能用的，而且更符合国内商用落地习惯

参考来源：
- https://docs.bigmodel.cn/cn/guide/models/text/glm-5

### 2. 向量模型
智谱官方确实提供向量模型：
- `Embedding-2`
- `Embedding-3`

建议：
- 优先 `Embedding-3`
原因：
- 支持更灵活的向量维度
- 明确面向高精度语义搜索和知识库场景

参考来源：
- https://docs.bigmodel.cn/cn/guide/models/embedding/embedding-2
- https://docs.bigmodel.cn/cn/guide/models/embedding/embedding-3

### 3. 审核模型要不要加 GLM-4-Flash
截至 2026-04-13，智谱官方仍提供 `GLM-4-Flash-250414`，它具备低成本和较长上下文能力。

我的判断：
- 可以加，但更适合做“业务审核/答案质检”
- 不建议把它当成唯一的“内容安全审核”

更合理的分工是：
- 内容安全审核：优先用智谱官方 `moderation` 内容安全接口
- 业务质检审核：可用 `GLM-4-Flash-250414` 检查回答是否跑题、是否缺少依据、是否应该转人工

参考来源：
- https://docs.bigmodel.cn/api-reference/工具-api/内容安全
- https://docs.bigmodel.cn/cn/guide/models/text/glm-4
- https://docs.bigmodel.cn/cn/guide/models/free/glm-4-flash-250414

### 4. 推荐的智谱版组合
- 平台：FastGPT
- 主模型：GLM-5
- 向量模型：Embedding-3
- 内容安全：moderation
- 业务质检：GLM-4-Flash-250414
- 渠道：官网优先，微信第二阶段接入
## 2026-04-22 Startup Findings
- `docker compose ... ps` shows the FastGPT stack is up, including `fastgpt-app`, Mongo, Redis, MinIO, Postgres, plugin, and MCP server.
- `http://127.0.0.1:3100` returns HTTP 200, so the main FastGPT web app is reachable.
- `http://127.0.0.1:9101` returns HTTP 200, so the MinIO console is reachable.
- `fastgpt-code-sandbox` and `opensandbox-server` show `unhealthy`, but Docker health details show the probe itself is failing because `curl` is missing in the container image. Logs still show successful startup and HTTP 200 sandbox responses.
- Local raw-doc and import-output validation scripts succeed when run with `-ExecutionPolicy Bypass`.
- `.venv\\Scripts\\python.exe` is broken after the project was copied; the launcher still points at a missing base interpreter, so local Python-based workflows should not rely on this copied venv.
- `scripts/demo-server.ps1` had become syntactically corrupted and was replaced with a clean server implementation that preserves the same demo API routes and static-file serving behavior.
- `scripts/start-demo.ps1` now acts as a reliable foreground starter. A child-process verification against port `8104` returned HTTP 200.
- `tools/validate/check_config.ps1` still reports all keys missing for `infra/fastgpt/.env.local`; this looks like a parser or file-format compatibility issue rather than missing values.

## 2026-04-22 Validation Repair Findings
- The original parse failure in `check_config.ps1` was not a missing-config problem. It was a Windows PowerShell compatibility problem across three layers: UTF-8 `.env.local` reading, regex-based parsing, and comma-separated `-RequiredKeys` arriving as a single string when invoked through `powershell -File`.
- Replacing regex parsing with explicit split-at-first-`=` parsing made the `.env` reader stable.
- Normalizing a single comma-separated `RequiredKeys` string fixed the false "all keys missing" result when the script is called from the command line.
- `tools/validate/required_keys.txt` was stale for this repo and was updated to `OPENAI_BASE_URL`, `CHAT_API_KEY`, `FASTGPT_PORT`, and `MINIO_PORT`.
- `tools/validate/run_all.ps1` now defaults to `infra/fastgpt/.env.local`, which matches this repository's real config location.
- `scripts/rebuild-venv.ps1` was added and verified successfully against both a temporary test venv and the real `.venv`.
- Rebuilding the real `.venv` completed successfully, and `.\.venv\Scripts\python.exe` now imports `openpyxl` and `docx` correctly.
- The rebuilt `pyvenv.cfg` still points to the Python Store launcher path under `AppData\Local\Microsoft\WindowsApps`, but that path now exists on this machine and the venv is working normally.
- Both delegated workers failed before execution with upstream model `503` responses, so the main agent completed both repairs locally.
