# HTTP调试代理服务 - Debug View

一个用于Android应用开发的HTTP请求调试工具，可以实时查看Android应用与后端API服务之间的所有HTTP请求和响应数据。

## 项目架构

```
Android App → Go代理服务 → Go API服务
             ↓
        Flutter Web界面
       (实时显示请求/响应)
```

## 功能特点

- ✅ **HTTP代理功能**：透明代理Android应用的HTTP请求
- ✅ **实时监控**：WebSocket实时推送新的请求数据
- ✅ **详细信息**：查看完整的请求头、请求体、响应头、响应体
- ✅ **搜索过滤**：支持URL关键词、HTTP方法、状态码过滤
- ✅ **现代界面**：Flutter Web实现的美观调试界面
- ✅ **数据管理**：支持清除日志，内存管理
- ✅ **状态显示**：实时连接状态，请求统计信息

## 项目结构

```
debug-view/
├── go-proxy/                 # Go代理服务
│   ├── main.go              # 主程序入口
│   ├── models/              # 数据模型
│   │   └── http_log.go      # HTTP日志结构
│   ├── proxy/               # 代理核心功能
│   │   ├── proxy.go         # HTTP代理实现
│   │   └── websocket.go     # WebSocket服务
│   ├── web/static/          # Flutter Web静态文件
│   └── go.mod               # Go模块依赖
├── flutter-web/             # Flutter Web项目
│   ├── lib/
│   │   ├── main.dart        # 主应用
│   │   ├── models/          # 数据模型
│   │   ├── services/        # 服务层
│   │   └── widgets/         # UI组件
│   └── pubspec.yaml         # Flutter依赖
└── README.md                # 项目说明
```

## 安装和使用

### 1. 环境要求

- Go 1.21+
- Flutter 3.0+
- Dart 3.0+

### 2. 启动代理服务

```bash
cd go-proxy
go mod tidy
go run main.go --target=http://localhost:8080 --proxy-port=8090 --web-port=8091
```

**参数说明：**
- `--target`: 目标API服务地址 (默认: http://localhost:8080)
- `--proxy-port`: 代理服务端口 (默认: 8090)
- `--web-port`: Web界面端口 (默认: 8091)
- `--max-logs`: 最大日志数量 (默认: 1000)

### 3. 配置Android应用

在Android应用中配置HTTP代理：

#### 方法1：代码配置 (推荐)
```kotlin
// 在Application或网络配置中添加
val proxy = Proxy(Proxy.Type.HTTP, InetSocketAddress("localhost", 8090))

// 使用OkHttp
val client = OkHttpClient.Builder()
    .proxy(proxy)
    .build()

// 使用Retrofit
val retrofit = Retrofit.Builder()
    .baseUrl("http://your-api-base-url/")
    .client(client)
    .build()
```

#### 方法2：模拟器网络配置
```bash
# 启动模拟器时配置代理
emulator -avd your_avd -http-proxy localhost:8090
```

### 4. 访问调试界面

打开浏览器访问：`http://localhost:8091`

## 使用说明

### 界面功能

1. **过滤栏**
   - URL过滤：输入关键词过滤特定URL
   - HTTP方法：选择GET、POST、PUT等方法
   - 状态码：过滤特定状态码的请求
   - 连接状态：显示WebSocket连接状态

2. **请求列表**
   - 实时显示所有HTTP请求
   - 显示方法、URL、状态码、耗时
   - 点击查看详细信息

3. **详情面板**
   - 基本信息：方法、URL、状态码、耗时等
   - 请求信息：请求头、请求体
   - 响应信息：响应头、响应体
   - 支持复制到剪贴板

4. **工具功能**
   - 清除过滤条件
   - 清除所有日志
   - 刷新日志列表

### 开发调试流程

1. 启动Go API服务（端口8080）
2. 启动代理服务（端口8090、8091）
3. 配置Android应用使用代理
4. 在Web界面查看实时请求数据
5. 根据请求响应信息调试API接口

## 开发说明

### 重新构建Flutter Web

```bash
cd flutter-web
flutter build web
cd ..
cp -r flutter-web/build/web/* go-proxy/web/static/
```

### 添加新功能

1. **Go后端**：在`go-proxy/proxy/`目录添加新的处理逻辑
2. **Flutter前端**：在`flutter-web/lib/`目录添加新的UI组件
3. **数据模型**：在两端的`models/`目录同步更新数据结构

## 故障排除

### 常见问题

1. **代理连接失败**
   - 检查目标API服务是否运行
   - 确认端口没有被占用
   - 检查防火墙设置

2. **WebSocket连接失败**
   - 确认Web服务端口（8091）可访问
   - 检查浏览器控制台错误信息
   - 尝试刷新页面重新连接

3. **Android代理不生效**
   - 确认代理配置正确
   - 检查网络权限
   - 尝试使用IP地址替代localhost

### 调试模式

启用详细日志：
```bash
go run main.go --target=http://localhost:8080 -v
```

## 技术栈

- **后端**: Go + Gorilla WebSocket + HTTP Proxy
- **前端**: Flutter Web + WebSocket Client
- **通信**: WebSocket (实时) + REST API (历史数据)

## 许可证

MIT License

## 贡献

欢迎提交Issue和Pull Request来改进这个项目。 