# 多阶段构建
FROM golang:1.21-alpine AS builder

# 设置工作目录
WORKDIR /app

# 安装必要的包
RUN apk add --no-cache git ca-certificates tzdata

# 复制go mod文件
COPY go.mod go.sum ./

# 下载依赖
RUN go mod download

# 复制源代码
COPY . .

# 构建应用
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags '-extldflags "-static"' -o ipv6proxy cmd/ipv6proxy/main.go

# 运行阶段
FROM alpine:latest

# 安装运行时依赖
RUN apk --no-cache add ca-certificates curl iproute2 iptables

# 创建非root用户
RUN addgroup -g 1001 -S ipv6proxy && \
    adduser -u 1001 -S ipv6proxy -G ipv6proxy

# 设置工作目录
WORKDIR /app

# 从构建阶段复制二进制文件
COPY --from=builder /app/ipv6proxy .
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# 复制启动脚本
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# 创建日志目录
RUN mkdir -p /var/log/ipv6proxy && \
    chown -R ipv6proxy:ipv6proxy /var/log/ipv6proxy

# 暴露端口
EXPOSE 100 101

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:${REAL_IPV4_PORT:-101}/health || exit 1

# 设置入口点
ENTRYPOINT ["docker-entrypoint.sh"]

# 默认命令
CMD ["./ipv6proxy"]
