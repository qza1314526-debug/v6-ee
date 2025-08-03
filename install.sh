#!/bin/bash

# IPv6代理服务器安装脚本 - 交互式版本
# 必须在交互式终端中运行

# 检查是否为交互式终端
if [ ! -t 0 ] || [ ! -t 1 ]; then
    echo "❌ 错误: 此脚本必须在交互式终端中运行"
    echo ""
    echo "请使用以下方式运行："
    echo "1. 下载脚本: wget https://raw.githubusercontent.com/qza666/v6/main/install.sh"
    echo "2. 添加执行权限: chmod +x install.sh"
    echo "3. 运行脚本: sudo ./install.sh"
    echo ""
    echo "❌ 不支持管道执行 (curl ... | bash)"
    exit 1
fi

# 启用错误检查
set -e

# 全局变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMP_DIR="/tmp/he-ipv6-setup"
LOG_FILE="$TEMP_DIR/install.log"
GO_VERSION="1.18"
GO_TAR="go${GO_VERSION}.linux-amd64.tar.gz"
REPO_URL="https://github.com/qza666/v6.git"
REPO_DIR="v6"
TUNNEL_NAME="he-ipv6"
CONFIG_DIR="/etc/he-ipv6"
CONFIG_FILE="$CONFIG_DIR/$TUNNEL_NAME.conf"

# 初始化安装环境
init_environment() {
    mkdir -p "$TEMP_DIR" "$CONFIG_DIR"
    exec 1> >(tee -a "$LOG_FILE")
    exec 2> >(tee -a "$LOG_FILE" >&2)
    echo "安装开始时间: $(date)"
    echo "正在初始化安装环境..."
}

# 检查root权限
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "错误: 请以root权限运行此脚本"
        exit 1
    fi
}

# 网络连接检查
check_network() {
    local test_hosts=("google.com" "github.com" "1.1.1.1")
    local success=0
    
    echo "检查网络连接..."
    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W 3 $host &>/dev/null; then
            success=1
            break
        fi
    done
    
    if [ $success -eq 0 ]; then
        echo "警告: 网络连接不稳定，这可能会影响安装过程"
        read -p "是否继续？(y/n): " continue_setup
        if [[ $continue_setup != [yY] ]]; then
            exit 1
        fi
    fi
}

# 检查并安装依赖
install_packages() {
    local packages="$1"
    echo "正在安装: $packages"
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $packages
}


# 安装基本工具
install_basic_tools() {
    echo "检查并安装必要工具..."
    local base_tools="curl wget"
    local dev_tools="build-essential git"
    local net_tools="ufw iproute2 net-tools"
    
    # 首先安装基本工具
    if ! command -v curl &>/dev/null || ! command -v wget &>/dev/null; then
        install_packages "$base_tools"
    fi
    
    # 然后安装开发工具
    if ! command -v git &>/dev/null; then
        install_packages "$dev_tools"
    fi
    
    # 最后安装网络工具
    install_packages "$net_tools"
    
    # 验证关键工具是否安装成功
    local required_tools="git curl wget"
    for tool in $required_tools; do
        if ! command -v $tool &>/dev/null; then
            echo "错误: $tool 安装失败"
            exit 1
        fi
    done
}

# 检查Go版本
check_go_version() {
    if command -v go &>/dev/null; then
        local current_version=$(go version | awk '{print $3}' | sed 's/go//')
        if [ "$(printf '%s\n' "$GO_VERSION" "$current_version" | sort -V | head -n1)" = "$GO_VERSION" ]; then
            echo "检测到Go版本 $current_version，符合要求..."
            return 0
        fi
    fi
    return 1
}

# 安装Go
install_go() {
    if check_go_version; then
        echo "Go版本检查通过，跳过安装"
        return 0
    fi

    echo "正在安装Go ${GO_VERSION}..."
    
    if [ ! -f "$TEMP_DIR/$GO_TAR" ]; then
        echo "下载Go安装包..."
        wget -P "$TEMP_DIR" "https://go.dev/dl/$GO_TAR" || {
            echo "错误: 下载Go失败"
            exit 1
        }
        echo "Go安装包下载完成"
    fi
    
    echo "删除旧的Go安装..."
    rm -rf /usr/local/go
    
    echo "解压Go安装包..."
    tar -C /usr/local -xzf "$TEMP_DIR/$GO_TAR" || {
        echo "错误: 解压Go失败"
        exit 1
    }
    echo "Go解压完成"
    
    echo "设置环境变量..."
    if ! grep -q "/usr/local/go/bin" /etc/profile; then
        echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
        echo 'export GO111MODULE=on' >> /etc/profile
        echo "环境变量已添加到/etc/profile"
    fi
    
    # 立即设置当前会话的环境变量
    export PATH=$PATH:/usr/local/go/bin
    export GO111MODULE=on
    echo "当前会话环境变量已设置"
    
    echo "验证Go安装..."
    if ! /usr/local/go/bin/go version; then
        echo "错误: Go安装失败，无法执行go命令"
        exit 1
    fi
    
    echo "Go安装成功完成"
}

# 克隆或更新代码仓库
clone_or_update_repo() {
    echo "准备项目代码..."
    if [ -d "$REPO_DIR/.git" ]; then
        echo "更新项目代码..."
        cd $REPO_DIR
        # 获取默认分支名称
        DEFAULT_BRANCH=$(git remote show origin | grep 'HEAD branch' | cut -d' ' -f5 2>/dev/null || echo "main")
        if ! git fetch --depth 1 origin $DEFAULT_BRANCH 2>/dev/null; then
            echo "尝试main分支..."
            if ! git fetch --depth 1 origin main 2>/dev/null; then
                echo "尝试master分支..."
                git fetch --depth 1 origin master
                git reset --hard origin/master
            else
                git reset --hard origin/main
            fi
        else
            git reset --hard origin/$DEFAULT_BRANCH
        fi
        cd ..
    else
        echo "克隆项目代码..."
        git clone --depth 1 $REPO_URL
    fi
}

# 验证IPv4地址
validate_ipv4() {
    local ip=$1
    if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if [[ $octet -gt 255 || ($octet =~ ^0[0-9]+) ]]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

# 验证IPv6地址
validate_ipv6() {
    local ip=$1
    if [[ $ip =~ ^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$ ]]; then
        return 0
    fi
    return 1
}

# 生成本机IPv6地址
generate_local_ipv6() {
    local he_ipv6=$1
    echo "${he_ipv6%::1}::2"
}

# 检查系统内存
check_system_memory() {
    echo "检查系统内存..."
    local total_mem=$(free -m | awk '/^Mem:/{print $2}')
    local available_mem=$(free -m | awk '/^Mem:/{print $7}')
    
    # 如果available列不存在，使用free列
    if [ -z "$available_mem" ] || [ "$available_mem" = "" ]; then
        available_mem=$(free -m | awk '/^Mem:/{print $4}')
    fi
    
    echo "总内存: ${total_mem}MB, 可用内存: ${available_mem}MB"
    
    if [ "$available_mem" -lt 256 ]; then
        echo "警告: 系统可用内存不足 (${available_mem}MB)"
        read -p "是否继续？(y/n): " continue_setup
        if [[ $continue_setup != [yY] ]]; then
            exit 1
        fi
    else
        echo "内存检查通过"
    fi
}

# 优化系统配置
optimize_system_config() {
    echo "优化系统配置..."
    local sysctl_file="/etc/sysctl.conf"
    local need_reload=0
    
    declare -A params=(
        ["net.ipv4.ip_forward"]="1"
        ["net.ipv6.conf.all.forwarding"]="1"
        ["net.ipv6.conf.all.proxy_ndp"]="1"
        ["net.ipv4.neigh.default.gc_thresh1"]="1024"
        ["net.ipv4.neigh.default.gc_thresh2"]="2048"
        ["net.ipv4.neigh.default.gc_thresh3"]="4096"
        ["net.ipv6.neigh.default.gc_thresh1"]="1024"
        ["net.ipv6.neigh.default.gc_thresh2"]="2048"
        ["net.ipv6.neigh.default.gc_thresh3"]="4096"
    )
    
    echo "配置系统参数..."
    for param in "${!params[@]}"; do
        if ! grep -q "^$param = ${params[$param]}$" $sysctl_file; then
            sed -i "/$param/d" $sysctl_file
            echo "$param = ${params[$param]}" >> $sysctl_file
            need_reload=1
            echo "添加参数: $param = ${params[$param]}"
        fi
    done
    
    if [ $need_reload -eq 1 ]; then
        echo "重新加载系统参数..."
        sysctl -p &>/dev/null
    fi
    echo "系统配置优化完成"
}

# 检查并删除现有隧道
check_and_remove_existing_tunnel() {
    if ip link show $TUNNEL_NAME &>/dev/null; then
        echo "发现现有隧道 $TUNNEL_NAME"
        read -p "是否删除现有隧道？(y/n): " confirm
        if [[ $confirm == [yY] ]]; then
            echo "正在删除现有隧道..."
            ip link set $TUNNEL_NAME down 2>/dev/null || true
            ip tunnel del $TUNNEL_NAME 2>/dev/null || true
            sed -i "/# HE IPv6 Tunnel.*$TUNNEL_NAME/,/# End IPv6 Tunnel/d" /etc/network/interfaces
            echo "现有隧道已删除"
        else
            echo "用户取消操作"
            exit 1
        fi
    fi
}

# 配置HE IPv6隧道
configure_he_tunnel() {
    local he_ipv4
    local local_ipv4
    local he_ipv6
    local local_ipv6
    local routed_prefix
    local prefix_length
    local ping_ipv6

    check_and_remove_existing_tunnel

    # 强制使用交互式终端
    exec < /dev/tty

    # 获取并验证HE服务器IPv4地址
    while true; do
        echo -n "请输入HE服务器IPv4地址: "
        read he_ipv4
        if validate_ipv4 "$he_ipv4"; then
            echo "正在测试连接到 $he_ipv4..."
            if ping -c 1 -W 3 "$he_ipv4" &>/dev/null; then
                echo "连接测试成功"
                break
            else
                echo "警告: 无法连接到服务器 $he_ipv4，但地址格式正确"
                echo -n "是否继续使用此地址？(y/N): "
                read confirm
                if [[ $confirm =~ ^[Yy]$ ]]; then
                    break
                fi
            fi
        else
            echo "无效的IPv4地址格式，请重新输入"
        fi
    done

    # 获取并验证本机IPv4地址
    echo "正在检测本机IPv4地址..."
    AUTO_LOCAL_IPV4=$(ip route get 8.8.8.8 | awk '{print $7; exit}' 2>/dev/null || curl -s -4 ifconfig.me 2>/dev/null || echo "")
    while true; do
        if [[ -n "$AUTO_LOCAL_IPV4" ]]; then
            echo -n "请输入本机IPv4地址 [$AUTO_LOCAL_IPV4]: "
        else
            echo -n "请输入本机IPv4地址: "
        fi
        read local_ipv4
        if [[ -z "$local_ipv4" && -n "$AUTO_LOCAL_IPV4" ]]; then
            local_ipv4="$AUTO_LOCAL_IPV4"
        fi
        if validate_ipv4 "$local_ipv4"; then
            if ip addr | grep -q "$local_ipv4" || [[ "$local_ipv4" == "$AUTO_LOCAL_IPV4" ]]; then
                break
            else
                echo "警告: 地址 $local_ipv4 可能不在本机网卡上"
                echo -n "是否继续使用此地址？(y/N): "
                read confirm
                if [[ $confirm =~ ^[Yy]$ ]]; then
                    break
                fi
            fi
        else
            echo "无效的IPv4地址格式，请重新输入"
        fi
    done

    # 获取并验证HE服务器IPv6地址
    while true; do
        echo -n "请输入HE服务器IPv6地址（包括前缀长度，如 2001:470:1f04:17b::1/64）: "
        read he_ipv6
        if [[ $he_ipv6 =~ ^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}::1/[0-9]+$ ]]; then
            break
        fi
        echo "无效的IPv6地址格式，请重新输入"
        echo "示例格式: 2001:470:1f04:17b::1/64"
    done

    # 生成本机IPv6地址
    local_ipv6=$(generate_local_ipv6 "${he_ipv6%/*}")
    local_ipv6="${local_ipv6}/${he_ipv6#*/}"
    echo "本机IPv6地址: $local_ipv6"

    # 获取并验证IPv6前缀
    while true; do
        echo -n "请输入HE分配的IPv6前缀（如 2001:470:1f05:17b::/64）: "
        read routed_prefix
        if [[ $routed_prefix =~ ^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}::/[0-9]+$ ]]; then
            break
        fi
        echo "无效的IPv6前缀格式，请重新输入"
        echo "示例格式: 2001:470:1f05:17b::/64"
    done

    prefix_length="${routed_prefix#*/}"
    routed_prefix="${routed_prefix%/*}"
    ping_ipv6="${routed_prefix%:*}:1"

    echo "配置摘要:"
    echo "  HE服务器IPv4: $he_ipv4"
    echo "  本机IPv4: $local_ipv4"
    echo "  HE服务器IPv6: ${he_ipv6%/*}"
    echo "  本机IPv6: ${local_ipv6%/*}"
    echo "  路由前缀: $routed_prefix/$prefix_length"
    echo -n "确认配置并继续？(y/N): "
    read confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo "用户取消配置"
        return 1
    fi

    # 配置隧道
    echo "正在配置隧道..."
    ip tunnel add $TUNNEL_NAME mode sit remote $he_ipv4 local $local_ipv4 ttl 255 || {
        echo "创建隧道失败"
        return 1
    }

    ip link set $TUNNEL_NAME up
    ip addr add ${local_ipv6} dev $TUNNEL_NAME
    ip addr add ${ping_ipv6}/${prefix_length} dev $TUNNEL_NAME
    ip -6 route add ${routed_prefix}/${prefix_length} dev $TUNNEL_NAME
    ip -6 route add ::/0 via ${he_ipv6%/*} dev $TUNNEL_NAME
    ip link set $TUNNEL_NAME mtu 1480

    # 保存配置
    cat > "$CONFIG_FILE" << EOF
HE_SERVER_IPV4=$he_ipv4
HE_SERVER_IPV6=${he_ipv6%/*}
LOCAL_IPV4=$local_ipv4
LOCAL_IPV6=${local_ipv6%/*}
ROUTED_PREFIX=$routed_prefix
PREFIX_LENGTH=$prefix_length
PING_IPV6=$ping_ipv6
EOF

    # 添加网络接口配置
    cat >> /etc/network/interfaces << EOF

# HE IPv6 Tunnel $TUNNEL_NAME
auto $TUNNEL_NAME
iface $TUNNEL_NAME inet6 v4tunnel
    address ${local_ipv6%/*}
    netmask 64
    endpoint $he_ipv4
    local $local_ipv4
    ttl 255
    gateway ${he_ipv6%/*}
    mtu 1480
    up ip -6 addr add ${ping_ipv6}/${prefix_length} dev \$IFACE
    up ip -6 route add ${routed_prefix}/${prefix_length} dev \$IFACE
    up ip -6 route add ::/0 via ${he_ipv6%/*} dev \$IFACE
# End IPv6 Tunnel
EOF

    # 测试连接
    echo "测试IPv6连接..."
    if ping6 -c 3 -I $TUNNEL_NAME ${he_ipv6%/*} &>/dev/null; then
        echo "IPv6隧道连接测试成功！"
    else
        echo "警告: IPv6隧道连接测试失败，但配置已保存"
    fi

    echo "IPv6隧道配置完成"
    return 0
}

# 创建系统服务
create_service() {
    local ipv6_cidr="$1"
    local real_ipv4="$2"
    
    cat > /etc/systemd/system/ipv6proxy.service << EOF
[Unit]
Description=IPv6 Proxy Service
After=network.target

[Service]
ExecStart=/usr/local/go/bin/go run /root/v6/cmd/ipv6proxy/main.go -cidr "$ipv6_cidr" -random-ipv6-port 100 -real-ipv4-port 101 -real-ipv4 "$real_ipv4"
Restart=always
User=root
WorkingDirectory=/root/v6
Environment=PATH=/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
}

# 主函数
main() {
    echo "开始安装IPv6 Proxy..."
    
    # 强制交互模式
    if [ ! -t 0 ]; then
        echo "错误: 此脚本必须在交互式终端中运行"
        echo "请下载脚本后直接执行："
        echo "  wget https://raw.githubusercontent.com/qza666/v6/main/install.sh"
        echo "  chmod +x install.sh"
        echo "  sudo ./install.sh"
        exit 1
    fi
    
    # 初始化环境
    echo "=== 步骤1: 初始化环境 ==="
    init_environment
    check_root
    check_network
    
    # Fix repository issues first
    echo "=== 步骤2: 修复软件源 ==="
    fix_repositories() {
        echo "修复软件源功能未实现"
    }
    fix_repositories
    
    # 先安装基本工具
    echo "=== 步骤3: 安装基本工具 ==="
    install_basic_tools
    
    # 安装Go
    echo "=== 步骤4: 安装Go语言 ==="
    install_go
    
    # 克隆代码
    echo "=== 步骤5: 获取项目代码 ==="
    clone_or_update_repo
    
    # 继续其他配置
    echo "=== 步骤6: 系统配置 ==="
    check_system_memory
    optimize_system_config
    
    # 配置HE IPv6隧道
    echo "=== 步骤7: 配置IPv6隧道 ==="
    echo "现在需要配置HE IPv6隧道，请准备好以下信息："
    echo "1. HE服务器IPv4地址 (从tunnelbroker.net获取)"
    echo "2. 本机IPv4地址 (服务器的公网IP)"
    echo "3. HE服务器IPv6地址 (格式: xxxx:xxxx:xxxx:xxxx::1/64)"
    echo "4. HE分配的IPv6前缀 (格式: xxxx:xxxx:xxxx:xxxx::/64)"
    echo ""
    echo -n "按回车键继续配置..."
    read
    
    if ! configure_he_tunnel; then
        echo "隧道配置失败，请检查输入的信息是否正确"
        exit 1
    fi
    
    # 从配置文件读取信息
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        ipv6_cidr="${ROUTED_PREFIX}/${PREFIX_LENGTH}"
        real_ipv4="${LOCAL_IPV4}"
    else
        echo "错误：找不到隧道配置文件"
        exit 1
    fi
    
    # 创建并启动服务
    echo "=== 步骤7: 创建系统服务 ==="
    create_service "$ipv6_cidr" "$real_ipv4"
    
    # 显示完成信息
    echo -e "\n🎉 安装完成！使用说明："
    cat << EOF

IPv6代理服务已配置完成。服务详情：
- 随机IPv6代理端口：100
- 真实IPv4代理端口：101
- IPv6 CIDR：$ipv6_cidr
- 真实IPv4地址：$real_ipv4

管理命令：
1. 启动服务：systemctl start ipv6proxy
2. 设置开机自启：systemctl enable ipv6proxy
3. 查看服务状态：systemctl status ipv6proxy
4. 查看服务日志：journalctl -u ipv6proxy -f
5. 停止服务：systemctl stop ipv6proxy

手动测试：
cd /root/v6
go run cmd/ipv6proxy/main.go -cidr $ipv6_cidr -real-ipv4 $real_ipv4

配置文件位置：
- 隧道配置：$CONFIG_FILE
- 服务配置：/etc/systemd/system/ipv6proxy.service

如需修改配置，编辑相应文件后请运行：
systemctl daemon-reload
systemctl restart ipv6proxy

EOF

    # 询问是否启动服务
    echo -n "是否现在启动服务？(Y/n): "
    read start_service
    if [[ ! $start_service =~ ^[Nn]$ ]]; then
        echo "正在启动服务..."
        systemctl start ipv6proxy
        systemctl enable ipv6proxy
        sleep 2
        
        if systemctl is-active ipv6proxy >/dev/null 2>&1; then
            echo "✅ 服务已成功启动并设置为开机自启！"
            echo ""
            echo "🌐 代理地址："
            echo "  随机IPv6代理: http://$real_ipv4:100"
            echo "  真实IPv4代理: http://$real_ipv4:101"
            echo ""
            echo "🧪 测试代理："
            echo "  curl --proxy http://$real_ipv4:100 http://ipv6.icanhazip.com"
            echo "  curl --proxy http://$real_ipv4:101 http://icanhazip.com"
        else
            echo "❌ 服务启动失败，请检查日志："
            echo "journalctl -u ipv6proxy -n 50 --no-pager"
        fi
    fi

    echo -e "\n✅ 安装和配置已完成。请检查上述信息，确保所有配置正确。"
    echo "📋 安装日志保存在：$LOG_FILE"
    echo ""
    echo "如有任何问题，请查看："
    echo "1. 服务日志: journalctl -u ipv6proxy -f"
    echo "2. 隧道状态: ip -6 addr show $TUNNEL_NAME"
    echo "3. 路由信息: ip -6 route show"
}

# 执行主函数
main
