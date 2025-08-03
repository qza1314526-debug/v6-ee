# IPv6代理服务器

一个高性能的IPv6代理服务器，支持随机IPv6地址生成和多IPv4出口配置。通过HE IPv6隧道提供IPv6连接，支持单IP和多IP代理模式。

## 🌟 核心特性

### 🎯 双模式代理
- **随机IPv6代理**: 从指定CIDR范围生成随机IPv6地址进行代理
- **多IPv4代理**: 支持多个IPv4地址，每个IP独立提供代理服务

### 🔀 智能路由
- **单IP模式**: 传统的单一出口IP配置
- **多IP模式**: 使用哪个IP访问代理，就从哪个IP出去
- **负载均衡**: 多个出口IP提供更好的性能和可靠性

### 🛡️ 安全认证
- **Basic认证**: 支持用户名密码认证保护代理服务
- **访问控制**: 可配置访问权限和用户管理

### 🌐 IPv6隧道
- **HE隧道支持**: 自动配置Hurricane Electric IPv6隧道
- **系统集成**: 自动配置系统路由和转发规则
- **持久化配置**: 重启后自动恢复隧道连接

## 📋 系统要求

| 项目 | 要求 |
|------|------|
| **操作系统** | Ubuntu 18.04+ / Debian 9+ / CentOS 7+ |
| **权限** | Root权限 |
| **内存** | 最少256MB可用内存 |
| **网络** | 稳定的IPv4网络连接 |
| **Go版本** | 1.18+ (安装脚本会自动安装) |

## 🚀 一键安装

### 快速安装

\`\`\`bash
# 下载安装脚本
wget https://raw.githubusercontent.com/qza1314526-debug/v6-ee/main/install.sh

# 添加执行权限
chmod +x install.sh

# 运行安装脚本
sudo ./install.sh
\`\`\`

> ⚠️ **注意**: 必须在交互式终端中运行，不支持管道执行

### 安装过程

安装脚本会自动完成以下步骤：

1. **环境检查**: 检查系统权限、网络连接和内存
2. **依赖安装**: 安装必要的系统工具和开发环境
3. **Go语言安装**: 自动下载并安装Go 1.18
4. **代码获取**: 克隆项目代码到本地
5. **系统优化**: 配置内核参数和网络设置
6. **IPv4配置**: 选择单IP或多IP代理模式
7. **IPv6隧道**: 配置HE IPv6隧道连接
8. **服务创建**: 创建systemd服务并设置自启动

## ⚙️ 配置说明

### HE IPv6隧道配置

在安装过程中，您需要提供以下信息：

| 配置项 | 说明 | 示例 |
|--------|------|------|
| **HE服务器IPv4** | Hurricane Electric服务器地址 | `216.66.80.26` |
| **本机IPv4** | 服务器的公网IPv4地址 | `1.2.3.4` |
| **HE服务器IPv6** | HE分配的服务器IPv6地址 | `2001:470:1f04:17b::1/64` |
| **IPv6前缀** | HE分配的路由前缀 | `2001:470:1f05:17b::/64` |

### 获取HE隧道信息

1. 访问 [Hurricane Electric IPv6 Tunnel Broker](https://tunnelbroker.net/)
2. 注册账号并创建隧道
3. 在隧道详情页面找到所需信息

### IPv4代理模式

#### 单IP模式
- 使用一个IPv4地址提供代理服务
- 所有请求都从同一个IP出去
- 适合简单的代理需求

#### 多IP模式
- 支持多个IPv4地址同时提供代理服务
- 每个IP在端口101上独立运行
- 使用哪个IP访问，就从哪个IP出去
- 适合需要多个出口IP的场景

## 🎮 使用方法

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

# 取消开机自启
sudo systemctl disable ipv6proxy

# 查看实时日志
sudo journalctl -u ipv6proxy -f
\`\`\`

### 代理使用

#### 随机IPv6代理 (端口100)

\`\`\`bash
# 设置环境变量
export http_proxy=http://服务器IP:100
export https_proxy=http://服务器IP:100

# 直接使用curl
curl --proxy http://服务器IP:100 http://ipv6.google.com

# 测试IPv6连接
curl --proxy http://服务器IP:100 http://ipv6.icanhazip.com
\`\`\`

#### IPv4代理 (端口101)

**单IP模式:**
\`\`\`bash
# 使用单一IPv4出口
curl --proxy http://服务器IP:101 http://icanhazip.com
\`\`\`

**多IP模式:**
\`\`\`bash
# 从IP1出去 (假设服务器有IP: 1.2.3.4)
curl --proxy http://1.2.3.4:101 http://icanhazip.com
# 返回: 1.2.3.4

# 从IP2出去 (假设服务器有IP: 5.6.7.8)
curl --proxy http://5.6.7.8:101 http://icanhazip.com  
# 返回: 5.6.7.8
\`\`\`

#### 带认证的代理

如果配置了用户名密码认证：

\`\`\`bash
# HTTP代理
export http_proxy=http://用户名:密码@服务器IP:100
export https_proxy=http://用户名:密码@服务器IP:100

# 直接使用
curl --proxy http://用户名:密码@服务器IP:100 http://example.com
\`\`\`

### 浏览器配置

#### Chrome/Edge
1. 设置 → 高级 → 系统 → 打开代理设置
2. 手动代理配置
3. HTTP代理: `服务器IP:100` (IPv6) 或 `服务器IP:101` (IPv4)

#### Firefox
1. 设置 → 网络设置 → 设置
2. 手动代理配置
3. HTTP代理: `服务器IP:100` 端口: `100`

## 🔧 高级配置

### 命令行参数

\`\`\`bash
# 查看所有参数
go run cmd/ipv6proxy/main.go -h
\`\`\`

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `-cidr` | 必填 | IPv6 CIDR范围 |
| `-real-ipv4` | 必填 | 服务器真实IPv4地址 |
| `-multi-ipv4` | "" | 多IPv4配置 (格式: ip1:port1,ip2:port2) |
| `-random-ipv6-port` | 100 | 随机IPv6代理端口 |
| `-real-ipv4-port` | 101 | 真实IPv4代理端口 |
| `-bind` | 0.0.0.0 | 绑定地址 |
| `-username` | "" | Basic认证用户名 |
| `-password` | "" | Basic认证密码 |
| `-verbose` | false | 详细日志输出 |

### 手动运行示例

\`\`\`bash
# 单IP模式
go run cmd/ipv6proxy/main.go \
  -cidr "2001:470:1f05:17b::/64" \
  -real-ipv4 "1.2.3.4"

# 多IP模式
go run cmd/ipv6proxy/main.go \
  -cidr "2001:470:1f05:17b::/64" \
  -multi-ipv4 "1.2.3.4:101,5.6.7.8:101"

# 带认证
go run cmd/ipv6proxy/main.go \
  -cidr "2001:470:1f05:17b::/64" \
  -real-ipv4 "1.2.3.4" \
  -username "user" \
  -password "pass"
\`\`\`

## 🧪 测试和验证

### 连接测试

\`\`\`bash
# 测试IPv6隧道
ping6 -c 3 2001:470:1f04:17b::1

# 测试IPv6代理
curl --proxy http://服务器IP:100 http://ipv6.icanhazip.com

# 测试IPv4代理
curl --proxy http://服务器IP:101 http://icanhazip.com

# 测试DNS解析
nslookup -type=AAAA google.com
\`\`\`

### 性能测试

\`\`\`bash
# 下载速度测试
curl --proxy http://服务器IP:100 -o /dev/null -s -w "%{speed_download}\n" http://speedtest.tele2.net/100MB.zip

# 延迟测试
curl --proxy http://服务器IP:100 -o /dev/null -s -w "%{time_total}\n" http://google.com
\`\`\`

### 日志分析

\`\`\`bash
# 查看服务状态
systemctl status ipv6proxy

# 查看详细日志
journalctl -u ipv6proxy -f --no-pager

# 查看错误日志
journalctl -u ipv6proxy -p err

# 查看最近50条日志
journalctl -u ipv6proxy -n 50
\`\`\`

## 🔍 故障排除

### 常见问题

#### 1. 权限错误
\`\`\`bash
# 确保以root权限运行
sudo systemctl start ipv6proxy
\`\`\`

#### 2. 端口被占用
\`\`\`bash
# 检查端口占用
sudo netstat -tlnp | grep :100
sudo netstat -tlnp | grep :101

# 杀死占用进程
sudo kill -9 <PID>
\`\`\`

#### 3. IPv6隧道连接失败
\`\`\`bash
# 检查隧道状态
ip -6 addr show he-ipv6

# 测试隧道连接
ping6 -I he-ipv6 2001:470:1f04:17b::1

# 重启隧道
sudo ip link set he-ipv6 down
sudo ip link set he-ipv6 up
\`\`\`

#### 4. DNS解析失败
\`\`\`bash
# 测试IPv6 DNS解析
nslookup -type=AAAA google.com

# 检查系统DNS配置
cat /etc/resolv.conf

# 手动设置DNS
echo "nameserver 2001:4860:4860::8888" >> /etc/resolv.conf
\`\`\`

#### 5. 服务启动失败
\`\`\`bash
# 查看详细错误信息
journalctl -u ipv6proxy -n 50 --no-pager

# 检查配置文件
cat /etc/systemd/system/ipv6proxy.service

# 重新加载配置
sudo systemctl daemon-reload
sudo systemctl restart ipv6proxy
\`\`\`

### 网络诊断

\`\`\`bash
# 检查网络接口
ip addr show

# 检查路由表
ip -6 route show

# 检查防火墙
sudo ufw status

# 检查系统参数
sysctl net.ipv6.conf.all.forwarding
sysctl net.ipv6.ip_nonlocal_bind
\`\`\`

### 性能优化

\`\`\`bash
# 调整系统参数
echo 'net.ipv6.neigh.default.gc_thresh1=1024' >> /etc/sysctl.conf
echo 'net.ipv6.neigh.default.gc_thresh2=2048' >> /etc/sysctl.conf
echo 'net.ipv6.neigh.default.gc_thresh3=4096' >> /etc/sysctl.conf
sysctl -p

# 调整文件描述符限制
echo '* soft nofile 65535' >> /etc/security/limits.conf
echo '* hard nofile 65535' >> /etc/security/limits.conf
\`\`\`

## 📊 监控和维护

### 系统监控

\`\`\`bash
# 查看连接数
ss -tuln | grep -E ':(100|101)'

# 查看内存使用
ps aux | grep ipv6proxy

# 查看CPU使用
top -p $(pgrep -f ipv6proxy)

# 查看网络流量
iftop -i he-ipv6
\`\`\`

### 定期维护

创建维护脚本：

\`\`\`bash
# 创建维护脚本
cat > /etc/cron.daily/ipv6proxy-maintenance << 'EOF'
#!/bin/bash
# 重启服务以清理连接
systemctl restart ipv6proxy
# 清理日志
journalctl --vacuum-time=7d
# 检查隧道状态
if ! ping6 -c 1 -I he-ipv6 2001:470:1f04:17b::1 &>/dev/null; then
    # 隧道异常，尝试重启
    ip link set he-ipv6 down
    ip link set he-ipv6 up
fi
EOF

chmod +x /etc/cron.daily/ipv6proxy-maintenance
\`\`\`

## 🔒 安全建议

### 基本安全

1. **启用认证**: 设置用户名密码保护代理服务
2. **防火墙配置**: 只开放必要的端口
3. **定期更新**: 保持系统和软件更新
4. **日志监控**: 定期检查访问日志

### 防火墙配置

\`\`\`bash
# 允许代理端口
sudo ufw allow 100/tcp
sudo ufw allow 101/tcp

# 允许SSH
sudo ufw allow 22/tcp

# 启用防火墙
sudo ufw enable
\`\`\`

### 访问控制

\`\`\`bash
# 限制特定IP访问
iptables -A INPUT -p tcp --dport 100 -s 允许的IP -j ACCEPT
iptables -A INPUT -p tcp --dport 100 -j DROP
\`\`\`

## 📝 更新日志

### v1.0.0
- 初始版本发布
- 支持随机IPv6代理
- 支持单IPv4代理
- HE IPv6隧道配置

### v1.1.0
- 新增多IPv4代理支持
- 改进安装脚本
- 优化系统配置
- 增强错误处理

### v1.2.0
- 改进用户界面
- 增加颜色输出
- 优化网络检测
- 完善文档

## 🤝 贡献指南

欢迎提交Issue和Pull Request！

### 开发环境

\`\`\`bash
# 克隆项目
git clone https://github.com/qza1314526-debug/v6-ee.git
cd v6-ee

# 安装依赖
go mod tidy

# 运行测试
go test ./...

# 构建项目
go build -o ipv6proxy cmd/ipv6proxy/main.go
\`\`\`

### 提交规范

- 使用清晰的提交信息
- 遵循Go代码规范
- 添加必要的测试
- 更新相关文档

## 📄 许可证

本项目采用MIT许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🆘 支持

如果您遇到问题，请：

1. 查看本文档的故障排除部分
2. 搜索已有的 [Issues](https://github.com/qza1314526-debug/v6-ee/issues)
3. 创建新的Issue并提供详细信息

## 📞 联系方式

- **GitHub**: [qza1314526-debug](https://github.com/qza1314526-debug)
- **Email**: support@example.com
- **文档**: [项目Wiki](https://github.com/qza1314526-debug/v6-ee/wiki)

---

**⚠️ 免责声明**: 请遵守当地法律法规，合理使用代理服务。本项目仅供学习和研究使用。

**🌟 如果这个项目对您有帮助，请给个Star支持一下！**
