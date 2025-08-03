#!/bin/bash

# IPv6 代理服务器快速安装脚本
# 适用于 Ubuntu/Debian 系统

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 全局变量
SCRIPT_VERSION="1.0.0"
PROJECT_NAME="IPv6 Proxy Server"
REPO_URL="https://github.com/qza666/v6.git"
INSTALL_DIR="/opt/ipv6proxy"
SERVICE_NAME="ipv6proxy"
LOG_FILE="/tmp/ipv6proxy-install.log"

# 打印带颜色的消息
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] ${message}${NC}" | tee -a "$LOG_FILE"
}

print_info() { print_message "$BLUE" "ℹ️  $1"; }
print_success() { print_message "$GREEN" "✅ $1"; }
print_warning() { print_message "$YELLOW" "⚠️  $1"; }
print_error() { print_message "$RED" "❌ $1"; }

# 显示横幅
show_banner() {
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                    IPv6 代理服务器                           ║
║                   快速安装脚本 v1.0.0                        ║
║                                                              ║
║  🚀 一键部署高性能IPv6代理服务                                ║
║  🌐 支持HE隧道自动配置                                        ║
║  🔒 支持认证和安全配置                                        ║
╚══════════════════════════════════════════════════════════════╝
EOF
}

# 检查系统要求
check_system() {
    print_info "检查系统环境..."
    
    # 检查操作系统
    if [[ ! -f /etc/os-release ]]; then
        print_error "不支持的操作系统"
        exit 1
    fi
    
    source /etc/os-release
    print_info "检测到系统: $PRETTY_NAME"
    
    # 检查架构
    ARCH=$(uname -m)
    if [[ "$ARCH" != "x86_64" ]]; then
        print_warning "检测到架构: $ARCH，可能不完全支持"
    fi
    
    # 检查root权限
    if [[ $EUID -ne 0 ]]; then
        print_error "请使用root权限运行此脚本"
        echo "使用方法: sudo $0"
        exit 1
    fi
    
    # 检查内存
    TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
    if [[ $TOTAL_MEM -lt 512 ]]; then
        print_warning "系统内存较低 (${TOTAL_MEM}MB)，建议至少512MB"
        read -p "是否继续安装？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    print_success "系统检查通过"
}

# 安装依赖
install_dependencies() {
    print_info "安装系统依赖..."
    
    # 更新包列表
    apt-get update -qq
    
    # 安装基础工具
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        curl wget git build-essential \
        net-tools iproute2 iptables \
        systemd cron logrotate \
        ca-certificates gnupg lsb-release
    
    print_success "依赖安装完成"
}

# 安装Go语言
install_go() {
    print_info "检查Go语言环境..."
    
    GO_VERSION="1.21.0"
    GO_TAR="go${GO_VERSION}.linux-amd64.tar.gz"
    
    if command -v go &> /dev/null; then
        CURRENT_GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
        if [[ "$(printf '%s\n' "$GO_VERSION" "$CURRENT_GO_VERSION" | sort -V | head -n1)" == "$GO_VERSION" ]]; then
            print_success "Go版本检查通过: $CURRENT_GO_VERSION"
            return 0
        fi
    fi
    
    print_info "安装Go $GO_VERSION..."
    
    # 下载Go
    cd /tmp
    if [[ ! -f "$GO_TAR" ]]; then
        wget -q --show-progress "https://go.dev/dl/$GO_TAR"
    fi
    
    # 安装Go
    rm -rf /usr/local/go
    tar -C /usr/local -xzf "$GO_TAR"
    
    # 设置环境变量
    cat > /etc/profile.d/go.sh << 'EOF'
export PATH=$PATH:/usr/local/go/bin
export GOPATH=/opt/go
export GO111MODULE=on
export GOPROXY=https://goproxy.cn,direct
EOF
    
    source /etc/profile.d/go.sh
    mkdir -p /opt/go
    
    # 验证安装
    if /usr/local/go/bin/go version; then
        print_success "Go安装成功"
    else
        print_error "Go安装失败"
        exit 1
    fi
}

# 下载和编译项目
build_project() {
    print_info "下载项目源码..."
    
    # 创建安装目录
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # 克隆项目
    if [[ -d ".git" ]]; then
        print_info "更新现有项目..."
        git pull origin main
    else
        git clone "$REPO_URL" .
    fi
    
    print_info "编译项目..."
    
    # 设置Go环境
    export PATH=$PATH:/usr/local/go/bin
    export GO111MODULE=on
    export GOPROXY=https://goproxy.cn,direct
    
    # 下载依赖
    go mod tidy
    
    # 编译项目
    go build -ldflags "-s -w" -o ipv6proxy cmd/ipv6proxy/main.go
    
    # 设置权限
    chmod +x ipv6proxy
    
    print_success "项目编译完成"
}

# 配置系统参数
configure_system() {
    print_info "配置系统参数..."
    
    # 配置内核参数
    cat > /etc/sysctl.d/99-ipv6proxy.conf << 'EOF'
# IPv6 Proxy System Configuration
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.ipv6.conf.all.proxy_ndp = 1
net.ipv6.ip_nonlocal_bind = 1

# Network performance tuning
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# Neighbor table optimization
net.ipv4.neigh.default.gc_thresh1 = 1024
net.ipv4.neigh.default.gc_thresh2 = 2048
net.ipv4.neigh.default.gc_thresh3 = 4096
net.ipv6.neigh.default.gc_thresh1 = 1024
net.ipv6.neigh.default.gc_thresh2 = 2048
net.ipv6.neigh.default.gc_thresh3 = 4096
EOF
    
    # 应用配置
    sysctl -p /etc/sysctl.d/99-ipv6proxy.conf
    
    print_success "系统参数配置完成"
}

# 交互式配置
interactive_config() {
    print_info "开始交互式配置..."
    
    # IPv6 CIDR配置
    while true; do
        echo
        print_info "请输入IPv6 CIDR范围 (例如: 2001:470:1f05:17b::/64)"
        read -p "IPv6 CIDR: " IPV6_CIDR
        
        if [[ $IPV6_CIDR =~ ^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}::/[0-9]+$ ]]; then
            break
        else
            print_error "无效的IPv6 CIDR格式，请重新输入"
        fi
    done
    
    # 真实IPv4地址配置
    while true; do
        echo
        print_info "请输入服务器的真实IPv4地址"
        # 尝试自动检测
        AUTO_IPV4=$(curl -s -4 ifconfig.me 2>/dev/null || curl -s -4 icanhazip.com 2>/dev/null || echo "")
        if [[ -n "$AUTO_IPV4" ]]; then
            print_info "检测到公网IPv4地址: $AUTO_IPV4"
            read -p "真实IPv4地址 [$AUTO_IPV4]: " REAL_IPV4
            REAL_IPV4=${REAL_IPV4:-$AUTO_IPV4}
        else
            read -p "真实IPv4地址: " REAL_IPV4
        fi
        
        if [[ $REAL_IPV4 =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            break
        else
            print_error "无效的IPv4地址格式，请重新输入"
        fi
    done
    
    # 端口配置
    echo
    print_info "配置代理端口 (默认: 随机IPv6端口=100, 真实IPv4端口=101)"
    read -p "随机IPv6代理端口 [100]: " RANDOM_PORT
    RANDOM_PORT=${RANDOM_PORT:-100}
    
    read -p "真实IPv4代理端口 [101]: " REAL_PORT
    REAL_PORT=${REAL_PORT:-101}
    
    # 认证配置
    echo
    print_info "是否启用代理认证？(推荐启用)"
    read -p "启用认证 (y/N): " -n 1 -r ENABLE_AUTH
    echo
    
    if [[ $ENABLE_AUTH =~ ^[Yy]$ ]]; then
        read -p "用户名: " PROXY_USER
        read -s -p "密码: " PROXY_PASS
        echo
        AUTH_PARAMS="-username \"$PROXY_USER\" -password \"$PROXY_PASS\""
    else
        AUTH_PARAMS=""
    fi
    
    # 保存配置
    cat > "$INSTALL_DIR/config.env" << EOF
IPV6_CIDR="$IPV6_CIDR"
REAL_IPV4="$REAL_IPV4"
RANDOM_PORT="$RANDOM_PORT"
REAL_PORT="$REAL_PORT"
AUTH_PARAMS="$AUTH_PARAMS"
EOF
    
    print_success "配置保存完成"
}

# 创建systemd服务
create_service() {
    print_info "创建系统服务..."
    
    # 加载配置
    source "$INSTALL_DIR/config.env"
    
    # 创建服务文件
    cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=IPv6 Proxy Server
Documentation=https://github.com/qza666/v6
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/ipv6proxy -cidr "$IPV6_CIDR" -real-ipv4 "$REAL_IPV4" -random-ipv6-port $RANDOM_PORT -real-ipv4-port $REAL_PORT $AUTH_PARAMS
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=ipv6proxy

# Security settings
NoNewPrivileges=false
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=$INSTALL_DIR /etc /var/log

# Resource limits
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF
    
    # 重载systemd配置
    systemctl daemon-reload
    
    print_success "系统服务创建完成"
}

# 配置日志轮转
setup_logrotate() {
    print_info "配置日志轮转..."
    
    cat > "/etc/logrotate.d/$SERVICE_NAME" << 'EOF'
/var/log/ipv6proxy/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
    postrotate
        systemctl reload ipv6proxy > /dev/null 2>&1 || true
    endscript
}
EOF
    
    # 创建日志目录
    mkdir -p /var/log/ipv6proxy
    
    print_success "日志轮转配置完成"
}

# 创建管理脚本
create_management_scripts() {
    print_info "创建管理脚本..."
    
    # 创建管理脚本
    cat > "$INSTALL_DIR/manage.sh" << 'EOF'
#!/bin/bash

SERVICE_NAME="ipv6proxy"
INSTALL_DIR="/opt/ipv6proxy"

case "$1" in
    start)
        echo "启动IPv6代理服务..."
        systemctl start $SERVICE_NAME
        ;;
    stop)
        echo "停止IPv6代理服务..."
        systemctl stop $SERVICE_NAME
        ;;
    restart)
        echo "重启IPv6代理服务..."
        systemctl restart $SERVICE_NAME
        ;;
    status)
        systemctl status $SERVICE_NAME
        ;;
    logs)
        journalctl -u $SERVICE_NAME -f
        ;;
    enable)
        echo "设置开机自启..."
        systemctl enable $SERVICE_NAME
        ;;
    disable)
        echo "取消开机自启..."
        systemctl disable $SERVICE_NAME
        ;;
    update)
        echo "更新项目..."
        cd $INSTALL_DIR
        git pull origin main
        go build -ldflags "-s -w" -o ipv6proxy cmd/ipv6proxy/main.go
        systemctl restart $SERVICE_NAME
        echo "更新完成"
        ;;
    *)
        echo "使用方法: $0 {start|stop|restart|status|logs|enable|disable|update}"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$INSTALL_DIR/manage.sh"
    
    # 创建全局命令链接
    ln -sf "$INSTALL_DIR/manage.sh" "/usr/local/bin/ipv6proxy"
    
    print_success "管理脚本创建完成"
}

# 显示安装结果
show_result() {
    source "$INSTALL_DIR/config.env"
    
    echo
    print_success "🎉 IPv6代理服务器安装完成！"
    echo
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                        安装信息                              ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║ 安装目录: $INSTALL_DIR"
    echo "║ 配置文件: $INSTALL_DIR/config.env"
    echo "║ 服务名称: $SERVICE_NAME"
    echo "║ IPv6 CIDR: $IPV6_CIDR"
    echo "║ 真实IPv4: $REAL_IPV4"
    echo "║ 随机IPv6端口: $RANDOM_PORT"
    echo "║ 真实IPv4端口: $REAL_PORT"
    if [[ -n "$AUTH_PARAMS" ]]; then
        echo "║ 认证: 已启用"
    else
        echo "║ 认证: 未启用"
    fi
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo
    echo "🚀 快速开始:"
    echo "   启动服务: ipv6proxy start"
    echo "   查看状态: ipv6proxy status"
    echo "   查看日志: ipv6proxy logs"
    echo "   设置自启: ipv6proxy enable"
    echo
    echo "🌐 代理地址:"
    echo "   随机IPv6: http://$REAL_IPV4:$RANDOM_PORT"
    echo "   真实IPv4: http://$REAL_IPV4:$REAL_PORT"
    echo
    echo "📖 更多信息请查看: $INSTALL_DIR/README.md"
    echo
    
    # 询问是否启动服务
    read -p "是否现在启动服务？(Y/n): " -n 1 -r START_NOW
    echo
    if [[ ! $START_NOW =~ ^[Nn]$ ]]; then
        print_info "启动服务..."
        systemctl start $SERVICE_NAME
        systemctl enable $SERVICE_NAME
        sleep 2
        
        if systemctl is-active $SERVICE_NAME >/dev/null 2>&1; then
            print_success "服务启动成功！"
        else
            print_error "服务启动失败，请检查日志: ipv6proxy logs"
        fi
    fi
}

# 主函数
main() {
    # 初始化日志
    echo "IPv6 Proxy Server Installation Log - $(date)" > "$LOG_FILE"
    
    show_banner
    echo
    
    print_info "开始安装 $PROJECT_NAME v$SCRIPT_VERSION"
    
    # 执行安装步骤
    check_system
    install_dependencies
    install_go
    build_project
    configure_system
    interactive_config
    create_service
    setup_logrotate
    create_management_scripts
    
    show_result
    
    print_success "安装完成！日志保存在: $LOG_FILE"
}

# 错误处理
trap 'print_error "安装过程中发生错误，请查看日志: $LOG_FILE"; exit 1' ERR

# 执行主函数
main "$@"
