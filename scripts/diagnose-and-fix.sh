#!/bin/bash

# IPv6代理服务器诊断和修复脚本

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_message $BLUE "=== IPv6代理服务器诊断工具 ==="
echo ""

# 1. 检查系统IP地址
print_message $YELLOW "1. 检查系统IP地址："
echo "所有网卡IP地址："
ip addr show | grep -E "inet\s" | grep -v "127.0.0.1"
echo ""

# 2. 检查服务状态
print_message $YELLOW "2. 检查服务状态："
systemctl status ipv6proxy --no-pager -l
echo ""

# 3. 检查端口监听
print_message $YELLOW "3. 检查端口监听情况："
netstat -tlnp | grep -E ':(100|101)' || echo "没有发现监听的代理端口"
echo ""

# 4. 检查服务日志
print_message $YELLOW "4. 最近的服务日志："
journalctl -u ipv6proxy -n 20 --no-pager
echo ""

# 5. 检查IPv6隧道
print_message $YELLOW "5. 检查IPv6隧道状态："
ip -6 addr show he-ipv6 2>/dev/null || echo "IPv6隧道未找到"
echo ""

# 6. 检查IPv6路由
print_message $YELLOW "6. 检查IPv6路由："
ip -6 route show | grep -E "(local|2001:470)" || echo "没有找到相关IPv6路由"
echo ""

# 7. 读取配置并验证IP
print_message $YELLOW "7. 验证配置的IP地址："
if [ -f "/etc/systemd/system/ipv6proxy.service" ]; then
    echo "服务配置："
    grep "ExecStart" /etc/systemd/system/ipv6proxy.service
    echo ""
    
    # 提取配置的IP地址
    MULTI_IPS=$(grep "ExecStart" /etc/systemd/system/ipv6proxy.service | grep -o "multi-ipv4[^\"]*" | cut -d'"' -f2)
    if [ -n "$MULTI_IPS" ]; then
        echo "配置的多IP地址："
        echo "$MULTI_IPS" | tr ',' '\n' | while read ip_port; do
            ip=$(echo "$ip_port" | cut -d':' -f1)
            port=$(echo "$ip_port" | cut -d':' -f2)
            echo -n "  $ip:$port - "
            
            # 检查IP是否存在
            if ip addr show | grep -q "$ip"; then
                print_message $GREEN "✓ IP存在"
            else
                print_message $RED "✗ IP不存在"
            fi
        done
    fi
else
    print_message $RED "服务配置文件未找到"
fi
echo ""

# 8. 提供修复建议
print_message $BLUE "=== 修复建议 ==="

# 检查不存在的IP
MISSING_IPS=()
if [ -n "$MULTI_IPS" ]; then
    echo "$MULTI_IPS" | tr ',' '\n' | while read ip_port; do
        ip=$(echo "$ip_port" | cut -d':' -f1)
        if ! ip addr show | grep -q "$ip"; then
            echo "发现不存在的IP: $ip"
        fi
    done
fi

echo ""
print_message $YELLOW "如果发现IP地址不存在，请选择以下修复方案："
echo ""
echo "方案1: 重新配置服务（推荐）"
echo "  sudo systemctl stop ipv6proxy"
echo "  sudo ./install.sh  # 重新运行安装脚本"
echo ""
echo "方案2: 手动添加IP地址（如果您有多个IP）"
echo "  # 添加IP到网卡（示例）"
echo "  sudo ip addr add 141.11.138.121/24 dev eth0"
echo "  sudo systemctl restart ipv6proxy"
echo ""
echo "方案3: 修改服务配置使用现有IP"
echo "  sudo systemctl stop ipv6proxy"
echo "  sudo nano /etc/systemd/system/ipv6proxy.service"
echo "  # 修改multi-ipv4参数，只保留存在的IP"
echo "  sudo systemctl daemon-reload"
echo "  sudo systemctl start ipv6proxy"
echo ""

# 9. 测试连接
print_message $YELLOW "9. 测试代理连接："
echo "IPv4代理测试："

# 获取实际存在的IP
EXISTING_IPS=($(ip addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1'))

for ip in "${EXISTING_IPS[@]}"; do
    echo -n "测试 $ip:101 - "
    if timeout 5 curl -s --proxy "http://$ip:101" "http://icanhazip.com" >/dev/null 2>&1; then
        print_message $GREEN "✓ 工作正常"
    else
        print_message $RED "✗ 连接失败"
    fi
done

echo ""
echo "IPv6代理测试："
if [ ${#EXISTING_IPS[@]} -gt 0 ]; then
    test_ip="${EXISTING_IPS[0]}"
    echo -n "测试 $test_ip:100 - "
    if timeout 10 curl -s --proxy "http://$test_ip:100" "http://ipv6.icanhazip.com" >/dev/null 2>&1; then
        print_message $GREEN "✓ IPv6代理工作正常"
    else
        print_message $RED "✗ IPv6代理连接失败"
        echo ""
        print_message $YELLOW "IPv6修复命令："
        if [ -f "/etc/he-ipv6/he-ipv6.conf" ]; then
            source /etc/he-ipv6/he-ipv6.conf
            echo "  sudo ip -6 route add local ${ROUTED_PREFIX}/${PREFIX_LENGTH} dev lo"
            echo "  sudo systemctl restart ipv6proxy"
        fi
    fi
fi

echo ""
print_message $BLUE "=== 诊断完成 ==="
