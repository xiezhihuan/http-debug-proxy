# HTTP Debug Proxy - 实时HTTP请求调试代理

[![Go Version](https://img.shields.io/badge/Go-1.21+-blue.svg)](https://golang.org/)
[![Flutter Version](https://img.shields.io/badge/Flutter-3.0+-blue.svg)](https://flutter.dev/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

一个强大的HTTP调试代理工具，专为Android应用和API服务调试而设计。提供实时Web界面查看所有HTTP请求和响应，支持JSON格式化、搜索、编辑等功能。

## 🌟 功能特性

### 🔍 实时监控
- **实时WebSocket更新**：所有HTTP请求实时推送到Web界面
- **请求拦截**：拦截Android应用发送的所有HTTP请求
- **响应捕获**：完整捕获API服务的响应数据
- **时间戳记录**：精确记录请求时间和耗时

### 🎨 强大的Web界面
- **Flutter Web构建**：现代化、响应式的Web界面
- **JSON编辑器**：支持JSON格式化、搜索、编辑、复制
- **请求分组**：按时间、状态码、方法等分组显示
- **过滤搜索**：支持URL、方法、状态码过滤
- **实时统计**：显示请求总数、成功率等统计信息

### 🔧 调试功能
- **请求重放**：重新发送历史请求
- **响应模拟**：模拟不同的响应数据
- **请求统计**：详细的请求性能分析
- **数据导出**：支持JSON/CSV格式导出

### ⚙️ 配置管理
- **灵活配置**：支持配置文件和环境变量
- **端口配置**：可配置代理端口和Web界面端口
- **过滤规则**：支持忽略特定路径的请求
- **数据持久化**：本地文件存储历史记录

## 🚀 快速开始

### 环境要求

- **Go 1.21+**
- **Flutter 3.0+**
- **Node.js 16+** (可选，用于开发)

### 安装部署

#### 1. 克隆项目

```bash
git clone https://github.com/your-username/http-debug-proxy.git
cd http-debug-proxy
```

#### 2. 构建Go代理服务

```bash
cd go-proxy
go mod tidy
go build -o debug-proxy main.go
```

#### 3. 构建Flutter Web界面

```bash
cd flutter-web
flutter pub get
flutter build web
cp -r build/web/* ../go-proxy/web/static/
```

#### 4. 启动服务

```bash
cd go-proxy
./debug-proxy -target http://localhost:8081 -proxy-port 8090 -web-port 8091
```

### 使用Docker部署

#### 快速启动（推荐）

使用预构建的Docker镜像：

```bash
# 基本启动
docker run -d \
  --name http-debug-proxy \
  -p 8080:8080 \
  -p 8091:8091 \
  -e TARGET_URL="http://192.168.100.94:8079" \
  -e PROXY_PORT=8080 \
  -e WEB_PORT=8091 \
  -e MAX_LOGS=1000 \
  -v $(pwd)/logs:/app/logs \
  --restart unless-stopped \
  602666178/http-proxy-debug-view
```

#### 参数说明

| 参数 | 说明 | 示例值 |
|------|------|--------|
| `--name` | 容器名称 | `http-debug-proxy` |
| `-p 8080:8080` | 代理端口映射 | 外部8080映射到容器8080 |
| `-p 8091:8091` | Web界面端口映射 | 外部8091映射到容器8091 |
| `-e TARGET_URL` | 目标API服务器地址 | `http://192.168.100.220:8081` |
| `-e PROXY_PORT` | 代理端口 | `8080` |
| `-e WEB_PORT` | Web界面端口 | `8091` |
| `-e MAX_LOGS` | 最大日志数量 | `1000` |
| `-v $(pwd)/logs:/app/logs` | 日志目录挂载 | 持久化日志数据 |
| `--restart unless-stopped` | 重启策略 | 容器异常退出时自动重启 |

#### 自定义构建

如果需要自定义构建：

```bash
# 构建Docker镜像
docker build -t http-debug-proxy .

# 运行自定义镜像
docker run -d \
  --name http-debug-proxy \
  -p 8080:8080 \
  -p 8091:8091 \
  -e TARGET_URL="http://your-api-server:8081" \
  -e PROXY_PORT=8080 \
  -e WEB_PORT=8091 \
  -e MAX_LOGS=1000 \
  -v $(pwd)/logs:/app/logs \
  --restart unless-stopped \
  http-debug-proxy
```

## 📖 使用指南

### 1. 配置Android应用代理

在Android应用中配置HTTP代理：

```java
// Android代码示例
Proxy proxy = new Proxy(Proxy.Type.HTTP, 
    new InetSocketAddress("your-proxy-server", 8090));
```

或者使用OkHttp：

```java
OkHttpClient client = new OkHttpClient.Builder()
    .proxy(new Proxy(Proxy.Type.HTTP, 
        new InetSocketAddress("your-proxy-server", 8090)))
    .build();
```

### 2. 访问Web界面

打开浏览器访问：`http://localhost:8091`

### 3. 查看请求数据

- **实时监控**：所有HTTP请求会实时显示在列表中
- **详细信息**：点击请求查看完整的请求和响应详情
- **JSON编辑**：响应体中的JSON数据支持格式化、搜索、编辑
- **过滤搜索**：使用过滤栏按条件筛选请求

## 🔌 API接口

### WebSocket接口

**连接地址**：`ws://localhost:8091/api/ws`

**消息格式**：
```json
{
  "type": "new_log",
  "data": {
    "id": "uuid",
    "timestamp": "2024-01-01T12:00:00Z",
    "method": "POST",
    "url": "http://api.example.com/users",
    "request_headers": {},
    "request_body": "{}",
    "response_headers": {},
    "response_body": "{}",
    "status_code": 200,
    "duration": 150
  }
}
```

### REST API接口

#### 获取日志列表
```http
GET /api/logs
```

**查询参数**：
- `url`：按URL过滤
- `method`：按HTTP方法过滤
- `status_code`：按状态码过滤

#### 清除日志
```http
POST /api/logs/clear
```

## 🛠️ 开发指南

### 项目结构

```
http-debug-proxy/
├── go-proxy/                 # Go代理服务
│   ├── main.go              # 主程序入口
│   ├── proxy/               # 代理核心逻辑
│   │   ├── proxy.go         # HTTP代理实现
│   │   └── websocket.go     # WebSocket服务
│   ├── models/              # 数据模型
│   │   └── http_log.go      # HTTP日志模型
│   └── web/static/          # Web静态文件
├── flutter-web/             # Flutter Web界面
│   ├── lib/                 # Dart源代码
│   │   ├── main.dart        # 主程序
│   │   ├── models/          # 数据模型
│   │   ├── services/        # 服务层
│   │   └── widgets/         # UI组件
│   └── pubspec.yaml         # 依赖配置
├── docs/                    # 文档
├── examples/                # 示例代码
└── docker/                  # Docker配置
```

### 添加新功能

#### 1. 扩展Go后端

```go
// 在proxy.go中添加新的API端点
func (p *ProxyServer) handleNewFeature(w http.ResponseWriter, r *http.Request) {
    // 实现新功能
}
```

#### 2. 扩展Flutter前端

```dart
// 在services/中添加新的服务
class NewFeatureService {
  Future<void> callNewAPI() async {
    // 调用新的API
  }
}
```

### 自定义配置

创建配置文件 `config.json`：

```json
{
  "target_url": "http://localhost:8081",
  "proxy_port": 8090,
  "web_port": 8091,
  "max_logs": 1000,
  "ignore_paths": ["/health", "/metrics"],
  "enable_https": false,
  "log_level": "info"
}
```

## 🐳 Docker部署

### Dockerfile

```dockerfile
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go-proxy/ .
RUN go mod download
RUN go build -o debug-proxy main.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/debug-proxy .
COPY go-proxy/web/static/ ./web/static/
EXPOSE 8090 8091
CMD ["./debug-proxy"]
```

### Docker Compose

创建 `docker-compose.yml` 文件：

```yaml
version: '3.8'
services:
  http-debug-proxy:
    image: 602666178/http-proxy-debug-view
    container_name: http-debug-proxy
    ports:
      - "8080:8080"
      - "8091:8091"
    environment:
      - TARGET_URL=http://192.168.100.220:8081
      - PROXY_PORT=8080
      - WEB_PORT=8091
      - MAX_LOGS=1000
    volumes:
      - ./logs:/app/logs
    restart: unless-stopped
```

启动服务：

```bash
# 启动服务
docker-compose up -d

# 查看日志
docker-compose logs -f

# 停止服务
docker-compose down
```

## 🔧 配置选项

### 命令行参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `-target` | `http://localhost:8081` | 目标API服务器地址 |
| `-proxy-port` | `8090` | 代理服务端口 |
| `-web-port` | `8091` | Web界面端口 |
| `-max-logs` | `1000` | 最大日志数量 |
| `-config` | `config.json` | 配置文件路径 |

### 环境变量

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `TARGET_URL` | `http://localhost:8081` | 目标API服务器地址 |
| `PROXY_PORT` | `8090` | 代理服务端口 |
| `WEB_PORT` | `8091` | Web界面端口 |
| `MAX_LOGS` | `1000` | 最大日志数量 |

## 📊 性能优化

### 内存管理
- 自动清理过期日志
- 限制最大日志数量
- 定期垃圾回收

### 网络优化
- WebSocket连接复用
- 请求压缩
- 缓存静态资源

## 🔒 安全考虑

### 生产环境部署
- 启用HTTPS
- 配置访问控制
- 限制代理访问
- 日志脱敏

### 安全配置示例

```json
{
  "enable_auth": true,
  "allowed_ips": ["192.168.1.0/24"],
  "enable_https": true,
  "ssl_cert": "/path/to/cert.pem",
  "ssl_key": "/path/to/key.pem"
}
```

## 🤝 贡献指南

### 提交Issue
1. 使用Issue模板
2. 提供详细的复现步骤
3. 包含错误日志和截图

### 提交PR
1. Fork项目
2. 创建功能分支
3. 提交代码变更
4. 创建Pull Request

### 代码规范
- Go代码遵循gofmt规范
- Dart代码遵循dart format规范
- 添加必要的注释和文档

## 📄 许可证

本项目采用 [MIT License](LICENSE) 许可证。

## 🙏 致谢

感谢以下开源项目的支持：
- [Gorilla WebSocket](https://github.com/gorilla/websocket)
- [Flutter](https://flutter.dev/)
- [json_editor_flutter](https://pub.dev/packages/json_editor_flutter)

## 📞 联系方式

- **项目地址**：https://github.com/your-username/http-debug-proxy
- **问题反馈**：https://github.com/your-username/http-debug-proxy/issues
- **邮箱**：your-email@example.com

---

⭐ 如果这个项目对您有帮助，请给我们一个Star！ 