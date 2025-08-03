# IPv6 代理服务器

一个高性能的IPv6代理服务器，支持随机IPv6地址生成和HE IPv6隧道配置。

## 🚀 特性

- **随机IPv6地址**: 从指定CIDR范围生成随机IPv6地址进行代理
- **双模式代理**: 支持随机IPv6和真实IPv4两种代理模式
- **HE隧道支持**: 自动配置Hurricane Electric IPv6隧道
- **认证支持**: 支持Basic认证保护代理服务
- **DNS over HTTPS/TLS**: 支持DoH和DoT进行IPv6地址解析
- **系统集成**: 自动配置系统路由和转发规则
- **服务化部署**: 支持systemd服务管理

## 📋 系统要求

- **操作系统**: Ubuntu 18.04+ / Debian 9+ / CentOS 7+
- **权限**: Root权限
- **内存**: 最少256MB可用内存
- **网络**: 稳定的IPv4网络连接
- **Go版本**: 1.18+ (安装脚本会自动安装)

## 🛠️ 快速安装

### 方法一：一键安装脚本

\`\`\`bash
# 下载并运行安装脚本
curl -fsSL https://raw.githubusercontent.com/qza666/v6/main/install.sh | sudo bash
\`\`\`

或者：

\`\`\`bash
# 克隆仓库
git clone https://github.com/qza666/v6.git
cd v6

# 运行安装脚本
sudo bash install.sh
\`\`\`

### 方法二：手动安装

1. **安装依赖**
\`\`\`bash
sudo apt update
sudo apt install -y curl wget git build-essential
\`\`\`

2. **安装Go语言**
\`\`\`bash
wget https://go.dev/dl/go1.18.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.18.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc
\`\`\`

3. **克隆并编译项目**
\`\`\`bash
git clone https://github.com/qza666/v6.git
cd v6
go mod tidy
go build -o ipv6proxy cmd/ipv6proxy/main.go
\`\`\`

## ⚙️ 配置说明

### 命令行参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `-cidr` | 必填 | IPv6 CIDR范围 (如: 2001:470:1f05:17b::/64) |
| `-real-ipv4` | 必填 | 服务器真实IPv4地址 |
| `-random-ipv6-port` | 100 | 随机IPv6代理端口 |
| `-real-ipv4-port` | 101 | 真实IPv4代理端口 |
| `-bind` | 0.0.0.0 | 绑定地址 |
| `-username` | "" | Basic认证用户名 |
| `-password` | "" | Basic认证密码 |
| `-verbose` | false | 详细日志输出 |

### 配置示例

\`\`\`bash
# 基本使用
./ipv6proxy -cidr "2001:470:1f05:17b::/64" -real-ipv4 "1.2.3.4"

# 带认证的使用
./ipv6proxy -cidr "2001:470:1f05:17b::/64" -real-ipv4 "1.2.3.4" \
           -username "user" -password "pass"

# 自定义端口
./ipv6proxy -cidr "2001:470:1f05:17b::/64" -real-ipv4 "1.2.3.4" \
           -random-ipv6-port 8080 -real-ipv4-port 8081
\`\`\`

## 🌐 HE IPv6隧道配置

### 获取HE隧道信息

1. 访问 [Hurricane Electric IPv6 Tunnel Broker](https://tunnelbroker.net/)
2. 注册账号并创建隧道
3. 记录以下信息：
   - Server IPv4 Address (HE服务器IPv4)
   - Server IPv6 Address (HE服务器IPv6)
   - Client IPv6 Address (客户端IPv6)
   - Routed /64 或 /48 (路由前缀)

### 隧道配置示例

安装脚本会引导您输入以下信息：

\`\`\`
HE服务器IPv4地址: 216.66.80.26
本机IPv4地址: 1.2.3.4
HE服务器IPv6地址: 2001:470:1f04:17b::1/64
HE分配的IPv6前缀: 2001:470:1f05:17b::/64
\`\`\`

## 🔧 使用方法

### 服务管理

\`\`\`bash
# 启动服务
sudo systemctl start ipv6proxy

# 停止服务
sudo systemctl stop ipv6proxy

# 重启服务
sudo systemctl restart ipv6proxy

# 查看状态
sudo systemctl status ipv6proxy

# 设置开机自启
sudo systemctl enable ipv6proxy

# 查看日志
sudo journalctl -u ipv6proxy -f
\`\`\`

### 代理使用

#### 随机IPv6代理 (端口100)
\`\`\`bash
# HTTP代理
export http_proxy=http://服务器IP:100
export https_proxy=http://服务器IP:100

# SOCKS代理 (如果支持)
curl --proxy socks5://服务器IP:100 http://ipv6.google.com
\`\`\`

#### 真实IPv4代理 (端口101)
\`\`\`bash
# HTTP代理
export http_proxy=http://服务器IP:101
export https_proxy=http://服务器IP:101
\`\`\`

#### 带认证的代理
\`\`\`bash
# 如果设置了用户名密码
export http_proxy=http://用户名:密码@服务器IP:100
export https_proxy=http://用户名:密码@服务器IP:100
\`\`\`

### 测试连接

\`\`\`bash
# 测试IPv6连接
curl -6 http://ipv6.google.com

# 测试代理
curl --proxy http://服务器IP:100 http://ipv6.google.com

# 查看出口IP
curl --proxy http://服务器IP:100 http://ipv6.icanhazip.com
\`\`\`

## 📁 文件结构

\`\`\`
v6/
├── cmd/ipv6proxy/main.go          # 主程序入口
├── internal/
│   ├── config/config.go           # 配置管理
│   ├── proxy/proxy.go             # 代理服务器逻辑
│   ├── dns/
│   │   ├── doh.go                 # DNS over HTTPS
│   │   └── dot.go                 # DNS over TLS
│   └── sysutils/sysutils.go       # 系统工具
├── install.sh                     # 一键安装脚本
├── quick-install.sh               # 快速安装脚本
├── docker-compose.yml             # Docker部署配置
├── Dockerfile                     # Docker镜像构建
└── README.md                      # 项目文档
\`\`\`

## 🐳 Docker部署

### 使用Docker Compose

\`\`\`bash
# 克隆项目
git clone https://github.com/qza666/v6.git
cd v6

# 编辑配置
cp .env.example .env
nano .env

# 启动服务
docker-compose up -d
\`\`\`

### 手动Docker部署

\`\`\`bash
# 构建镜像
docker build -t ipv6proxy .

# 运行容器
docker run -d --name ipv6proxy \
  --privileged \
  --net=host \
  -e CIDR="2001:470:1f05:17b::/64" \
  -e REAL_IPV4="1.2.3.4" \
  ipv6proxy
\`\`\`

## 🔍 故障排除

### 常见问题

1. **权限错误**
   \`\`\`bash
   # 确保以root权限运行
   sudo ./ipv6proxy -cidr "..." -real-ipv4 "..."
   \`\`\`

2. **端口被占用**
   \`\`\`bash
   # 检查端口占用
   sudo netstat -tlnp | grep :100
   
   # 使用其他端口
   ./ipv6proxy -random-ipv6-port 8080 -real-ipv4-port 8081
   \`\`\`

3. **IPv6隧道连接失败**
   \`\`\`bash
   # 检查隧道状态
   ip -6 addr show he-ipv6
   
   # 测试隧道连接
   ping6 -I he-ipv6 2001:470:1f04:17b::1
   \`\`\`

4. **DNS解析失败**
   \`\`\`bash
   # 测试IPv6 DNS解析
   nslookup -type=AAAA google.com
   
   # 检查系统DNS配置
   cat /etc/resolv.conf
   \`\`\`

### 日志分析

\`\`\`bash
# 查看详细日志
sudo journalctl -u ipv6proxy -f --no-pager

# 查看系统日志
sudo dmesg | grep -i ipv6

# 查看网络配置
ip -6 addr show
ip -6 route show
\`\`\`

### 性能优化

\`\`\`bash
# 调整系统参数
echo 'net.ipv6.conf.all.forwarding=1' >> /etc/sysctl.conf
echo 'net.ipv6.neigh.default.gc_thresh1=1024' >> /etc/sysctl.conf
echo 'net.ipv6.neigh.default.gc_thresh2=2048' >> /etc/sysctl.conf
echo 'net.ipv6.neigh.default.gc_thresh3=4096' >> /etc/sysctl.conf
sysctl -p
\`\`\`

## 📊 监控和维护

### 系统监控

\`\`\`bash
# 查看连接数
ss -tuln | grep -E ':(100|101)'

# 查看内存使用
ps aux | grep ipv6proxy

# 查看网络流量
iftop -i he-ipv6
\`\`\`

### 定期维护

\`\`\`bash
# 创建维护脚本
cat > /etc/cron.daily/ipv6proxy-maintenance << 'EOF'
#!/bin/bash
# 重启服务以清理连接
systemctl restart ipv6proxy
# 清理日志
journalctl --vacuum-time=7d
EOF

chmod +x /etc/cron.daily/ipv6proxy-maintenance
\`\`\`

## 🤝 贡献

欢迎提交Issue和Pull Request！

## 📄 许可证

本项目采用MIT许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🆘 支持

如果您遇到问题，请：

1. 查看本文档的故障排除部分
2. 搜索已有的 [Issues](https://github.com/qza666/v6/issues)
3. 创建新的Issue并提供详细信息

## 📞 联系方式

- GitHub: [qza666](https://github.com/qza666)
- Email: support@example.com

---

**⚠️ 免责声明**: 请遵守当地法律法规，合理使用代理服务。
