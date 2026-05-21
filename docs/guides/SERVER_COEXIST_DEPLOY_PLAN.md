# 当前服务器共存部署方案

当前服务器已确认正在运行：

- `mvp-nginx-server666666`
- `mvp-cs-lab-server666666`

其中：

- `mvp-nginx-server666666` 占用了 `80`
- `mvp-cs-lab-server666666` 是 Flask 服务，内部跑在 `8787`

所以本项目按“共存模式”部署。

## 1. 不冲突的目标结构

保留老系统：

- `kefuceshi.5593102.top -> mvp nginx -> app:8787`

新增新系统：

- `kefuceshi2.5593102.top -> mvp nginx -> 172.18.0.1:4180`

AI1 FastGPT 新起一套，端口连续安排：

- 官网：`4180`
- FastGPT：`4181`
- MCP：`4182`
- MinIO API：`4183`
- MinIO Console：`4184`

## 2. 这次要用的文件

### FastGPT 环境模板

- `deploy/env/fastgpt.server.ai1.env.example`

### FastGPT 可直接填写版本

- `deploy/env/fastgpt.server.ai1.env`

### 官网环境模板

- `deploy/env/guanwang.server.env.example`

### 官网可直接填写版本

- `deploy/env/guanwang.server.env`

### Nginx 双域名模板

- `deploy/nginx/mvp-dual-domain.default.conf.template`

### 独立容器名 override

- `infra/fastgpt/docker-compose.server.ai1.override.yml`

### 便捷启动脚本

- `scripts/start-fastgpt-server-ai1.ps1`
- `scripts/start-guanwang-server-ai1.ps1`

## 3. 为什么要用 override

仓库默认 FastGPT 容器名是：

- `fastgpt-app`
- `fastgpt-mongo`
- `fastgpt-pg`

为了以后同机再加别的服务不撞名，这次统一改成：

- `ai1-fastgpt-app`
- `ai1-fastgpt-mongo`
- `ai1-fastgpt-pg`

## 4. 现在你只需要填什么

### FastGPT 这套

编辑：

- `deploy/env/fastgpt.server.ai1.env`

只需要改：

- `CHAT_API_KEY`

其它端口、容器名、本地密码和内部密钥我已经先帮你填好。

### 官网这套

编辑：

- `deploy/env/guanwang.server.env`

只需要改：

- `FASTGPT_APP_API_KEY`
- `CHAT_API_KEY`

说明：

- `CHAT_API_KEY`
  - 是模型平台 key，比如智谱
- `FASTGPT_APP_API_KEY`
  - 是你在 FastGPT 后台创建应用后生成的应用 OpenAPI key

## 5. 建议启动顺序

### 5.1 启动 AI1 FastGPT

```powershell
pwsh -File .\scripts\start-fastgpt-server-ai1.ps1
```

### 5.2 启动官网服务

```powershell
pwsh -File .\scripts\start-guanwang-server-ai1.ps1
```

### 5.3 替换 mvp nginx 模板

把：

- `deploy/nginx/mvp-dual-domain.default.conf.template`

覆盖到服务器：

- `/opt/mvp666666/ops/nginx/default.conf.template`

然后重建现有 nginx 容器。

## 6. 还剩一个无法提前替你填死的值

只有：

- `FASTGPT_APP_API_KEY`

这个值必须等你把 FastGPT 启起来，在后台创建或确认应用后才能拿到。

## 7. 风险提示

- 这次最大的共享点是 `80` 端口入口，不是 FastGPT 容器
- 新站通过 `172.18.0.1:4180` 从 nginx 容器回到宿主机
- 如果宿主机桥接访问受限，需要额外放行本机 Docker bridge 访问
