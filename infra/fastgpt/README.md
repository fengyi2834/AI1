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

1. 复制环境变量模板

```powershell
Copy-Item .\infra\fastgpt\.env.example .\infra\fastgpt\.env.local
```

2. 编辑 `.\infra\fastgpt\.env.local`

至少填这两个值：

- `OPENAI_BASE_URL`
- `CHAT_API_KEY`

3. 启动服务

```powershell
.\scripts\start-local.ps1
```

4. 访问服务

- FastGPT: `http://localhost:3000`
- MinIO Console: `http://localhost:9001`
- MCP Server: `http://localhost:3005`

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
