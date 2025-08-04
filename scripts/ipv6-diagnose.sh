#!/bin/bash

# IPv6隧道和代理诊断修复脚本

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_message $PURPLE "=== IPv6隧道和代理诊断工具 ==="
echo ""

# 读取配置文件
CONFIG_FILE="/etc/he-ipv6/he-ipv6.conf"
if [ ! -f "$CONFIG_FILE" ]; then
    print_message $RED "错误: 找不到IPv6隧道配置文件 $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"
print_message $BLUE "读取到的配置："
echo "  HE服务器IPv4: $HE_SERVER_IPV4"
echo "  本机IPv4: $LOCAL_IPV4"
echo "  HE服务器IPv6: $HE_SERVER_IPV6"
echo "  本机IPv6: $LOCAL_IPV6"
echo "  路由前缀: $ROUTED_PREFIX/$PREFIX_LENGTH"
echo ""

# 1. 检查隧道接口状态
print_message $YELLOW "1. 检查隧道接口状态："
if ip link show he-ipv6 &>/dev/null; then
    print_message $GREEN "✓ 隧道接口存在"
    ip -6 addr show he-ipv6
    echo ""
    
    # 检查接口是否UP
    if ip link show he-ipv6 | grep -q "state UP"; then
        print_message $GREEN "✓ 隧道接口已启动"
    else
        print_message $RED "✗ 隧道接口未启动"
        echo "修复命令: sudo ip link set he-ipv6 up"
    fi
else
    print_message $RED "✗ 隧道接口不存在"
    echo "需要重新创建隧道"
fi
echo ""

# 2. 测试到HE服务器的连接
print_message $YELLOW "2. 测试到HE服务器的IPv4连接："
if ping -c 3 -W 3 "$HE_SERVER_IPV4" &>/dev/null; then
    print_message $GREEN "✓ 可以ping通HE服务器IPv4: $HE_SERVER_IPV4"
else
    print_message $RED "✗ 无法ping通HE服务器IPv4: $HE_SERVER_IPV4"
    echo "这可能是网络连接问题"
fi
echo ""

# 3. 测试IPv6隧道连接
print_message $YELLOW "3. 测试IPv6隧道连接："
if ping6 -c 3 -W 3 -I he-ipv6 "$HE_SERVER_IPV6" &>/dev/null; then
    print_message $GREEN "✓ 可以通过隧道ping通HE服务器IPv6: $HE_SERVER_IPV6"
else
    print_message $RED "✗ 无法通过隧道ping通HE服务器IPv6: $HE_SERVER_IPV6"
    echo "隧道连接有问题"
fi
echo ""

# 4. 检查IPv6路由
print_message $YELLOW "4. 检查IPv6路由表："
echo "相关IPv6路由："
ip -6 route show | grep -E "(2001:470|default|local)" || echo "没有找到相关路由"
echo ""

# 5. 检查系统参数
print_message $YELLOW "5. 检查系统参数："
params=(
    "net.ipv6.conf.all.forwarding"
    "net.ipv6.ip_nonlocal_bind"
    "net.ipv6.conf.all.proxy_ndp"
)

for param in "${params[@]}"; do
    value=$(sysctl -n "$param" 2>/dev/null || echo "未设置")
    if [ "$value" = "1" ]; then
        print_message $GREEN "✓ $param = $value"
    else
        print_message $RED "✗ $param = $value (应该为1)"
    fi
done
echo ""

# 6. 测试IPv6代理
print_message $YELLOW "6. 测试IPv6代理功能："
LOCAL_IP=$(ip addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n1)
if [ -n "$LOCAL_IP" ]; then
    echo "使用本地IP $LOCAL_IP 测试IPv6代理..."
    
    # 测试代理是否监听
    if netstat -tln | grep -q ":100 "; then
        print_message $GREEN "✓ IPv6代理端口100正在监听"
        
        # 测试代理连接
        echo -n "测试IPv6代理连接... "
        if timeout 10 curl -s --proxy "http://$LOCAL_IP:100" "http://ipv6.google.com" >/dev/null 2>&1; then
            print_message $GREEN "✓ IPv6代理工作正常"
        else
            print_message $RED "✗ IPv6代理连接失败"
        fi
    else
        print_message $RED "✗ IPv6代理端口100未监听"
    fi
else
    print_message $RED "✗ 找不到本地IP地址"
fi
echo ""

# 7. 检查服务日志中的错误
print_message $YELLOW "7. 检查服务日志中的IPv6相关错误："
journalctl -u ipv6proxy -n 50 --no-pager | grep -i -E "(ipv6|error|failed)" | tail -10
echo ""

# 8. 提供修复方案
print_message $BLUE "=== 修复方案 ==="
echo ""

print_message $CYAN "方案1: 重新配置IPv6隧道"
cat << 'EOF'
sudo systemctl stop ipv6proxy

# 删除现有隧道
sudo ip link set he-ipv6 down 2>/dev/null || true
sudo ip tunnel del he-ipv6 2>/dev/null || true

# 重新创建隧道
EOF

echo "sudo ip tunnel add he-ipv6 mode sit remote $HE_SERVER_IPV4 local $LOCAL_IPV4 ttl 255"
echo "sudo ip link set he-ipv6 up"
echo "sudo ip addr add $LOCAL_IPV6/64 dev he-ipv6"
echo "sudo ip addr add $PING_IPV6/$PREFIX_LENGTH dev he-ipv6"
echo "sudo ip -6 route add $ROUTED_PREFIX/$PREFIX_LENGTH dev he-ipv6"
echo "sudo ip -6 route add ::/0 via $HE_SERVER_IPV6 dev he-ipv6"
echo "sudo ip link set he-ipv6 mtu 1480"
echo ""

print_message $CYAN "方案2: 添加本地路由（关键步骤）"
echo "sudo ip -6 route add local $ROUTED_PREFIX/$PREFIX_LENGTH dev lo"
echo ""

print_message $CYAN "方案3: 修复系统参数"
cat << 'EOF'
sudo sysctl -w net.ipv6.conf.all.forwarding=1
sudo sysctl -w net.ipv6.ip_nonlocal_bind=1
sudo sysctl -w net.ipv6.conf.all.proxy_ndp=1
EOF
echo ""

print_message $CYAN "方案4: 重启服务"
echo "sudo systemctl restart ipv6proxy"
echo ""

# 9. 自动修复选项
print_message $YELLOW "是否要自动执行修复？(y/N): "
read -r auto_fix

if [[ $auto_fix =~ ^[Yy]$ ]]; then
    print_message $BLUE "开始自动修复..."
    
    # 停止服务
    print_message $BLUE "停止代理服务..."
    systemctl stop ipv6proxy
    
    # 重新配置隧道
    print_message $BLUE "重新配置IPv6隧道..."
    ip link set he-ipv6 down 2>/dev/null || true
    ip tunnel del he-ipv6 2>/dev/null || true
    
    ip tunnel add he-ipv6 mode sit remote "$HE_SERVER_IPV4" local "$LOCAL_IPV4" ttl 255
    ip link set he-ipv6 up
    ip addr add "$LOCAL_IPV6/64" dev he-ipv6
    ip addr add "$PING_IPV6/$PREFIX_LENGTH" dev he-ipv6
    ip -6 route add "$ROUTED_PREFIX/$PREFIX_LENGTH" dev he-ipv6
    ip -6 route add ::/0 via "$HE_SERVER_IPV6" dev he-ipv6
    ip link set he-ipv6 mtu 1480
    
    # 添加本地路由
    print_message $BLUE "添加本地路由..."
    ip -6 route add local "$ROUTED_PREFIX/$PREFIX_LENGTH" dev lo 2>/dev/null || true
    
    # 设置系统参数
    print_message $BLUE "设置系统参数..."
    sysctl -w net.ipv6.conf.all.forwarding=1
    sysctl -w net.ipv6.ip_nonlocal_bind=1
    sysctl -w net.ipv6.conf.all.proxy_ndp=1
    
    # 重启服务
    print_message $BLUE "重启代理服务..."
    systemctl start ipv6proxy
    
    sleep 3
    
    # 测试修复结果
    print_message $BLUE "测试修复结果..."
    if ping6 -c 2 -W 3 -I he-ipv6 "$HE_SERVER_IPV6" &>/dev/null; then
        print_message $GREEN "✓ IPv6隧道连接正常"
    else
        print_message $RED "✗ IPv6隧道仍有问题"
    fi
    
    LOCAL_IP=$(ip addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n1)
    if timeout 10 curl -s --proxy "http://$LOCAL_IP:100" "http://ipv6.google.com" >/dev/null 2>&1; then
        print_message $GREEN "✓ IPv6代理修复成功！"
        echo ""
        print_message $CYAN "测试命令："
        echo "curl --proxy http://$LOCAL_IP:100 http://ipv6.icanhazip.com"
    else
        print_message $RED "✗ IPv6代理仍有问题"
        echo ""
        print_message $YELLOW "请检查HE隧道配置是否正确，或联系HE技术支持"
    fi
    
    print_message $GREEN "自动修复完成！"
else
    print_message $BLUE "请手动执行上述修复命令"
fi

echo ""
print_message $PURPLE "=== 诊断完成 ==="
