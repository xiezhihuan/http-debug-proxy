#!/bin/bash

# HTTP调试代理服务启动脚本
echo "🚀 启动HTTP调试代理服务..."

# 检查参数
TARGET_URL=${1:-"http://localhost:8081"}
PROXY_PORT=${2:-"8080"}
WEB_PORT=${3:-"8091"}

echo "📋 配置信息:"
echo "   目标API服务: $TARGET_URL"
echo "   代理端口:   $PROXY_PORT"
echo "   Web界面:    http://localhost:$WEB_PORT"
echo ""

# 进入go-proxy目录
cd go-proxy

# 检查是否已编译
if [ ! -f "debug-proxy" ]; then
    echo "📦 编译Go代理服务..."
    go build -o debug-proxy main.go
    if [ $? -ne 0 ]; then
        echo "❌ 编译失败"
        exit 1
    fi
fi

echo "✅ 启动代理服务..."
echo "💡 使用说明："
echo "   1. 配置Android应用使用代理: localhost:$PROXY_PORT"
echo "   2. 打开浏览器访问: http://localhost:$WEB_PORT"
echo "   3. 按 Ctrl+C 停止服务"
echo ""

# 启动服务
./debug-proxy --target="$TARGET_URL" --proxy-port="$PROXY_PORT" --web-port="$WEB_PORT" 