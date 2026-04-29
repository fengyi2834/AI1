# AGENT.md

## 1. 这是什么项目

这是一个面向“广西亿库光养硅藻环保科技有限公司”的本地 AI 客服项目，核心目标是把原先偏演示性质的脚本式问答流程，逐步升级成一个可测试、可迭代的 FastGPT RAG 客服系统，同时保留业务护栏层。

项目当前已经覆盖这几条主线：

- FastGPT 本地部署与知识库接入
- 官网聊天演示页 `web-demo/`
- 文本 FAQ / 文档知识库清洗与导入
- 图片咨询能力（视觉模型）
- 板材样板图 / 实拍图返回能力

一句话理解当前工程：

`源资料 -> 清洗后的 FAQ / 文档 / 图片目录 -> FastGPT / demo-server -> 网页客服演示 -> 本地验证`

---

## 2. 新对话建议先读什么

如果是新开对话，默认先读这些文件：

1. `AGENT.md`
2. `PROJECT_INDEX.md`
3. `CURRENT_STATE.md`
4. `DECISIONS.md`
5. `NEXT_ACTION.md`

如果要继续工程细节，再读：

- `task_plan.md`
- `findings.md`
- `progress.md`

这三份是“工作记忆”，很详细，但也更长。

---

## 3. 项目目标和当前阶段

### 总目标

把客服从“能演示”推进到“真实可测”的 FastGPT RAG 方案，并尽量减少模型瞎推断。

### 当前已完成的大项

- FAQ / 文档知识库多轮清洗与导入
- FastGPT 工作流修复与提示词中文化
- 文本客服链路可跑通
- 图片客服链路可跑通
- FastGPT 视觉工作流已启用
- 四种板材样板图 / 实拍图已接入

### 当前还没彻底解决的点

- FastGPT 虽然能回答，但仍可能比本地兜底更“泛”或更会推断
- 图片请求在 `demo-server` 里有时仍会走本地 `vision_rag` 兜底，而不是稳定命中 FastGPT 视觉结果
- 图片 URL 当前仍是局域网地址，外网不可直接访问

---

## 4. 当前系统架构

### 4.1 本地服务层

- FastGPT 主服务：`http://127.0.0.1:3100/`
- 网页演示客服：`http://127.0.0.1:8099/`
- MinIO 对象存储：
  - 局域网访问：`http://192.168.77.97:9100/`
  - 本机访问：`http://127.0.0.1:9100/`

### 4.2 主要聊天链路

当前有两条主要问答链：

1. **FastGPT 应用链**
   - 真实 FastGPT 工作流
   - 已接知识库
   - 已切到中文提示词
   - 已启用视觉模型 `glm-4v-flash`

2. **`scripts/demo-server.ps1` 控制链**
   - 前端 `/api/ai/chat` 实际落到这里
   - 负责业务护栏
   - 负责文本 fallback
   - 负责图片上传到 MinIO
   - 负责图片理解 / 本地视觉兜底
   - 负责板材图片目录直返

### 4.3 文字与图片的当前分工

- 纯文本问题：优先走 FastGPT，失败再 fallback
- 普通带图问题：优先尝试 FastGPT 视觉工作流；若不稳，`demo-server` 可回退到本地视觉融合
- “我要看样板图/实拍图/照片”类请求：不走模型判断，直接按本地图片目录返回对应图片

---

## 5. 关键目录说明

- `infra/fastgpt/`
  - FastGPT 本地 docker 配置
  - `.env.local` 是当前本地运行环境核心配置

- `scripts/`
  - 本项目最关键的工程脚本目录
  - 包含启动、重建知识库、调优 FastGPT、上传图片到 MinIO 等脚本

- `config/fastgpt/`
  - 模型配置模板
  - 提示词
  - 工作流模板

- `data/faq/`
  - FAQ 来源与整理后 CSV

- `data/import_ready/`
  - 当前导入用知识资产
  - 包括安全文档块、图片目录文本记录等

- `data/image_catalog/`
  - 当前图片目录索引
  - 例如：`board_images.json`

- `web-demo/`
  - 本地网页客服演示页

- `tu/`
  - 本地板材图片源目录

- `docs/tasks/`
  - 可复用任务说明，如知识库清洗范围

---

## 6. 当前关键文件

### 6.1 交接与状态文件

- `PROJECT_INDEX.md`
- `CURRENT_STATE.md`
- `DECISIONS.md`
- `NEXT_ACTION.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

### 6.2 启动与主脚本

- `scripts/start-local.ps1`
- `scripts/start-demo.ps1`
- `scripts/demo-server.ps1`
- `scripts/tune-fastgpt-rag-app.ps1`
- `scripts/register-fastgpt-chat-model.ps1`
- `scripts/upload_minio_public.py`

### 6.3 提示词

- `config/fastgpt/prompts/demo_live_system_prompt.md`
- `config/fastgpt/prompts/demo_vision_system_prompt.md`
- `config/fastgpt/prompts/system_prompt.md`

### 6.4 图片目录

- `data/image_catalog/board_images.json`
- `data/import_ready/board_image_catalog.md`

---

## 7. 怎么启动项目

在项目根目录 `C:\Users\Administrator\Desktop\AI1` 下执行：

### 第一步：启动 FastGPT 本地栈

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-local.ps1
```

### 第二步：启动网页演示客服

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-demo.ps1 -Port 8099
```

### 启动后主要访问地址

- FastGPT：`http://127.0.0.1:3100/`
- 网页演示页：`http://127.0.0.1:8099/`

前提：

- Docker Desktop 已启动
- `infra/fastgpt/.env.local` 存在
- 智谱 API Key 已配置到 `.env.local`

---

## 8. 当前模型与视觉能力现状

### 8.1 结论

- 当前文本主链路不适合直接换成 `glm-5`
- 当前视觉模型主选是 `glm-4v-flash`

### 8.2 为什么不用 `glm-5` 做主客服

之前实测过：

- `glm-4-flash-250414`：文本链路稳定、速度可接受
- `glm-5`：在当前 FastGPT 工作流里出现过空回答和明显变慢

所以当前策略是：

- 文本主链路：`glm-4-flash-250414`
- 视觉链路：`glm-4v-flash`

### 8.3 FastGPT 视觉链路曾经踩过的坑

FastGPT 视觉工作流不是只改工作流 JSON 就够，曾经卡过：

1. Mongo 里的 `system_models` 没注册视觉模型
2. `chatConfig.fileSelectConfig.canSelectImg` 没打开
3. `aiChatVision` 没打开
4. `fastgpt-aiproxy` 的 `channels.models` 白名单没加 `glm-4v-flash`

这几个如果少一个，就可能表现成：

- 模型选得到但跑不通
- 图片能选但接口报错
- 视觉模型 404

---

## 9. 图片咨询当前是怎么做的

### 9.1 用户上传图片

前端会把图片转成 `dataUrl` 送到 `demo-server`。

### 9.2 `demo-server` 会做什么

根据场景分成三类：

1. **普通图片问答**
   - 尝试上传图片到 MinIO
   - 尝试走 FastGPT 视觉工作流
   - 如果不稳，可回退到本地视觉理解 + FAQ/RAG 融合

2. **只发图片不写问题**
   - 优先做图片内容总结
   - 避免模型无约束地自行延展

3. **想看样板图 / 实拍图 / 照片**
   - 直接走图片目录逻辑
   - 不依赖模型决定发哪张图

### 9.3 为什么要保留本地图片目录直返

因为“发图给用户看”这件事更适合确定性逻辑，而不是大模型自由发挥。

优点：

- 快
- 稳
- 不会编不存在的图
- 不会把 A 板图发成 B 板图

---

## 10. 当前四种板材图片资产

来源目录：

- `C:\Users\Administrator\Desktop\AI1\tu`

当前已接入的四张图：

- 背景墙板
- 菜板
- 防火板
- 隔音板

索引文件：

- `data/image_catalog/board_images.json`

文本记录：

- `data/import_ready/board_image_catalog.md`

当前支持的典型问法：

- `我想看防火板样板图`
- `发下隔音板照片`
- `把四种板的实拍图都发我看看`
- `想看样板图`

这些请求当前会直接返回 Markdown 图片链接，前端会把图渲染出来。

---

## 11. 知识库现状

### 11.1 当前主知识来源

- 精修 FAQ 集合
- 审核后的 DOCX FAQ 集合
- 审核后的 doc chunks 集合

### 11.2 当前活跃集合

- `gx_yiku_fastgpt_faq_curated`：91 行
- `gx-yiku-customer-top-10-50-docx`：20 行审核保留 FAQ
- `gx-yiku-doc-chunks-reviewed`：82 条安全文档块

### 11.3 当前知识库策略

- FAQ 走“一问一答”
- 风险内容严格清理
- `needs_review` 不进活跃集合
- 价格、合同、客户跟踪、内部销售材料不进公开客服知识库

---

## 12. 目前最重要的经验和坑

### 12.1 不要把 fallback 成功当成 FastGPT 健康

网页能答，不代表 FastGPT 本体就答得好。

### 12.2 不要轻易把模型主链路切到 `glm-5`

它在当前链路里历史上表现不好。

### 12.3 提示词必须尽量中文化、边界化

尤其是这类中文客服项目，中文提示词更稳。

### 12.4 图片链路的关键不只是模型

还包括：

- MinIO / 对象存储
- 可访问 URL
- FastGPT 视觉开关
- aiproxy 模型白名单

### 12.5 板材样图不要依赖模型自由决定

样板图 / 实拍图发图逻辑更适合规则直返。

---

## 13. 当前已知风险

1. FastGPT 虽能回答，但仍可能过于泛化或补充未证实细节。
2. 图片请求在 `demo-server` 中仍可能回退到本地 `vision_rag`，说明 FastGPT-first 图片成功路径还可以继续收紧。
3. 当前样板图 / 实拍图 URL 使用的是局域网地址 `http://192.168.77.97:9100/...`。
4. 这意味着：
   - 本机 / 局域网演示可用
   - 外网用户当前不可直接访问这些图片

---

## 14. 如果未来要打通外网，需要什么

当前不是必须，但如果要外网可用，至少需要：

1. 公网域名或公网 IP
2. HTTPS 证书
3. 反向代理
4. 把图片地址从局域网地址换成公网可访问地址
5. 检查跨域、上传大小、访问控制

最推荐的方式不是直接把 `9100` 裸露到外网，而是：

- 站点走统一域名
- 图片也挂在同域名路径下
- 由代理去转发到 MinIO

---

## 15. 当前最应该继续做什么

如果新对话是继续推进工程，优先考虑：

1. 继续压缩 FastGPT 的无依据推断
2. 继续把图片请求优先链路收紧为更稳定的 FastGPT-first
3. 如果要外网演示，优先改图片访问域名
4. 如果要扩展样板图，继续往 `data/image_catalog/board_images.json` 追加，并保持直返逻辑

---

## 16. 新对话推荐开场提示

可以直接用下面这段作为新对话启动语：

```text
先读 AGENT.md、PROJECT_INDEX.md、CURRENT_STATE.md、DECISIONS.md、NEXT_ACTION.md。
如果要继续当前工程细节，再读 task_plan.md、findings.md、progress.md。
本项目是广西亿库本地 FastGPT AI 客服，当前已支持文本问答、图片咨询、四种板材样板图/实拍图直返。
继续工作时优先关注 FastGPT RAG 稳定性、图片链路稳定性、以及局域网图片 URL 的外网替换问题。
```
