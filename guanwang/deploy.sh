#!/usr/bin/env bash
# ============================================
# 亿库官网 + AI客服 全套部署脚本
# 用法：bash deploy.sh
# 前提：
#   1. SSH 公钥已添加到服务器（ssh-copy-id root@43.99.63.64）
#   2. 域名 guangxiyiku.com DNS 已指向 43.99.63.64
#   3. 服务器上已安装宝塔面板（Nginx）
# ============================================
set -e

SERVER="43.99.63.64"
SERVER_USER="root"
PROJECT_DIR="/opt/AI1"
SITE_DIR="/www/wwwroot/guangxiyiku.com"
LOCAL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "============================================"
echo "  亿库 AI 客服系统部署"
echo "  目标服务器: ${SERVER}"
echo "============================================"

# ── 步骤 1: 上传 AI1 项目到服务器 ──
echo ""
echo "=== 步骤 1/6: 上传项目代码 ==="
ssh "${SERVER_USER}@${SERVER}" "mkdir -p ${PROJECT_DIR}"

EXCLUDE_FILE="$(mktemp)"
cat > "$EXCLUDE_FILE" <<'IGNORE'
.git
node_modules
.venv
tmp
*.pptx
*.pdf
assets/raw
__pycache__
*.pyc
.DS_Store
IGNORE

rsync -avz --delete \
    --exclude-from="$EXCLUDE_FILE" \
    "${LOCAL_ROOT}/" \
    "${SERVER_USER}@${SERVER}:${PROJECT_DIR}/"

rm -f "$EXCLUDE_FILE"
echo "项目代码已上传到 ${PROJECT_DIR}"

# ── 步骤 2: 上传静态官网到宝塔目录 ──
echo ""
echo "=== 步骤 2/6: 部署静态官网 ==="
EXCLUDE_WEB="$(mktemp)"
cat > "$EXCLUDE_WEB" <<'IGNORE'
*.md
*.pptx
*.pdf
deploy.sh
nginx.conf
assets/raw
.git
node_modules
IGNORE

rsync -avz --delete \
    --exclude-from="$EXCLUDE_WEB" \
    "${LOCAL_ROOT}/guanwang/" \
    "${SERVER_USER}@${SERVER}:${SITE_DIR}/"

rm -f "$EXCLUDE_WEB"
echo "静态文件已上传到 ${SITE_DIR}"

# ── 步骤 3: 安装依赖（Docker + pwsh） ──
echo ""
echo "=== 步骤 3/6: 检查系统依赖 ==="
ssh "${SERVER_USER}@${SERVER}" 'bash -s' <<'DEPS'
set -e

# Docker
if ! command -v docker &>/dev/null; then
    echo "安装 Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
else
    echo "Docker ✓"
fi

# Docker Compose plugin
if ! docker compose version &>/dev/null; then
    echo "安装 Docker Compose..."
    apt-get update -qq && apt-get install -y -qq docker-compose-plugin
fi
echo "Docker Compose ✓"

# PowerShell (pwsh) for demo server
if ! command -v pwsh &>/dev/null; then
    echo "安装 PowerShell..."
    apt-get update -qq && apt-get install -y -qq wget apt-transport-https software-properties-common
    source /etc/os-release
    wget -q https://packages.microsoft.com/config/ubuntu/${VERSION_ID}/packages-microsoft-prod.deb -O /tmp/packages-microsoft-prod.deb
    dpkg -i /tmp/packages-microsoft-prod.deb
    apt-get update -qq && apt-get install -y -qq powershell
    rm -f /tmp/packages-microsoft-prod.deb
fi
echo "PowerShell ✓"
DEPS

# ── 步骤 4: 启动 FastGPT Docker 栈 ──
echo ""
echo "=== 步骤 4/6: 启动 FastGPT 服务 ==="
ssh "${SERVER_USER}@${SERVER}" 'bash -s' <<'FASTGPT'
set -e
cd /opt/AI1/infra/fastgpt

# 创建 runtime 目录
mkdir -p runtime_server/{pg,mongo,redis,minio,aiproxy_pg}

# 启动 FastGPT 全家桶
docker compose -f docker-compose.local.yml -f docker-compose.server.ai1.override.yml \
    --env-file ../../deploy/env/fastgpt.server.ai1.env \
    up -d

echo "等待 FastGPT 启动..."
sleep 10
docker compose -f docker-compose.local.yml -f docker-compose.server.ai1.override.yml ps
FASTGPT

# ── 步骤 5: 配置 Nginx ──
echo ""
echo "=== 步骤 5/6: 更新 Nginx 配置 ==="
ssh "${SERVER_USER}@${SERVER}" "cp ${SITE_DIR}/nginx.conf /www/server/panel/vhost/nginx/guangxiyiku.com.conf && nginx -t && nginx -s reload"
echo "Nginx 配置已更新"

# ── 步骤 6: 启动 Demo Server ──
echo ""
echo "=== 步骤 6/6: 启动 AI 客服服务 ==="
ssh "${SERVER_USER}@${SERVER}" 'bash -s' <<'DEMO'
set -e

# 停止旧进程
pkill -f "demo-server.ps1" 2>/dev/null || true
sleep 1

# 启动 demo server（后台运行）
cd /opt/AI1
nohup pwsh -File ./scripts/start-guanwang-server-ai1.ps1 -Port 4180 \
    > /var/log/ai1-guanwang.log 2>&1 &

sleep 3

# 检查是否启动成功
if pgrep -f "demo-server.ps1" > /dev/null; then
    echo "AI 客服服务已启动 (端口 4180)"
else
    echo "WARNING: AI 客服服务可能未成功启动，查看日志: tail -f /var/log/ai1-guanwang.log"
fi
DEMO

# ── 完成 ──
echo ""
echo "============================================"
echo "  部署完成！"
echo "============================================"
echo ""
echo "访问地址："
echo "  官网:     http://guangxiyiku.com"
echo "  （SSL 申请后） https://guangxiyiku.com"
echo ""
echo "后续步骤："
echo "  1. SSL:  宝塔面板 → SSL → Let's Encrypt → 一键申请"
echo "  2. 然后取消 nginx.conf 里 HTTPS 块的注释，重载 Nginx"
echo "  3. 填 API Key:"
echo "     vi /opt/AI1/deploy/env/guanwang.server.env"
echo "     改 CHAT_API_KEY 和 ZHIPU_API_KEY"
echo "  4. 重启 AI 服务:"
echo "     ssh root@${SERVER} 'pkill -f demo-server; cd /opt/AI1 && nohup pwsh -File ./scripts/start-guanwang-server-ai1.ps1 -Port 4180 > /var/log/ai1-guanwang.log 2>&1 &'"
