#!/bin/bash

# IPv6代理服务器备份脚本

BACKUP_DIR="/opt/backups/ipv6proxy"
INSTALL_DIR="/opt/ipv6proxy"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="ipv6proxy_backup_$DATE.tar.gz"

# 创建备份目录
mkdir -p "$BACKUP_DIR"

echo "开始备份IPv6代理服务器配置..."

# 停止服务
systemctl stop ipv6proxy

# 创建备份
tar -czf "$BACKUP_DIR/$BACKUP_FILE" \
    -C / \
    opt/ipv6proxy \
    etc/systemd/system/ipv6proxy.service \
    etc/sysctl.d/99-ipv6proxy.conf \
    etc/logrotate.d/ipv6proxy \
    etc/he-ipv6 2>/dev/null || true

# 启动服务
systemctl start ipv6proxy

echo "备份完成: $BACKUP_DIR/$BACKUP_FILE"

# 清理旧备份（保留最近7天）
find "$BACKUP_DIR" -name "ipv6proxy_backup_*.tar.gz" -mtime +7 -delete

echo "备份脚本执行完成"
