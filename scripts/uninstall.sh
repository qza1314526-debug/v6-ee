#!/bin/bash

# IPv6代理服务器卸载脚本

echo "开始卸载IPv6代理服务器..."

# 停止并禁用服务
systemctl stop ipv6proxy 2>/dev/null || true
systemctl disable ipv6proxy 2>/dev/null || true

# 删除服务文件
rm -f /etc/systemd/system/ipv6proxy.service

# 删除系统配置
rm -f /etc/sysctl.d/99-ipv6proxy.conf
rm -f /etc/logrotate.d/ipv6proxy

# 删除安装目录
rm -rf /opt/ipv6proxy

# 删除日志目录
rm -rf /var/log/ipv6proxy

# 删除命令链接
rm -f /usr/local/bin/ipv6proxy

# 删除HE隧道配置
rm -rf /etc/he-ipv6

# 重载systemd配置
systemctl daemon-reload

echo "卸载完成"
echo "注意: Go语言环境和系统依赖包未被删除"
