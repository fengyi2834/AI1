# FastGPT 本地部署脚手架

这一套文件用于本地先跑通 `FastGPT + 智谱`，再迁移到云服务器。

## 文件说明

- `docker-compose.local.yml`
  本地开发用 Compose 脚手架，参考 FastGPT 官方 Docker Compose 部署文档整理
- `.env.example`
  本地环境变量模板
- `config.json`
  FastGPT 本地配置文件模板

## 快速启动

<div style="border:2px solid #d92d20;padding:12px 14px;border-radius:10px;background:#fff1f0;color:#a61b1b;margin:12px 0;">
  <strong>红色提醒：</strong> 当前仓库可以先用 <code>data/raw_docs</code> 里的模拟 <code>xlsx/docx</code> 做联调，
  但真正接智谱模型前，必须打开 <code>infra/fastgpt/.env.local</code>，
  把 <code>CHAT_API_KEY=__REPLACE_WITH_REAL_ZHIPU_API_KEY_BEFORE_REAL_RUN__</code>
  改成你的真实 API Key。
</div>

1. 复制环境变量模板

```powershell
Copy-Item .\infra\fastgpt\.env.example .\infra\fastgpt\.env.local
```

2. 编辑 `.\infra\fastgpt\.env.local`

至少填这两个值：

- `OPENAI_BASE_URL`
- `CHAT_API_KEY`

如果你只是先跑模拟数据：

- `OPENAI_BASE_URL` 可以先保留当前智谱兼容地址
- `CHAT_API_KEY` 可以暂时保留占位值，但这时不要把页面当成“真实模型已接通”
- 一旦开始真联调，第一件事就是替换 `CHAT_API_KEY`

3. 启动服务

```powershell
.\scripts\start-local.ps1
```

4. 访问服务

- FastGPT: `http://localhost:3000`
- MinIO Console: `http://localhost:9001`
- MCP Server: `http://localhost:3005`

按当前仓库里的本地配置启动时，实际常用端口通常是：

- FastGPT: `http://localhost:3100`
- MinIO Console: `http://localhost:9101`
- MCP Server: `http://localhost:3105`

默认 root 账号：

- 用户名：`root`
- 密码：`.env.local` 中的 `DEFAULT_ROOT_PSW`

## 停止服务

```powershell
.\scripts\stop-local.ps1
```

## 重要提醒

- `STORAGE_EXTERNAL_ENDPOINT` 不能写成 `127.0.0.1` 或 `localhost`
- Windows 本地开发优先使用 `host.docker.internal`
- 如果 CPU 不支持 AVX，可把 Mongo 镜像切到 `4.4.29`
- 修改 `config.json` 后，需执行 `docker compose down` 再重新启动

## 参考

- FastGPT 官方 Docker Compose 部署文档：
  https://doc.fastgpt.cn/zh-CN/docs/self-host/deploy/docker
- FastGPT 官方配置文件说明：
  https://doc.fastgpt.cn/docs/introduction/development/configuration
