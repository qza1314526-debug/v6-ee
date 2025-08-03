#!/bin/bash

# IPv6代理服务器恢复脚本

if [ $# -ne 1 ]; then
    echo "使用方法: $0 <备份文件路径>"
    exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "错误: 备份文件不存在: $BACKUP_FILE"
    exit 1
fi

echo "开始恢复IPv6代理服务器配置..."

# 停止服务
systemctl stop ipv6proxy 2>/dev/null || true

# 恢复文件
tar -xzf "$BACKUP_FILE" -C /

# 重载systemd配置
systemctl daemon-reload

# 应用系统配置
sysctl -p /etc/sysctl.d/99-ipv6proxy.conf

# 启动服务
systemctl start ipv6proxy
systemctl enable ipv6proxy

echo "恢复完成"
echo "服务状态:"
systemctl status ipv6proxy
