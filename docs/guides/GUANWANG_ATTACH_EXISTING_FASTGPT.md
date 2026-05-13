# 官网接入现有 FastGPT

如果服务器上已经有一套正常运行的 FastGPT，最稳的方式不是再起第二套，而是：

`官网 + demo-server -> 直接接现有 FastGPT`

这样可以避免下面两类冲突：

## 1. 为什么会冲突

当前仓库里的 `infra/fastgpt/docker-compose.local.yml` 写死了很多固定容器名：

- `fastgpt-app`
- `fastgpt-mongo`
- `fastgpt-pg`
- `fastgpt-redis`
- `fastgpt-minio`

如果服务器上已经有另一套 FastGPT 也用这些名字，那么再次启动当前这套 Compose 时，大概率会出现：

- 容器名冲突
- 端口冲突
- 误连到别人的 Mongo / MinIO

所以：

- **不要在同一台服务器上直接再起一套默认 FastGPT**
- **先复用现有 FastGPT**

## 2. 这次推荐方案

只部署这两层：

1. 官网静态页 `guanwang/`
2. `scripts/demo-server.ps1`

`demo-server` 再通过环境文件去调用你现有的 FastGPT 应用接口。

## 3. 你只需要准备什么

复制：

- `deploy/env/guanwang.server.env.example`

到：

- `deploy/env/guanwang.server.env`

然后至少填写这几个值：

- `FASTGPT_APP_API_URL`
- `FASTGPT_APP_API_KEY`
- `CHAT_API_KEY`

如果图片上传也要正常使用，再补：

- `STORAGE_EXTERNAL_ENDPOINT`
- `MINIO_ROOT_USER`
- `MINIO_ROOT_PASSWORD`

## 4. 启动命令

```powershell
pwsh -File .\scripts\start-guanwang.ps1 -Port 4180 -EnvFile .\deploy\env\guanwang.server.env
```

## 5. 什么时候才需要第二套 FastGPT

只有在下面情况才建议单独起第二套：

- 你要把官网客服和现有系统完全隔离
- 你拿到了新的独立端口规划
- 你准备单独改容器名、端口、卷目录

否则这次先复用现有 FastGPT 是最省事也最稳的方案。
