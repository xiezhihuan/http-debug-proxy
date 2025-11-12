#!/bin/sh

# Docker容器启动脚本
echo "🚀 启动HTTP调试代理服务 (Docker模式)..."

# 使用环境变量或默认值
TARGET_URL=${TARGET_URL:-"http://localhost:8081"}
PROXY_PORT=${PROXY_PORT:-"8090"}
WEB_PORT=${WEB_PORT:-"8091"}
MAX_LOGS=${MAX_LOGS:-"1000"}

echo "📋 配置信息:"
echo "   目标API服务: $TARGET_URL"
echo "   代理端口:   $PROXY_PORT"
echo "   Web界面:    http://localhost:$WEB_PORT"
echo "   最大日志数: $MAX_LOGS"
echo ""

echo "✅ 启动代理服务..."
echo "💡 使用说明："
echo "   1. 配置Android应用使用代理: container_ip:$PROXY_PORT"
echo "   2. 打开浏览器访问: http://localhost:$WEB_PORT"
echo "   3. 发送SIGTERM信号停止服务"
echo ""

# 启动服务，支持信号处理
exec ./debug-proxy --target="$TARGET_URL" --proxy-port="$PROXY_PORT" --web-port="$WEB_PORT" --max-logs="$MAX_LOGS" 