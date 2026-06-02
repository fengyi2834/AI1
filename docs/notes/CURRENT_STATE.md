# Current State — 广西亿库硅藻板 AI 客服

## 服务器

- **IP**: 43.99.63.64 (阿里云)
- **域名**: guangxiyiku.com
- **OS**: Ubuntu 22.04 / 宝塔面板

## 架构

```
用户浏览器 → Nginx (:80/:443) → guanwang 官网
                                  ├─ /api/ai/chat → Demo Server (pwsh :4180)
                                  ├─ /chat.html → 手机独立聊天页
                                  └─ /api/auth/* → 认证接口

Demo Server 路由:
  ├─ FastGPT (RAG 知识库) → DeepSeek
  ├─ 直连回退 → DeepSeek API
  └─ 图片识别 → 智谱 GLM-4.6V-FlashX

邮件 → Python 微服务 (:12580) → 163 SMTP
备份 → cron 每日 03:00 → /opt/AI1/backups/
```

## FastGPT (Docker)

| 服务 | 镜像 | 状态 |
|------|------|------|
| fastgpt-app | v4.14.22 | 运行中 |
| fastgpt-plugin | v0.6.2 | healthy |
| fastgpt-code-sandbox | v4.14.22 | healthy |
| opensandbox-server | v0.1.9 | healthy |
| mongo | 5.0.32 (replica set) | healthy |
| pg | pgvector 0.8.0-pg15 | healthy |
| minio | RELEASE.2025-09-07 | healthy |
| redis | 7.2 | healthy |

服务器 App ID: `6a1545d47e465598db06e660` ("广西亿库 AI 客服")
服务器 Dataset ID: `6a1647eb5d22da047b8de666`
API Key: `ak_7bb9991e8a04d892f6f56d8182c7677c783610222bfeabe0`

## Demo Server (pwsh)

- **端口**: 127.0.0.1:4180
- **进程**: pwsh (start-guanwang-server-ai1.ps1)
- **模型**: 文字→DeepSeek, 图片→智谱 glm-4.6v-flashx
- **知识库**: 91 条 FAQ + RAG 检索
- **认证**: register / verify / login / me / forgot / reset-password
- **限流**: 设备指纹, 5次/24h, 登录后不限
- **匿名**: 聊天不存盘, 刷新即清; 登录后持久化

## 邮件服务

- Python 微服务 (127.0.0.1:12580), systemd 管理
- 163 邮箱 SMTP: xiaofeng24761@163.com
- systemd: ai1-email-sender.service

## 已完成的近期工作

- [x] FastGPT 全家桶升级到 v4.14.22
- [x] 插件 S3 初始化卡死修复
- [x] MongoDB replica set 确认
- [x] opensandbox / code-sandbox healthcheck 修复
- [x] phpMyAdmin 888 端口限制
- [x] 邮件发送（注册验证码 + 找回密码）
- [x] 设备限流 + 邮箱注册登录
- [x] 手机独立聊天页 /chat.html
- [x] 图片上传 + 智谱直出识别
- [x] 数据备份（每日 cron）
