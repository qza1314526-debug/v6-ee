#!/bin/bash

# IPv6代理服务器一键安装脚本
# 支持单IPv4和多IPv4配置模式
# 必须在交互式终端中运行

# 检查是否为交互式终端
if [ ! -t 0 ] || [ ! -t 1 ]; then
    echo "❌ 错误: 此脚本必须在交互式终端中运行"
    echo ""
    echo "请使用以下方式运行："
    echo "1. 下载脚本: wget https://raw.githubusercontent.com/qza1314526-debug/v6-ee/main/install.sh"
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
REPO_URL="https://github.com/qza1314526-debug/v6-ee.git"
REPO_DIR="v6"
TUNNEL_NAME="he-ipv6"
CONFIG_DIR="/etc/he-ipv6"
CONFIG_FILE="$CONFIG_DIR/$TUNNEL_NAME.conf"

# 多IP配置数组
declare -a MULTI_IPV4_ARRAY

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# 初始化安装环境
init_environment() {
    mkdir -p "$TEMP_DIR" "$CONFIG_DIR"
    exec 1> >(tee -a "$LOG_FILE")
    exec 2> >(tee -a "$LOG_FILE" >&2)
    print_message $BLUE "安装开始时间: $(date)"
    print_message $BLUE "正在初始化安装环境..."
}

# 检查root权限
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_message $RED "错误: 请以root权限运行此脚本"
        exit 1
    fi
}

# 网络连接检查
check_network() {
    local test_hosts=("google.com" "github.com" "1.1.1.1")
    local success=0
    
    print_message $BLUE "检查网络连接..."
    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W 3 $host &>/dev/null; then
            success=1
            break
        fi
    done
    
    if [ $success -eq 0 ]; then
        print_message $YELLOW "警告: 网络连接不稳定，这可能会影响安装过程"
        read -p "是否继续？(y/n): " continue_setup
        if [[ $continue_setup != [yY] ]]; then
            exit 1
        fi
    fi
}

# 检查并安装依赖
install_packages() {
    local packages="$1"
    print_message $BLUE "正在安装: $packages"
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $packages
}

# 安装基本工具
install_basic_tools() {
    print_message $BLUE "检查并安装必要工具..."
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
            print_message $RED "错误: $tool 安装失败"
            exit 1
        fi
    done
    print_message $GREEN "基本工具安装完成"
}

# 检查Go版本
check_go_version() {
    if command -v go &>/dev/null; then
        local current_version=$(go version | awk '{print $3}' | sed 's/go//')
        if [ "$(printf '%s\n' "$GO_VERSION" "$current_version" | sort -V | head -n1)" = "$GO_VERSION" ]; then
            print_message $GREEN "检测到Go版本 $current_version，符合要求..."
            return 0
        fi
    fi
    return 1
}

# 安装Go
install_go() {
    if check_go_version; then
        print_message $GREEN "Go版本检查通过，跳过安装"
        return 0
    fi

    print_message $BLUE "正在安装Go ${GO_VERSION}..."
    
    if [ ! -f "$TEMP_DIR/$GO_TAR" ]; then
        print_message $BLUE "下载Go安装包..."
        wget -P "$TEMP_DIR" "https://go.dev/dl/$GO_TAR" || {
            print_message $RED "错误: 下载Go失败"
            exit 1
        }
        print_message $GREEN "Go安装包下载完成"
    fi
    
    print_message $BLUE "删除旧的Go安装..."
    rm -rf /usr/local/go
    
    print_message $BLUE "解压Go安装包..."
    tar -C /usr/local -xzf "$TEMP_DIR/$GO_TAR" || {
        print_message $RED "错误: 解压Go失败"
        exit 1
    }
    print_message $GREEN "Go解压完成"
    
    print_message $BLUE "设置环境变量..."
    if ! grep -q "/usr/local/go/bin" /etc/profile; then
        echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
        echo 'export GO111MODULE=on' >> /etc/profile
        print_message $GREEN "环境变量已添加到/etc/profile"
    fi
    
    # 立即设置当前会话的环境变量
    export PATH=$PATH:/usr/local/go/bin
    export GO111MODULE=on
    print_message $GREEN "当前会话环境变量已设置"
    
    print_message $BLUE "验证Go安装..."
    if ! /usr/local/go/bin/go version; then
        print_message $RED "错误: Go安装失败，无法执行go命令"
        exit 1
    fi
    
    print_message $GREEN "Go安装成功完成"
}

# 克隆或更新代码仓库
clone_or_update_repo() {
    print_message $BLUE "准备项目代码..."
    if [ -d "$REPO_DIR/.git" ]; then
        print_message $BLUE "更新项目代码..."
        cd $REPO_DIR
        # 先获取远程信息
        git fetch origin 2>/dev/null || true
        # 获取默认分支
        DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
        print_message $BLUE "检测到默认分支: $DEFAULT_BRANCH"
        
        # 尝试更新到默认分支
        if git show-ref --verify --quiet refs/remotes/origin/$DEFAULT_BRANCH; then
            print_message $BLUE "切换到分支: $DEFAULT_BRANCH"
            git checkout -B $DEFAULT_BRANCH origin/$DEFAULT_BRANCH
        elif git show-ref --verify --quiet refs/remotes/origin/main; then
            print_message $BLUE "切换到分支: main"
            git checkout -B main origin/main
        elif git show-ref --verify --quiet refs/remotes/origin/master; then
            print_message $BLUE "切换到分支: master"
            git checkout -B master origin/master
        else
            print_message $RED "错误: 找不到可用的分支"
            exit 1
        fi
        cd ..
    else
        print_message $BLUE "克隆项目代码..."
        # 直接克隆，Git会自动选择默认分支
        if ! git clone --depth 1 $REPO_URL $REPO_DIR; then
            print_message $RED "错误: 克隆项目失败"
            exit 1
        fi
    fi
    print_message $GREEN "项目代码准备完成"
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

# 检测服务器所有IPv4地址
detect_server_ipv4() {
    print_message $BLUE "正在检测服务器IPv4地址..."
    
    # 获取所有网卡的IPv4地址
    local all_ips=($(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | sort -u))
    
    # 尝试获取公网IP
    local public_ip=""
    for service in "ifconfig.me" "icanhazip.com" "ipinfo.io/ip"; do
        public_ip=$(curl -s -4 --connect-timeout 5 "$service" 2>/dev/null | grep -oE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' || echo "")
        if [[ -n "$public_ip" ]]; then
            break
        fi
    done
    
    print_message $CYAN "检测到的IPv4地址："
    local i=1
    for ip in "${all_ips[@]}"; do
        echo "  $i) $ip (本地)"
        ((i++))
    done
    
    if [[ -n "$public_ip" && ! " ${all_ips[@]} " =~ " ${public_ip} " ]]; then
        echo "  $i) $public_ip (公网)"
        all_ips+=("$public_ip")
    fi
    
    echo "${all_ips[@]}"
}

# 配置多IPv4代理
configure_multi_ipv4() {
    print_message $PURPLE "=== 多IPv4代理配置 ==="
    
    # 检测可用IP
    local available_ips_output=$(detect_server_ipv4)
    local available_ips=($(echo "$available_ips_output" | tail -n 1))
    
    if [ ${#available_ips[@]} -eq 0 ]; then
        print_message $RED "错误: 未检测到可用的IPv4地址"
        return 1
    fi
    
    print_message $GREEN "检测到 ${#available_ips[@]} 个IPv4地址"
    
    # 强制使用交互式终端
    exec < /dev/tty
    
    echo -n "是否配置多IPv4代理？(y/N): "
    read use_multi_ip
    
    if [[ ! $use_multi_ip =~ ^[Yy]$ ]]; then
        # 单IP模式
        print_message $BLUE "选择单IP模式"
        while true; do
            print_message $CYAN "可用的IPv4地址："
            for i in "${!available_ips[@]}"; do
                echo "  $((i+1))) ${available_ips[i]}"
            done
            echo "  $((${#available_ips[@]}+1))) 手动输入IP地址"
            echo -n "请选择要使用的IPv4地址 [1]: "
            read ip_choice
            ip_choice=${ip_choice:-1}
            
            if [[ $ip_choice =~ ^[0-9]+$ ]]; then
                if [ $ip_choice -ge 1 ] && [ $ip_choice -le ${#available_ips[@]} ]; then
                    SINGLE_IPV4="${available_ips[$((ip_choice-1))]}"
                    print_message $GREEN "选择的IPv4地址: $SINGLE_IPV4"
                    break
                elif [ $ip_choice -eq $((${#available_ips[@]}+1)) ]; then
                    echo -n "请输入IPv4地址: "
                    read manual_ip
                    if validate_ipv4 "$manual_ip"; then
                        SINGLE_IPV4="$manual_ip"
                        print_message $GREEN "选择的IPv4地址: $SINGLE_IPV4"
                        break
                    else
                        print_message $RED "无效的IPv4地址格式"
                    fi
                else
                    print_message $RED "无效选择，请重新输入"
                fi
            else
                print_message $RED "无效选择，请重新输入"
            fi
        done
        return 0
    fi
    
    # 多IP模式
    print_message $BLUE "配置多IPv4代理模式"
    print_message $YELLOW "每个IPv4地址将在端口101上提供代理服务"
    print_message $YELLOW "使用哪个IP访问代理，就从哪个IP出去"
    echo ""
    
    while true; do
        print_message $CYAN "可用的IPv4地址："
        for i in "${!available_ips[@]}"; do
            local status=""
            for selected_ip in "${MULTI_IPV4_ARRAY[@]}"; do
                if [[ "$selected_ip" == "${available_ips[i]}" ]]; then
                    status=" (已选择)"
                    break
                fi
            done
            echo "  $((i+1))) ${available_ips[i]}$status"
        done
        echo "  $((${#available_ips[@]}+1))) 手动添加IP地址"
        
        echo ""
        print_message $GREEN "已选择的IP地址: ${MULTI_IPV4_ARRAY[@]}"
        echo ""
        print_message $CYAN "选项："
        echo "  1-${#available_ips[@]}) 选择/取消选择IP地址"
        echo "  $((${#available_ips[@]}+1))) 手动添加IP地址"
        echo "  d) 完成选择"
        echo "  q) 退出"
        
        echo -n "请输入选择: "
        read choice
        
        case $choice in
            [1-9]|[1-9][0-9])
                if [ $choice -ge 1 ] && [ $choice -le ${#available_ips[@]} ]; then
                    local selected_ip="${available_ips[$((choice-1))]}"
                    
                    # 检查是否已选择
                    local found=false
                    for i in "${!MULTI_IPV4_ARRAY[@]}"; do
                        if [[ "${MULTI_IPV4_ARRAY[i]}" == "$selected_ip" ]]; then
                            # 取消选择
                            unset MULTI_IPV4_ARRAY[i]
                            MULTI_IPV4_ARRAY=("${MULTI_IPV4_ARRAY[@]}")  # 重新索引数组
                            print_message $YELLOW "已取消选择: $selected_ip"
                            found=true
                            break
                        fi
                    done
                    
                    if [ "$found" = false ]; then
                        # 添加选择
                        MULTI_IPV4_ARRAY+=("$selected_ip")
                        print_message $GREEN "已选择: $selected_ip"
                    fi
                elif [ $choice -eq $((${#available_ips[@]}+1)) ]; then
                    echo -n "请输入IPv4地址: "
                    read manual_ip
                    if validate_ipv4 "$manual_ip"; then
                        # 检查是否已存在
                        local exists=false
                        for existing_ip in "${MULTI_IPV4_ARRAY[@]}"; do
                            if [[ "$existing_ip" == "$manual_ip" ]]; then
                                exists=true
                                break
                            fi
                        done
                        if [ "$exists" = false ]; then
                            MULTI_IPV4_ARRAY+=("$manual_ip")
                            print_message $GREEN "已添加: $manual_ip"
                        else
                            print_message $YELLOW "IP地址已存在: $manual_ip"
                        fi
                    else
                        print_message $RED "无效的IPv4地址格式"
                    fi
                else
                    print_message $RED "无效选择"
                fi
                ;;
            d|D)
                if [ ${#MULTI_IPV4_ARRAY[@]} -eq 0 ]; then
                    print_message $RED "错误: 至少需要选择一个IP地址"
                else
                    print_message $GREEN "完成选择，共选择了 ${#MULTI_IPV4_ARRAY[@]} 个IP地址"
                    break
                fi
                ;;
            q|Q)
                print_message $RED "用户取消配置"
                exit 1
                ;;
            *)
                print_message $RED "无效选择"
                ;;
        esac
        echo ""
    done
    
    print_message $GREEN "多IPv4配置完成："
    for ip in "${MULTI_IPV4_ARRAY[@]}"; do
        echo "  - $ip:101"
    done
}

# 检查系统内存
check_system_memory() {
    print_message $BLUE "检查系统内存..."
    local total_mem=$(free -m | awk '/^Mem:/{print $2}')
    local available_mem=$(free -m | awk '/^Mem:/{print $7}')
    
    # 如果available列不存在，使用free列
    if [ -z "$available_mem" ] || [ "$available_mem" = "" ]; then
        available_mem=$(free -m | awk '/^Mem:/{print $4}')
    fi
    
    print_message $CYAN "总内存: ${total_mem}MB, 可用内存: ${available_mem}MB"
    
    if [ "$available_mem" -lt 256 ]; then
        print_message $YELLOW "警告: 系统可用内存不足 (${available_mem}MB)"
        read -p "是否继续？(y/n): " continue_setup
        if [[ $continue_setup != [yY] ]]; then
            exit 1
        fi
    else
        print_message $GREEN "内存检查通过"
    fi
}

# 优化系统配置
optimize_system_config() {
    print_message $BLUE "优化系统配置..."
    local sysctl_file="/etc/sysctl.conf"
    local need_reload=0
    
    declare -A params=(
        ["net.ipv4.ip_forward"]="1"
        ["net.ipv6.conf.all.forwarding"]="1"
        ["net.ipv6.conf.all.proxy_ndp"]="1"
        ["net.ipv6.ip_nonlocal_bind"]="1"
        ["net.ipv4.neigh.default.gc_thresh1"]="1024"
        ["net.ipv4.neigh.default.gc_thresh2"]="2048"
        ["net.ipv4.neigh.default.gc_thresh3"]="4096"
        ["net.ipv6.neigh.default.gc_thresh1"]="1024"
        ["net.ipv6.neigh.default.gc_thresh2"]="2048"
        ["net.ipv6.neigh.default.gc_thresh3"]="4096"
    )
    
    print_message $BLUE "配置系统参数..."
    for param in "${!params[@]}"; do
        if ! grep -q "^$param = ${params[$param]}$" $sysctl_file; then
            sed -i "/$param/d" $sysctl_file
            echo "$param = ${params[$param]}" >> $sysctl_file
            need_reload=1
            print_message $BLUE "添加参数: $param = ${params[$param]}"
        fi
    done
    
    if [ $need_reload -eq 1 ]; then
        print_message $BLUE "重新加载系统参数..."
        if ! sysctl -p &>/dev/null; then
            print_message $YELLOW "警告: 部分系统参数加载失败，但继续安装..."
        fi
    fi
    print_message $GREEN "系统配置优化完成"
}

# 检查并删除现有隧道
check_and_remove_existing_tunnel() {
    if ip link show $TUNNEL_NAME &>/dev/null; then
        print_message $YELLOW "发现现有隧道 $TUNNEL_NAME"
        read -p "是否删除现有隧道？(y/n): " confirm
        if [[ $confirm == [yY] ]]; then
            print_message $BLUE "正在删除现有隧道..."
            ip link set $TUNNEL_NAME down 2>/dev/null || true
            ip tunnel del $TUNNEL_NAME 2>/dev/null || true
            sed -i "/# HE IPv6 Tunnel.*$TUNNEL_NAME/,/# End IPv6 Tunnel/d" /etc/network/interfaces
            print_message $GREEN "现有隧道已删除"
        else
            print_message $RED "用户取消操作"
            exit 1
        fi
    fi
}

# 生成本机IPv6地址
generate_local_ipv6() {
    local he_ipv6=$1
    echo "${he_ipv6%::1}::2"
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

    print_message $PURPLE "=== HE IPv6隧道配置 ==="
    print_message $YELLOW "请准备好从 https://tunnelbroker.net 获取的隧道信息"
    echo ""

    # 获取并验证HE服务器IPv4地址
    while true; do
        echo -n "请输入HE服务器IPv4地址: "
        read he_ipv4
        if validate_ipv4 "$he_ipv4"; then
            print_message $BLUE "正在测试连接到 $he_ipv4..."
            if ping -c 1 -W 3 "$he_ipv4" &>/dev/null; then
                print_message $GREEN "连接测试成功"
                break
            else
                print_message $YELLOW "警告: 无法连接到服务器 $he_ipv4，但地址格式正确"
                echo -n "是否继续使用此地址？(y/N): "
                read confirm
                if [[ $confirm =~ ^[Yy]$ ]]; then
                    break
                fi
            fi
        else
            print_message $RED "无效的IPv4地址格式，请重新输入"
        fi
    done

    # 获取并验证本机IPv4地址
    print_message $BLUE "正在检测本机IPv4地址..."
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
                print_message $YELLOW "警告: 地址 $local_ipv4 可能不在本机网卡上"
                echo -n "是否继续使用此地址？(y/N): "
                read confirm
                if [[ $confirm =~ ^[Yy]$ ]]; then
                    break
                fi
            fi
        else
            print_message $RED "无效的IPv4地址格式，请重新输入"
        fi
    done

    # 获取并验证HE服务器IPv6地址
    while true; do
        echo -n "请输入HE服务器IPv6地址（包括前缀长度，如 2001:470:1f04:17b::1/64）: "
        read he_ipv6
        if [[ $he_ipv6 =~ ^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}::1/[0-9]+$ ]]; then
            break
        fi
        print_message $RED "无效的IPv6地址格式，请重新输入"
        print_message $YELLOW "示例格式: 2001:470:1f04:17b::1/64"
    done

    # 生成本机IPv6地址
    local_ipv6=$(generate_local_ipv6 "${he_ipv6%/*}")
    local_ipv6="${local_ipv6}/${he_ipv6#*/}"
    print_message $GREEN "本机IPv6地址: $local_ipv6"

    # 获取并验证IPv6前缀
    while true; do
        echo -n "请输入HE分配的IPv6前缀（如 2001:470:1f05:17b::/64）: "
        read routed_prefix
        if [[ $routed_prefix =~ ^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}::/[0-9]+$ ]]; then
            break
        fi
        print_message $RED "无效的IPv6前缀格式，请重新输入"
        print_message $YELLOW "示例格式: 2001:470:1f05:17b::/64"
    done

    prefix_length="${routed_prefix#*/}"
    routed_prefix="${routed_prefix%/*}"
    ping_ipv6="${routed_prefix%:*}:1"

    print_message $CYAN "配置摘要:"
    echo "  HE服务器IPv4: $he_ipv4"
    echo "  本机IPv4: $local_ipv4"
    echo "  HE服务器IPv6: ${he_ipv6%/*}"
    echo "  本机IPv6: ${local_ipv6%/*}"
    echo "  路由前缀: $routed_prefix/$prefix_length"
    echo -n "确认配置并继续？(y/N): "
    read confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_message $RED "用户取消配置"
        return 1
    fi

    # 配置隧道
    print_message $BLUE "正在配置隧道..."
    ip tunnel add $TUNNEL_NAME mode sit remote $he_ipv4 local $local_ipv4 ttl 255 2>/dev/null || {
        print_message $YELLOW "隧道可能已存在，尝试删除后重新创建..."
        ip tunnel del $TUNNEL_NAME 2>/dev/null || true
        ip tunnel add $TUNNEL_NAME mode sit remote $he_ipv4 local $local_ipv4 ttl 255 || {
            print_message $RED "创建隧道失败"
            return 1
        }
    }

    ip link set $TUNNEL_NAME up
    ip addr add ${local_ipv6} dev $TUNNEL_NAME 2>/dev/null || true
    ip addr add ${ping_ipv6}/${prefix_length} dev $TUNNEL_NAME 2>/dev/null || true
    ip -6 route add ${routed_prefix}/${prefix_length} dev $TUNNEL_NAME 2>/dev/null || true
    ip -6 route add ::/0 via ${he_ipv6%/*} dev $TUNNEL_NAME 2>/dev/null || true
    ip link set $TUNNEL_NAME mtu 1480

    # 添加本地路由以支持IPv6代理
    print_message $BLUE "配置IPv6本地路由..."
    ip -6 route add local ${routed_prefix}/${prefix_length} dev lo 2>/dev/null || true

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
    up ip -6 route add local ${routed_prefix}/${prefix_length} dev lo
# End IPv6 Tunnel
EOF

    # 测试连接
    print_message $BLUE "测试IPv6连接..."
    if ping6 -c 3 -I $TUNNEL_NAME ${he_ipv6%/*} &>/dev/null; then
        print_message $GREEN "IPv6隧道连接测试成功！"
    else
        print_message $YELLOW "警告: IPv6隧道连接测试失败，但配置已保存"
    fi

    print_message $GREEN "IPv6隧道配置完成"
    return 0
}

# 创建系统服务
create_service() {
    local ipv6_cidr="$1"
    
    # 构建命令行参数
    local cmd_args="-cidr \"$ipv6_cidr\" -random-ipv6-port 100"
    
    if [ ${#MULTI_IPV4_ARRAY[@]} -gt 0 ]; then
        # 多IP模式
        local multi_ip_str=""
        for ip in "${MULTI_IPV4_ARRAY[@]}"; do
            if [ -n "$multi_ip_str" ]; then
                multi_ip_str="$multi_ip_str,$ip:101"
            else
                multi_ip_str="$ip:101"
            fi
        done
        cmd_args="$cmd_args -multi-ipv4 \"$multi_ip_str\""
    else
        # 单IP模式
        cmd_args="$cmd_args -real-ipv4-port 101 -real-ipv4 \"$SINGLE_IPV4\""
    fi
    
    cat > /etc/systemd/system/ipv6proxy.service << EOF
[Unit]
Description=IPv6 Proxy Service
After=network.target

[Service]
ExecStart=/usr/local/go/bin/go run /root/v6/cmd/ipv6proxy/main.go $cmd_args
Restart=always
User=root
WorkingDirectory=/root/v6
Environment=PATH=/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    print_message $GREEN "系统服务创建完成"
}

# 显示安装完成信息
show_completion_info() {
    local ipv6_cidr="$1"
    
    print_message $GREEN "🎉 安装完成！"
    echo ""
    print_message $CYAN "IPv6代理服务配置详情："
    echo "- 随机IPv6代理端口：100"
    echo "- IPv6 CIDR：$ipv6_cidr"
    echo ""

    if [ ${#MULTI_IPV4_ARRAY[@]} -gt 0 ]; then
        print_message $CYAN "多IPv4代理配置："
        for ip in "${MULTI_IPV4_ARRAY[@]}"; do
            echo "- IPv4代理: http://$ip:101 (出口IP: $ip)"
        done
    else
        print_message $CYAN "单IPv4代理配置："
        echo "- IPv4代理: http://$SINGLE_IPV4:101 (出口IP: $SINGLE_IPV4)"
    fi

    echo ""
    print_message $PURPLE "管理命令："
    echo "1. 启动服务：systemctl start ipv6proxy"
    echo "2. 设置开机自启：systemctl enable ipv6proxy"
    echo "3. 查看服务状态：systemctl status ipv6proxy"
    echo "4. 查看服务日志：journalctl -u ipv6proxy -f"
    echo "5. 停止服务：systemctl stop ipv6proxy"
    echo ""
    
    print_message $PURPLE "配置文件位置："
    echo "- 隧道配置：$CONFIG_FILE"
    echo "- 服务配置：/etc/systemd/system/ipv6proxy.service"
    echo ""
    
    print_message $YELLOW "如需修改配置，编辑相应文件后请运行："
    echo "systemctl daemon-reload"
    echo "systemctl restart ipv6proxy"
    echo ""
}

# 主函数
main() {
    print_message $PURPLE "🚀 IPv6代理服务器一键安装脚本"
    print_message $PURPLE "支持单IPv4和多IPv4配置模式"
    echo ""
    
    # 强制交互模式
    if [ ! -t 0 ]; then
        print_message $RED "错误: 此脚本必须在交互式终端中运行"
        print_message $YELLOW "请下载脚本后直接执行："
        echo "  wget https://raw.githubusercontent.com/qza1314526-debug/v6-ee/main/install.sh"
        echo "  chmod +x install.sh"
        echo "  sudo ./install.sh"
        exit 1
    fi
    
    # 初始化环境
    print_message $PURPLE "=== 步骤1: 初始化环境 ==="
    init_environment
    check_root
    check_network
    print_message $GREEN "步骤1完成"
    
    # 先安装基本工具
    print_message $PURPLE "=== 步骤2: 安装基本工具 ==="
    install_basic_tools
    print_message $GREEN "步骤2完成"
    
    # 安装Go
    print_message $PURPLE "=== 步骤3: 安装Go语言 ==="
    install_go
    print_message $GREEN "步骤3完成"
    
    # 克隆代码
    print_message $PURPLE "=== 步骤4: 获取项目代码 ==="
    clone_or_update_repo
    print_message $GREEN "步骤4完成"
    
    # 继续其他配置
    print_message $PURPLE "=== 步骤5: 系统配置 ==="
    check_system_memory
    optimize_system_config
    print_message $GREEN "步骤5完成"
    
    # 配置多IPv4代理
    print_message $PURPLE "=== 步骤6: 配置IPv4代理 ==="
    if ! configure_multi_ipv4; then
        print_message $RED "IPv4配置失败"
        exit 1
    fi
    print_message $GREEN "步骤6完成"
    
    # 配置HE IPv6隧道
    print_message $PURPLE "=== 步骤7: 配置IPv6隧道 ==="
    print_message $YELLOW "现在需要配置HE IPv6隧道，请准备好以下信息："
    echo "1. HE服务器IPv4地址 (从tunnelbroker.net获取)"
    echo "2. 本机IPv4地址 (服务器的公网IP)"
    echo "3. HE服务器IPv6地址 (格式: xxxx:xxxx:xxxx:xxxx::1/64)"
    echo "4. HE分配的IPv6前缀 (格式: xxxx:xxxx:xxxx:xxxx::/64)"
    echo ""
    echo -n "按回车键继续配置..."
    read
    
    if ! configure_he_tunnel; then
        print_message $RED "隧道配置失败，请检查输入的信息是否正确"
        exit 1
    fi
    print_message $GREEN "步骤7完成"
    
    # 从配置文件读取信息
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        ipv6_cidr="${ROUTED_PREFIX}/${PREFIX_LENGTH}"
    else
        print_message $RED "错误：找不到隧道配置文件"
        exit 1
    fi
    
    # 创建并启动服务
    print_message $PURPLE "=== 步骤8: 创建系统服务 ==="
    create_service "$ipv6_cidr"
    print_message $GREEN "步骤8完成"
    
    # 显示完成信息
    show_completion_info "$ipv6_cidr"

    # 询问是否启动服务
    echo -n "是否现在启动服务？(Y/n): "
    read start_service
    if [[ ! $start_service =~ ^[Nn]$ ]]; then
        print_message $BLUE "正在启动服务..."
        systemctl start ipv6proxy
        systemctl enable ipv6proxy
        sleep 2
        
        if systemctl is-active ipv6proxy >/dev/null 2>&1; then
            print_message $GREEN "✅ 服务已成功启动并设置为开机自启！"
            echo ""
            print_message $CYAN "🌐 代理地址："
            echo "  随机IPv6代理: http://任意IP:100"
            
            if [ ${#MULTI_IPV4_ARRAY[@]} -gt 0 ]; then
                for ip in "${MULTI_IPV4_ARRAY[@]}"; do
                    echo "  IPv4代理($ip): http://$ip:101"
                done
            else
                echo "  IPv4代理: http://$SINGLE_IPV4:101"
            fi
            
            echo ""
            print_message $CYAN "🧪 测试代理："
            echo "  curl --proxy http://任意IP:100 http://ipv6.icanhazip.com"
            
            if [ ${#MULTI_IPV4_ARRAY[@]} -gt 0 ]; then
                for ip in "${MULTI_IPV4_ARRAY[@]}"; do
                    echo "  curl --proxy http://$ip:101 http://icanhazip.com  # 出口IP: $ip"
                done
            else
                echo "  curl --proxy http://$SINGLE_IPV4:101 http://icanhazip.com"
            fi
            
            # 添加故障排除提示
            echo ""
            print_message $YELLOW "如果IPv6代理无法工作，请尝试以下命令修复："
            echo "1. 添加本地路由: ip -6 route add local $ipv6_cidr dev lo"
            echo "2. 检查系统参数: sysctl net.ipv6.ip_nonlocal_bind"
            echo "3. 重启服务: systemctl restart ipv6proxy"
            
        else
            print_message $RED "❌ 服务启动失败，请检查日志："
            echo "journalctl -u ipv6proxy -n 50 --no-pager"
        fi
    fi

    echo ""
    print_message $GREEN "✅ 安装和配置已完成。请检查上述信息，确保所有配置正确。"
    print_message $BLUE "📋 安装日志保存在：$LOG_FILE"
    echo ""
    print_message $YELLOW "如有任何问题，请查看："
    echo "1. 服务日志: journalctl -u ipv6proxy -f"
    echo "2. 隧道状态: ip -6 addr show $TUNNEL_NAME"
    echo "3. 路由信息: ip -6 route show"
}

# 执行主函数
main "$@"
