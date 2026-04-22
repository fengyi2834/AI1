# 广西亿库 AI 客服项目

这是一个面向广西亿库光养硅藻环保科技有限公司的 FastGPT + 智谱 AI 客服最小实现仓库。

当前目标不是一次做成完整生产系统，而是先把下面这条链路跑通：

1. 从 `xlsx/docx` 原始资料整理知识文本
2. 生成可导入 FastGPT 的中间产物
3. 本地通过 Docker 跑起 FastGPT 开发环境
4. 接入智谱模型
5. 提供一个官网客服接入 Demo
6. 提供基础校验脚本，方便反复调试

## 当前联调提醒

<div style="border:2px solid #d92d20;padding:12px 14px;border-radius:10px;background:#fff1f0;color:#a61b1b;">
  <strong>当前默认按“模拟数据联调”处理。</strong><br/>
  你可以先使用 <code>data/raw_docs</code> 里的 smoke / smoke2 示例资料跑通流程。<br/>
  但只要你准备接真实智谱模型，就必须去改 <code>infra/fastgpt/.env.local</code> 里的
  <code>CHAT_API_KEY</code>。如果它还是
  <code>__REPLACE_WITH_REAL_ZHIPU_API_KEY_BEFORE_REAL_RUN__</code>，
  就说明真实模型还没有接上。
</div>

## 目录约定

- `infra/fastgpt/`
  FastGPT 本地部署脚手架
- `scripts/`
  启停和辅助脚本
- `tools/knowledge_ingest/`
  原始资料整理工具
- `tools/validate/`
  校验与测试辅助工具
- `config/fastgpt/`
  模型、提示词、知识库、工作流模板
- `web-demo/`
  官网接入 Demo

## 推荐开发顺序

1. 准备原始资料到本地目录
2. 运行资料整理工具
3. 启动本地 FastGPT
4. 填写智谱相关配置
5. 导入知识资料
6. 打开官网 Demo 联调
7. 运行基础校验脚本

## 当前状态

- 项目文档已初步完成
- 代码脚手架正在搭建中
- 当前目录尚未初始化为 Git 仓库
## Current Verified Commands

### Start FastGPT local stack

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-local.ps1
```

Main entry:

- FastGPT: `http://127.0.0.1:3100`
- MinIO Console: `http://127.0.0.1:9101`

### Start demo server

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-demo.ps1 -Port 8099
```

Demo entry:

- Demo: `http://127.0.0.1:8099`

### Rebuild Python venv after copy or move

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\rebuild-venv.ps1
```

What it does:

- Rebuilds `.venv`
- Upgrades `pip`
- Installs `tools\knowledge_ingest\requirements.txt`
- Verifies `openpyxl` and `python-docx`

### Run validation scripts

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\validate\run_all.ps1
```

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\validate\check_config.ps1 -ConfigPath .\infra\fastgpt\.env.local -RequiredKeys OPENAI_BASE_URL,CHAT_API_KEY,FASTGPT_PORT,MINIO_PORT
```
