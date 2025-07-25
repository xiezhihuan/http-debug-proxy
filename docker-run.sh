#!/bin/bash

# HTTP调试代理快速启动脚本
# 使用Docker镜像: 602666178/http-proxy-debug-view:latest

echo "🚀 启动HTTP调试代理服务..."
echo "================================"

# 默认配置
TARGET_URL=${TARGET_URL:-"http://192.168.100.220:8081"}
PROXY_PORT=${PROXY_PORT:-"8080"}
WEB_PORT=${WEB_PORT:-"8091"}
MAX_LOGS=${MAX_LOGS:-"1000"}

echo "📋 配置信息:"
echo "  目标API服务器: $TARGET_URL"
echo "  代理端口: $PROXY_PORT"
echo "  Web界面端口: $WEB_PORT"
echo "  最大日志数: $MAX_LOGS"
echo "================================"

# 检查端口是否被占用
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo "❌ 错误: 端口 $port 已被占用"
        echo "请停止占用端口的服务或修改端口配置"
        exit 1
    fi
}

echo "🔍 检查端口占用情况..."
check_port $PROXY_PORT
check_port $WEB_PORT

echo "✅ 端口检查通过"

# 创建日志目录
mkdir -p ./logs

echo "🐳 启动Docker容器..."

# 停止并删除已存在的容器
docker stop http-debug-proxy 2>/dev/null || true
docker rm http-debug-proxy 2>/dev/null || true

# 启动新容器
# docker run -d \
#   --name http-debug-proxy \
#   -p $PROXY_PORT:8090 \
#   -p $WEB_PORT:8091 \
#   -e TARGET_URL="$TARGET_URL" \
#   -e PROXY_PORT=8090 \
#   -e WEB_PORT=8091 \
#   -e MAX_LOGS="$MAX_LOGS" \
#   -v $(pwd)/logs:/app/logs \
#   --restart unless-stopped \
#   602666178/http-proxy-debug-view:latest

docker run -d \
  --name http-debug-proxy \
  -p 8080:8080 \
  -p 8091:8091 \
  -e TARGET_URL="http://192.168.100.220:8081" \
  -e PROXY_PORT=8080 \
  -e WEB_PORT=8091 \
  -e MAX_LOGS="$MAX_LOGS" \
  -v $(pwd)/logs:/app/logs \
  --restart unless-stopped \
  602666178/http-proxy-debug-view:latest

if [ $? -eq 0 ]; then
    echo "✅ 容器启动成功!"
    echo ""
    echo "🌐 访问地址:"
    echo "  Web调试界面: http://localhost:$WEB_PORT"
    echo "  代理服务地址: http://localhost:$PROXY_PORT"
    echo ""
    echo "📱 Android应用配置:"
    echo "  代理服务器: localhost (或您的服务器IP)"
    echo "  代理端口: $PROXY_PORT"
    echo ""
    echo "📋 常用命令:"
    echo "  查看日志: docker logs -f http-debug-proxy"
    echo "  停止服务: docker stop http-debug-proxy"
    echo "  删除容器: docker rm http-debug-proxy"
    echo ""
    echo "⏳ 等待服务启动完成..."
    sleep 3
    
    # 检查服务是否正常启动
    if curl -s http://localhost:$WEB_PORT >/dev/null 2>&1; then
        echo "🎉 服务启动完成！现在可以访问 http://localhost:$WEB_PORT"
    else
        echo "⚠️  服务可能还在启动中，请稍等片刻再访问"
    fi
else
    echo "❌ 容器启动失败!"
    echo "请检查Docker是否正常运行，或查看错误信息"
    exit 1
fi 