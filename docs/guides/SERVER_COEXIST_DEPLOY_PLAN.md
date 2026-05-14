# 当前服务器共存部署方案

当前服务器已确认正在运行：

- `mvp-nginx-server666666`
- `mvp-cs-lab-server666666`

其中：

- `mvp-nginx-server666666` 占用了 `80`
- `mvp-cs-lab-server666666` 是 Flask 服务，内部跑在 `8787`

所以本项目需要按“共存模式”部署。

## 1. 不冲突的目标结构

保留现有老系统：

- `kefuceshi.5593102.top -> mvp nginx -> app:8787`

新增新系统：

- `kefuceshi2.5593102.top -> mvp nginx -> 172.18.0.1:4180`

AI1 FastGPT 新起一套：

- FastGPT 主服务：`3100`
- MinIO：`9100`
- MCP：`3105`

## 2. 这次要用的文件

### FastGPT 新环境模板

- `deploy/env/fastgpt.server.ai1.env.example`

### 官网新环境模板

- `deploy/env/guanwang.server.env.example`

### Nginx 双域名模板

- `deploy/nginx/mvp-dual-domain.default.conf.template`

### 独立容器名 override

- `infra/fastgpt/docker-compose.server.ai1.override.yml`

## 3. 为什么要用 override

当前仓库默认 FastGPT 容器名是：

- `fastgpt-app`
- `fastgpt-mongo`
- `fastgpt-pg`

这次虽然和现有 Flask 老系统不冲突，但为了后面机器上再加别的服务不撞名，建议用 override 改成：

- `ai1-fastgpt-app`
- `ai1-fastgpt-mongo`
- `ai1-fastgpt-pg`

## 4. 你只需要填的关键值

### FastGPT 这套

在 `deploy/env/fastgpt.server.ai1.env` 里填：

- `CHAT_API_KEY`
- `DEFAULT_ROOT_PSW`
- `ROOT_KEY`
- `TOKEN_KEY`
- `FILE_TOKEN_KEY`
- `AES256_SECRET_KEY`
- `PLUGIN_TOKEN`
- `CODE_SANDBOX_TOKEN`
- `VOLUME_MANAGER_TOKEN`
- `AIPROXY_API_TOKEN`
- `PG_PASSWORD`
- `MONGO_PASSWORD`
- `REDIS_PASSWORD`
- `MINIO_ROOT_USER`
- `MINIO_ROOT_PASSWORD`

### 官网这套

在 `deploy/env/guanwang.server.env` 里填：

- `FASTGPT_APP_API_KEY`
- `CHAT_API_KEY`
- `MINIO_ROOT_USER`
- `MINIO_ROOT_PASSWORD`

## 5. 建议启动顺序

### 5.1 启动 AI1 FastGPT

```bash
docker compose \
  --env-file deploy/env/fastgpt.server.ai1.env \
  -f infra/fastgpt/docker-compose.local.yml \
  -f infra/fastgpt/docker-compose.server.ai1.override.yml \
  up -d
```

### 5.2 启动官网服务

```bash
pwsh -File ./scripts/start-guanwang.ps1 -Port 4180 -EnvFile ./deploy/env/guanwang.server.env
```

### 5.3 替换 mvp nginx 模板

把：

- `deploy/nginx/mvp-dual-domain.default.conf.template`

覆盖到服务器：

- `/opt/mvp666666/ops/nginx/default.conf.template`

然后重建现有 nginx 容器。

## 6. 风险提示

- 这次最大的共享点是 `80` 端口入口，不是 FastGPT 容器
- 新站通过 `172.18.0.1:4180` 从 nginx 容器回到宿主机
- 如果宿主机防火墙限制了该访问，需要额外放行本机桥接访问
