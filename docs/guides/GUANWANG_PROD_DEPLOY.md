# 官网快速部署说明

这份说明对应当前项目的“最快上线版本”：

- 域名：`kefuceshi2.5593102.top`
- 服务器：`43.99.50.75`
- 系统：`Ubuntu 22.04`
- 站点入口：`guanwang/`
- 业务入口：`scripts/demo-server.ps1`

## 1. 这次部署的真实结构

当前不是“前端直接调 FastGPT”，而是：

`Nginx -> demo-server(4180) -> FastGPT(3100) -> Mongo / PgVector / Redis / MinIO`

所以你要部署的是两层：

1. FastGPT 容器层
2. 官网+AI 中间层

## 2. 这次已经补过的关键点

- 官网部署基线已经保存在 Git 分支：
  - `codex/deploy-prep-20260513`
- `lead/handoff` 不再只是空返回
  - 现在会落到：
  - `data/logs/lead_requests.jsonl`
  - `data/logs/handoff_requests.jsonl`

## 3. 上线前必须改的配置

服务器上的 `infra/fastgpt/.env.local` 至少改这些：

```env
FASTGPT_PORT=3100
FASTGPT_MCP_PORT=3105
MINIO_PORT=9100
MINIO_CONSOLE_PORT=9101

FE_DOMAIN=http://kefuceshi2.5593102.top:3100
STORAGE_EXTERNAL_ENDPOINT=http://kefuceshi2.5593102.top:9100

OPENAI_BASE_URL=https://open.bigmodel.cn/api/paas/v4/
CHAT_API_KEY=<你的真实模型Key>

CHAT_BACKEND=fastgpt_prefer
FASTGPT_APP_API_URL=http://127.0.0.1:3100/api/v1/chat/completions
FASTGPT_APP_API_KEY=fgtest-001

ALLOWED_ORIGINS=http://kefuceshi2.5593102.top,http://43.99.50.75
```

说明：

- `CHAT_BACKEND=fastgpt_prefer`
  - 正式环境先这样最稳
- `STORAGE_EXTERNAL_ENDPOINT`
  - 这是当前“最快上线”的写法
  - 它要求你把 `9100` 端口放行
  - 后面如果要更规范，再改成独立静态资源域名或反向代理

## 4. 服务器安装步骤

### 4.1 安装基础环境

```bash
sudo apt update
sudo apt install -y git curl nginx
```

### 4.2 安装 Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo systemctl enable docker
sudo systemctl start docker
```

### 4.3 安装 PowerShell

```bash
sudo apt-get update
sudo apt-get install -y wget apt-transport-https software-properties-common
wget -q https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install -y powershell
```

## 5. 拉代码并切到部署分支

```bash
cd /opt
sudo git clone https://github.com/fengyi2834/AI1.git
cd /opt/AI1
sudo git checkout codex/deploy-prep-20260513
```

## 6. 准备环境文件

在服务器上手工创建：

`/opt/AI1/infra/fastgpt/.env.local`

不要把本机的私钥文件直接乱传，建议按上面的配置项重新填。

## 7. 启动 FastGPT

```bash
cd /opt/AI1
sudo pwsh -File ./scripts/start-local.ps1
```

检查：

- `http://43.99.50.75:3100`
- `http://kefuceshi2.5593102.top:3100`

## 8. 启动官网 AI 服务

```bash
cd /opt/AI1
sudo pwsh -File ./scripts/start-guanwang.ps1 -Port 4180
```

先用下面地址本机验证：

- `http://127.0.0.1:4180`

## 9. 配置 Nginx

把下面文件放到：

- `/etc/nginx/sites-available/kefuceshi2.5593102.top.conf`

来源模板：

- `deploy/nginx/kefuceshi2.5593102.top.conf`

启用：

```bash
sudo ln -s /etc/nginx/sites-available/kefuceshi2.5593102.top.conf /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

## 10. 配置 systemd

把下面文件放到：

- `/etc/systemd/system/ai1-guanwang.service`

来源模板：

- `deploy/systemd/ai1-guanwang.service`

启用：

```bash
sudo systemctl daemon-reload
sudo systemctl enable ai1-guanwang
sudo systemctl start ai1-guanwang
sudo systemctl status ai1-guanwang
```

## 11. 服务器安全组 / 防火墙

当前最快上线至少放行：

- `80`：官网
- `22`：SSH
- `3100`：FastGPT 管理和测试
- `9100`：MinIO 公网图片访问

可先不放行：

- `9101`
- `3105`

## 12. 上线后第一轮验证

先验这几个：

1. 官网能打开  
   - `http://kefuceshi2.5593102.top`

2. 聊天能返回  
   - 问一句“新房适合用吗”

3. 留资能写入日志  
   - 检查：
   - `/opt/AI1/data/logs/lead_requests.jsonl`

4. 转人工能写入日志  
   - 检查：
   - `/opt/AI1/data/logs/handoff_requests.jsonl`

5. 图片能显示  
   - 尤其是 AI 返回图片和样板图

## 13. 当前版本仍然建议后续补的点

- 给 `lead/handoff` 增加企业微信、飞书或邮件通知
- 给官网加 HTTPS
- 把 `9100` 从“公网直开”升级成“独立静态资源域名/代理”
- 再做公众号 webhook 接入
