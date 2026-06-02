# Next Action

## 待办

| 优先级 | 任务 | 说明 |
|--------|------|------|
| P1 | 宝塔面板 8888 加固 | 改端口或加 IP 白名单 |
| P1 | API 密钥管理 | .env 明文密钥迁移 |
| P2 | 网站监控告警 | 服务异常时能通知 |
| P2 | 数据备份 | cron 已配，每天 03:00 |
| — | Windows TLS 兼容 | 之前临时关 http2，需彻底修 |

## 常用命令

```bash
# 重启 Demo Server
fuser -k 4180/tcp
cd /opt/AI1 && nohup pwsh -File ./scripts/start-guanwang-server-ai1.ps1 -Port 4180 > /var/log/ai1-guanwang.log 2>&1 &

# 重启 FastGPT
cd /opt/AI1/infra/fastgpt
docker compose -f docker-compose.local.yml -f docker-compose.server.ai1.override.yml --env-file ../../deploy/env/fastgpt.server.ai1.env up -d

# 查看日志
tail -f /var/log/ai1-guanwang.log
docker logs -f ai1-fastgpt-app

# 手动备份
bash /opt/AI1/scripts/backup.sh
```

## 关键文件

- `scripts/demo-server.ps1` — 主聊天服务（路由、认证、AI 调用）
- `scripts/email-sender.py` — 邮件微服务
- `scripts/backup.sh` — 数据备份
- `deploy/env/guanwang.server.env` — Demo Server 环境变量
- `deploy/env/fastgpt.server.ai1.env` — FastGPT 环境变量
- `infra/fastgpt/docker-compose.local.yml` — FastGPT 容器编排
