#!/bin/bash
# AI1 数据备份脚本 — 每日凌晨 3 点 cron 执行
# 备份：MongoDB + PostgreSQL + 聊天数据 + 配置
# 保留最近 7 天

set -e
BACKUP_ROOT="/opt/AI1/backups"
DATE=$(date +%Y%m%d)
DEST="$BACKUP_ROOT/$DATE"
LOG="$BACKUP_ROOT/backup.log"
RETENTION_DAYS=7

mkdir -p "$DEST"

echo "=== $(date) 开始备份 ===" >> "$LOG"

# 1. MongoDB（FastGPT 知识库、用户数据）
echo "[1/5] MongoDB dump..." >> "$LOG"
docker exec ai1-fastgpt-mongo mongodump \
  -u ai1_mongo_user -p mg_d67dda3bc67c49db811be3b72c335b8e \
  --authenticationDatabase admin --db fastgpt \
  --out /tmp/mongodump 2>> "$LOG"
docker cp ai1-fastgpt-mongo:/tmp/mongodump "$DEST/mongo" 2>> "$LOG"
docker exec ai1-fastgpt-mongo rm -rf /tmp/mongodump 2>/dev/null
echo "[1/5] OK" >> "$LOG"

# 2. PostgreSQL（向量数据、工作流）
echo "[2/5] PostgreSQL dump..." >> "$LOG"
docker exec ai1-fastgpt-pg pg_dump \
  -U ai1_pg_user postgres > "$DEST/fastgpt_pg.sql" 2>> "$LOG"
echo "[2/5] OK" >> "$LOG"

# 3. 聊天数据（聊天记忆、意向记录）
echo "[3/5] 聊天数据..." >> "$LOG"
if [ -d /opt/AI1/data ]; then
  cp -r /opt/AI1/data "$DEST/data" 2>> "$LOG"
  echo "[3/5] OK" >> "$LOG"
else
  echo "[3/5] SKIP (no data dir)" >> "$LOG"
fi

# 4. MinIO 文件存储
echo "[4/5] MinIO..." >> "$LOG"
if [ -d /opt/AI1/infra/fastgpt/runtime_server/minio ]; then
  cp -r /opt/AI1/infra/fastgpt/runtime_server/minio "$DEST/minio" 2>> "$LOG"
  echo "[4/5] OK" >> "$LOG"
else
  echo "[4/5] SKIP" >> "$LOG"
fi

# 5. 关键配置文件
echo "[5/5] 配置文件..." >> "$LOG"
mkdir -p "$DEST/config"
cp /opt/AI1/deploy/env/*.env "$DEST/config/" 2>/dev/null
cp /opt/AI1/infra/fastgpt/.env.local "$DEST/config/" 2>/dev/null
cp /opt/AI1/infra/fastgpt/docker-compose.local.yml "$DEST/config/" 2>/dev/null
echo "[5/5] OK" >> "$LOG"

# 打包
cd "$BACKUP_ROOT"
tar -czf "$DATE.tar.gz" "$DATE" 2>> "$LOG"
rm -rf "$DATE"
echo "备份包: $BACKUP_ROOT/$DATE.tar.gz ($(du -h "$DATE.tar.gz" | cut -f1))" >> "$LOG"

# 清理 7 天前的备份
find "$BACKUP_ROOT" -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete 2>> "$LOG"

echo "=== $(date) 备份完成 ===" >> "$LOG"
echo "" >> "$LOG"
