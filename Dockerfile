# 多阶段构建 - 构建阶段
FROM golang:1.21-alpine AS builder

# 设置工作目录
WORKDIR /app

# 安装必要的工具
RUN apk add --no-cache git ca-certificates tzdata

# 复制Go模块文件
COPY go-proxy/go.mod go-proxy/go.sum ./

# 下载依赖
RUN go mod download

# 复制源代码
COPY go-proxy/ .

# 构建Go应用
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o debug-proxy main.go

# 运行阶段
FROM alpine:latest

# 安装必要的包
RUN apk --no-cache add ca-certificates tzdata

# 设置时区
ENV TZ=Asia/Shanghai

# 创建非root用户
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

# 设置工作目录
WORKDIR /app

# 从构建阶段复制二进制文件
COPY --from=builder /app/debug-proxy .

# 复制静态文件
COPY go-proxy/web/static/ ./web/static/

# 复制Docker启动脚本并设置可执行权限
COPY docker-start.sh ./
RUN chmod +x docker-start.sh

# 创建日志目录
RUN mkdir -p /app/logs && chown -R appuser:appgroup /app

# 切换到非root用户
USER appuser

# 暴露端口
EXPOSE 8090 8091

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8091/ || exit 1

# 设置环境变量
ENV TARGET_URL=http://localhost:8081
ENV PROXY_PORT=8090
ENV WEB_PORT=8091
ENV MAX_LOGS=1000

# 启动命令 - 使用Docker专用启动脚本
CMD ["./docker-start.sh"] 