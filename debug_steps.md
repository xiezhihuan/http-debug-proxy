# HTTP调试代理服务 - 故障排除指南

## 🚀 快速测试

### 1. 检查服务状态
```bash
# 检查代理服务是否运行
ps aux | grep debug-proxy

# 检查端口监听
netstat -an | grep 8091
```

### 2. 访问测试页面
打开浏览器访问：`http://localhost:8091/test.html`

如果看到绿色的"Web服务器状态：正常"，说明Go服务器正常工作。

### 3. 访问主界面
打开浏览器访问：`http://localhost:8091`

## 🔧 如果主界面显示空白

### 步骤1：检查浏览器控制台
1. 按 `F12` 打开开发者工具
2. 切换到 `Console` 标签
3. 刷新页面（Ctrl+F5 或 Cmd+R）
4. 查看是否有红色错误信息

### 步骤2：检查网络请求
1. 在开发者工具中切换到 `Network` 标签
2. 刷新页面
3. 检查是否有失败的请求（红色状态）
4. 特别注意 `main.dart.js` 是否加载成功

### 步骤3：常见问题和解决方案

#### ❌ 问题：WebSocket连接失败
**现象**：界面显示"未连接"状态
**解决**：
- 检查Go服务是否正常运行
- 确认端口8091可访问
- 尝试重启浏览器

#### ❌ 问题：JavaScript加载失败
**现象**：控制台显示404错误或CORS错误
**解决**：
```bash
# 重新构建Flutter Web
cd flutter-web
flutter clean
flutter build web
cd ..
cp -r flutter-web/build/web/* go-proxy/web/static/
```

#### ❌ 问题：界面显示但功能异常
**现象**：页面加载但按钮无响应
**解决**：
- 检查浏览器是否禁用了JavaScript
- 尝试无痕浏览模式
- 清除浏览器缓存

### 步骤4：手动测试API
```bash
# 测试日志API
curl http://localhost:8091/api/logs

# 测试清除API
curl -X POST http://localhost:8091/api/logs/clear

# 测试WebSocket连接
# 可以使用在线WebSocket测试工具连接到 ws://localhost:8091/api/ws
```

## 🆘 仍然无法解决？

### 收集调试信息
1. 浏览器控制台的完整错误信息
2. 网络请求失败的详细信息
3. Go服务器的日志输出

### 替代方案
如果Flutter Web界面仍然有问题，可以直接使用API测试：

```bash
# 查看当前日志
curl http://localhost:8091/api/logs | jq

# 配置Android应用代理到 localhost:8080
# 然后发送一些HTTP请求

# 再次查看日志，应该能看到新的请求记录
curl http://localhost:8091/api/logs | jq
```

## 📞 技术支持
如果问题仍然存在，请提供：
1. 浏览器类型和版本
2. 操作系统版本
3. 控制台错误信息截图
4. Go服务器启动日志 