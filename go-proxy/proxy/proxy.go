package proxy

import (
	"bytes"
	"crypto/tls"
	"debug-view/models"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"compress/flate"
	"compress/gzip"

	"github.com/andybalholm/brotli"
	"github.com/google/uuid"
)

// TargetServer represents a target server with health status
type TargetServer struct {
	URL       string
	IsHealthy bool
	LastCheck time.Time
}

// ProxyServer represents the HTTP proxy server
type ProxyServer struct {
	targetURLs          []*TargetServer
	currentIndex        int
	logs                []models.HTTPLog
	mutex               sync.RWMutex
	maxLogs             int
	wsHub               *WebSocketHub
	isListening         bool
	healthCheckInterval time.Duration
}

// NewProxyServer creates a new proxy server instance
func NewProxyServer(targetURLs []string, maxLogs int) *ProxyServer {
	servers := make([]*TargetServer, 0, len(targetURLs))
	for _, url := range targetURLs {
		url = strings.TrimSpace(url)
		if url != "" {
			servers = append(servers, &TargetServer{
				URL:       url,
				IsHealthy: true, // 初始假设健康
				LastCheck: time.Now(),
			})
		}
	}

	if len(servers) == 0 {
		// 如果没有提供 URL，使用默认值
		servers = append(servers, &TargetServer{
			URL:       "http://localhost:8080",
			IsHealthy: true,
			LastCheck: time.Now(),
		})
	}

	ps := &ProxyServer{
		targetURLs:          servers,
		currentIndex:        0,
		logs:                make([]models.HTTPLog, 0),
		maxLogs:             maxLogs,
		wsHub:               NewWebSocketHub(),
		isListening:         true,            // 默认开启监听
		healthCheckInterval: 5 * time.Second, // 每5秒检查一次
	}

	// 启动健康检查
	go ps.startHealthCheck()

	// 立即执行一次健康检查（不等待第一个 ticker）
	go func() {
		time.Sleep(1 * time.Second) // 等待 1 秒让服务器启动
		ps.mutex.RLock()
		servers := make([]*TargetServer, len(ps.targetURLs))
		for i, s := range ps.targetURLs {
			servers[i] = &TargetServer{
				URL:       s.URL,
				IsHealthy: s.IsHealthy,
				LastCheck: s.LastCheck,
			}
		}
		ps.mutex.RUnlock()

		for i, server := range servers {
			wasHealthy := server.IsHealthy
			server.IsHealthy = ps.checkHealth(server)
			server.LastCheck = time.Now()

			ps.mutex.Lock()
			ps.targetURLs[i].IsHealthy = server.IsHealthy
			ps.targetURLs[i].LastCheck = server.LastCheck
			if wasHealthy != server.IsHealthy && server.IsHealthy {
				log.Printf("✅ 目标服务器健康检查通过: %s", server.URL)
			}
			ps.mutex.Unlock()
		}
	}()

	return ps
}

// Start starts the proxy server
func (p *ProxyServer) Start(proxyPort, webPort string) error {
	// Start WebSocket hub
	go p.wsHub.Run()

	// Setup HTTP handlers
	mux := http.NewServeMux()

	// Proxy handler - handles all requests to be proxied
	mux.HandleFunc("/proxy/", p.handleProxy)

	// API handlers for web interface
	mux.HandleFunc("/api/logs", p.handleGetLogs)
	mux.HandleFunc("/api/logs/clear", p.handleClearLogs)
	mux.HandleFunc("/api/listening/start", p.handleStartListening)
	mux.HandleFunc("/api/listening/stop", p.handleStopListening)
	mux.HandleFunc("/api/listening/status", p.handleListeningStatus)
	mux.HandleFunc("/api/replay", p.handleReplayRequest)
	mux.HandleFunc("/api/targets", p.handleGetTargets)
	mux.HandleFunc("/api/ws", p.wsHub.HandleWebSocket)

	// Static file handler for Flutter web
	mux.Handle("/", http.FileServer(http.Dir("./web/static/")))

	log.Printf("Proxy server starting on port %s", proxyPort)
	log.Printf("Target servers (%d):", len(p.targetURLs))
	for i, server := range p.targetURLs {
		status := "✓"
		if !server.IsHealthy {
			status = "✗"
		}
		log.Printf("  [%d] %s %s", i+1, status, server.URL)
	}
	log.Printf("Current active target: %s", p.getCurrentTarget().URL)
	log.Printf("Web interface available on port %s", webPort)

	// Start web interface server
	go func() {
		webServer := &http.Server{
			Addr:    ":" + webPort,
			Handler: p.corsMiddleware(mux),
		}
		log.Fatal(webServer.ListenAndServe())
	}()

	// Start proxy server
	proxyServer := &http.Server{
		Addr:    ":" + proxyPort,
		Handler: http.HandlerFunc(p.handleProxyRoot),
	}

	return proxyServer.ListenAndServe()
}

// decompressResponseBody 解压缩响应体
func decompressResponseBody(body []byte, headers http.Header) ([]byte, error) {
	contentEncoding := headers.Get("Content-Encoding")
	if contentEncoding == "" {
		return body, nil // 无需解压
	}

	var uncompressedBody []byte
	var err error

	switch contentEncoding {
	case "gzip":
		uncompressedBody, err = decompressGzip(body)
	case "deflate":
		uncompressedBody, err = decompressDeflate(body)
	case "br":
		uncompressedBody, err = decompressBrotli(body)
	case "gzip, deflate":
		// 处理多重编码，先解压 gzip，再解压 deflate
		uncompressedBody, err = decompressGzip(body)
		if err == nil {
			uncompressedBody, err = decompressDeflate(uncompressedBody)
		}
	default:
		log.Printf("Unsupported content encoding: %s", contentEncoding)
		return body, nil
	}

	if err != nil {
		return body, fmt.Errorf("failed to decompress %s: %v", contentEncoding, err)
	}

	// 解压成功，移除 Content-Encoding 头
	headers.Del("Content-Encoding")

	// 更新 Content-Length 头（如果存在）
	if headers.Get("Content-Length") != "" {
		headers.Set("Content-Length", strconv.Itoa(len(uncompressedBody)))
	}

	log.Printf("Successfully decompressed %s response: %d -> %d bytes", contentEncoding, len(body), len(uncompressedBody))
	return uncompressedBody, nil
}

// decompressGzip 解压 gzip 内容
func decompressGzip(data []byte) ([]byte, error) {
	reader, err := gzip.NewReader(bytes.NewReader(data))
	if err != nil {
		return nil, err
	}
	defer reader.Close()

	return io.ReadAll(reader)
}

// decompressDeflate 解压 deflate 内容
func decompressDeflate(data []byte) ([]byte, error) {
	reader := flate.NewReader(bytes.NewReader(data))
	defer reader.Close()

	return io.ReadAll(reader)
}

// decompressBrotli 解压 brotli 内容
func decompressBrotli(data []byte) ([]byte, error) {
	reader := brotli.NewReader(bytes.NewReader(data))
	return io.ReadAll(reader)
}

// handleReplayRequest 处理请求重放
func (p *ProxyServer) handleReplayRequest(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// 解析重放请求参数
	var replayReq struct {
		OriginalLogID string            `json:"original_log_id"`
		Method        string            `json:"method"`
		URL           string            `json:"url"`
		Headers       map[string]string `json:"headers"`
		Body          string            `json:"body"`
	}

	if err := json.NewDecoder(r.Body).Decode(&replayReq); err != nil {
		log.Printf("Failed to decode replay request: %v", err)
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	// 验证必要参数
	if replayReq.URL == "" {
		log.Printf("Replay request failed: URL is empty")
		http.Error(w, "URL is required", http.StatusBadRequest)
		return
	}

	// 处理URL协议问题
	finalURL := replayReq.URL
	if !strings.HasPrefix(finalURL, "http://") && !strings.HasPrefix(finalURL, "https://") {
		// 如果没有协议前缀，自动添加代理服务器地址
		currentTarget := p.getCurrentTarget()
		if currentTarget == nil {
			http.Error(w, "No target server available", http.StatusServiceUnavailable)
			return
		}

		if strings.HasPrefix(finalURL, "/") {
			// 如果是绝对路径，添加代理服务器地址
			finalURL = currentTarget.URL + finalURL
		} else {
			// 如果是相对路径，添加代理服务器地址
			finalURL = currentTarget.URL + "/" + finalURL
		}
		log.Printf("🔧 自动添加协议前缀，URL: %s -> %s", replayReq.URL, finalURL)
	}

	// 添加调试日志
	log.Printf("🔄 开始重放请求:")
	log.Printf("   原始日志ID: %s", replayReq.OriginalLogID)
	log.Printf("   方法: %s", replayReq.Method)
	log.Printf("   原始URL: %s", replayReq.URL)
	log.Printf("   最终URL: %s", finalURL)
	log.Printf("   请求头数量: %d", len(replayReq.Headers))
	log.Printf("   请求体长度: %d bytes", len(replayReq.Body))

	// 创建重放请求
	startTime := time.Now()
	logID := uuid.New().String()

	// 准备请求体
	var bodyReader io.Reader
	if replayReq.Body != "" {
		bodyReader = strings.NewReader(replayReq.Body)
	}

	// 创建 HTTP 请求
	req, err := http.NewRequest(replayReq.Method, finalURL, bodyReader)
	if err != nil {
		http.Error(w, "Failed to create request", http.StatusInternalServerError)
		return
	}

	// 设置请求头
	for key, value := range replayReq.Headers {
		req.Header.Set(key, value)
		log.Printf("   设置请求头: %s = %s", key, value)
	}

	// 发送请求
	log.Printf("🚀 发送重放请求到: %s", finalURL)
	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		log.Printf("❌ 重放请求失败: %v", err)
		http.Error(w, fmt.Sprintf("Failed to send request: %v", err), http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()

	log.Printf("✅ 重放请求成功，状态码: %d", resp.StatusCode)

	// 读取响应体
	responseBody, err := io.ReadAll(resp.Body)
	if err != nil {
		log.Printf("Failed to read response body: %v", err)
		http.Error(w, "Failed to read response body", http.StatusInternalServerError)
		return
	}

	log.Printf("📥 响应体大小: %d bytes", len(responseBody))

	// 解压缩响应体（如果需要）
	responseBody, err = decompressResponseBody(responseBody, resp.Header)
	if err != nil {
		log.Printf("Warning: Failed to decompress replay response body: %v", err)
	}

	// 记录重放请求
	duration := time.Since(startTime).Milliseconds()

	// 获取Content-Type
	requestContentType := req.Header.Get("Content-Type")
	responseContentType := resp.Header.Get("Content-Type")

	// 编码请求体和响应体
	encodedRequestBody, requestBodyType := models.EncodeBody([]byte(replayReq.Body), requestContentType)
	encodedResponseBody, responseBodyType := models.EncodeBody(responseBody, responseContentType)

	replayLog := models.HTTPLog{
		ID:               logID,
		Timestamp:        startTime,
		Method:           replayReq.Method,
		URL:              finalURL, // 使用处理后的URL
		RequestHeaders:   req.Header,
		RequestBody:      encodedRequestBody,
		RequestBodyType:  requestBodyType,
		ResponseHeaders:  resp.Header,
		ResponseBody:     encodedResponseBody,
		ResponseBodyType: responseBodyType,
		StatusCode:       resp.StatusCode,
		Duration:         duration,
	}

	// 添加重放日志
	p.addLog(replayLog)

	log.Printf("📝 重放日志已记录，ID: %s, 耗时: %dms", logID, duration)

	// 返回重放结果
	w.Header().Set("Content-Type", "application/json")
	result := map[string]interface{}{
		"success":     true,
		"log_id":      logID,
		"message":     "Request replayed successfully",
		"status_code": resp.StatusCode,
		"duration":    duration,
	}
	json.NewEncoder(w).Encode(result)
}

// getCurrentTarget returns the currently active target server
func (p *ProxyServer) getCurrentTarget() *TargetServer {
	p.mutex.RLock()
	defer p.mutex.RUnlock()

	if len(p.targetURLs) == 0 {
		return nil
	}

	// 确保索引有效
	if p.currentIndex >= len(p.targetURLs) {
		p.currentIndex = 0
	}

	return p.targetURLs[p.currentIndex]
}

// checkHealth checks if a target server is healthy
func (p *ProxyServer) checkHealth(server *TargetServer) bool {
	// 创建自定义 Transport，跳过 TLS 证书验证（开发环境）
	tr := &http.Transport{
		TLSClientConfig: &tls.Config{
			InsecureSkipVerify: true, // 跳过证书验证（仅开发环境）
		},
	}

	client := &http.Client{
		Timeout:   5 * time.Second,
		Transport: tr,
	}

	// 先尝试 HEAD 请求（更轻量）
	req, err := http.NewRequest("HEAD", server.URL, nil)
	if err != nil {
		return false
	}

	resp, err := client.Do(req)
	if err != nil {
		// HEAD 失败，尝试 GET 请求（某些服务器不支持 HEAD）
		req, err := http.NewRequest("GET", server.URL, nil)
		if err != nil {
			log.Printf("健康检查失败 [%s]: 创建请求失败: %v", server.URL, err)
			return false
		}
		resp, err = client.Do(req)
		if err != nil {
			log.Printf("健康检查失败 [%s]: 请求失败: %v", server.URL, err)
			return false
		}
		defer resp.Body.Close()
	} else {
		defer resp.Body.Close()
	}

	// 判断服务器是否健康
	// - 502 Bad Gateway 视为不健康（网关无法从上游获得有效响应）
	// - 其他状态码（包括 404/403）视为健康（说明服务器可达且可处理请求）
	// - 只有连接失败或超时才认为不健康
	isHealthy := resp.StatusCode > 0 && resp.StatusCode != 502
	return isHealthy
}

// switchToNextTarget switches to the next available healthy target
func (p *ProxyServer) switchToNextTarget() bool {
	p.mutex.Lock()
	defer p.mutex.Unlock()

	if len(p.targetURLs) == 0 {
		return false
	}

	// 从当前位置开始查找下一个健康的服务器
	startIndex := p.currentIndex
	for i := 0; i < len(p.targetURLs); i++ {
		nextIndex := (p.currentIndex + 1) % len(p.targetURLs)
		if p.targetURLs[nextIndex].IsHealthy {
			if p.currentIndex != nextIndex {
				log.Printf("🔄 切换到目标服务器: %s -> %s",
					p.targetURLs[p.currentIndex].URL,
					p.targetURLs[nextIndex].URL)
			}
			p.currentIndex = nextIndex
			return true
		}
		p.currentIndex = nextIndex
	}

	// 如果所有服务器都不健康，保持当前索引
	if startIndex != p.currentIndex {
		log.Printf("⚠️ 所有目标服务器都不健康，保持当前: %s",
			p.targetURLs[p.currentIndex].URL)
	}
	return false
}

// startHealthCheck starts the health check routine
func (p *ProxyServer) startHealthCheck() {
	ticker := time.NewTicker(p.healthCheckInterval)
	defer ticker.Stop()

	for range ticker.C {
		// 先获取服务器列表的副本（在锁外检查健康状态）
		p.mutex.RLock()
		servers := make([]*TargetServer, len(p.targetURLs))
		for i, s := range p.targetURLs {
			servers[i] = &TargetServer{
				URL:       s.URL,
				IsHealthy: s.IsHealthy,
				LastCheck: s.LastCheck,
			}
		}
		currentIdx := p.currentIndex
		p.mutex.RUnlock()

		// 在锁外检查健康状态
		for i, server := range servers {
			wasHealthy := server.IsHealthy
			server.IsHealthy = p.checkHealth(server)
			server.LastCheck = time.Now()

			// 在锁内更新状态
			p.mutex.Lock()
			p.targetURLs[i].IsHealthy = server.IsHealthy
			p.targetURLs[i].LastCheck = server.LastCheck

			if wasHealthy != server.IsHealthy {
				if server.IsHealthy {
					log.Printf("✅ 目标服务器恢复: %s", server.URL)
					// 如果第一个服务器恢复，切换回去
					if i == 0 && p.currentIndex != 0 {
						log.Printf("🔄 第一个服务器恢复，切换回: %s", server.URL)
						p.currentIndex = 0
					}
				} else {
					log.Printf("❌ 目标服务器不可用: %s", server.URL)
					// 如果当前服务器不可用，切换到下一个
					if i == currentIdx {
						// 临时解锁，因为 switchToNextTarget 需要锁
						p.mutex.Unlock()
						p.switchToNextTarget()
						p.mutex.Lock()
					}
				}
			}
			p.mutex.Unlock()
		}
	}
}

// handleProxyRoot handles all requests to the proxy server
func (p *ProxyServer) handleProxyRoot(w http.ResponseWriter, r *http.Request) {
	startTime := time.Now()
	logID := uuid.New().String()

	// Read request body
	requestBody, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Failed to read request body", http.StatusInternalServerError)
		return
	}
	r.Body = io.NopCloser(bytes.NewBuffer(requestBody))

	// Get current target
	currentTarget := p.getCurrentTarget()
	if currentTarget == nil {
		http.Error(w, "No target server available", http.StatusServiceUnavailable)
		return
	}

	// 如果当前目标不健康，尝试切换
	if !currentTarget.IsHealthy {
		p.switchToNextTarget()
		currentTarget = p.getCurrentTarget()
		if currentTarget == nil || !currentTarget.IsHealthy {
			http.Error(w, "No healthy target server available", http.StatusServiceUnavailable)
			return
		}
	}

	// Create target URL
	targetURL := currentTarget.URL + r.URL.Path
	if r.URL.RawQuery != "" {
		targetURL += "?" + r.URL.RawQuery
	}

	// Create new request
	proxyReq, err := http.NewRequest(r.Method, targetURL, bytes.NewBuffer(requestBody))
	if err != nil {
		http.Error(w, "Failed to create proxy request", http.StatusInternalServerError)
		return
	}

	// Copy headers
	for name, values := range r.Header {
		for _, value := range values {
			proxyReq.Header.Add(name, value)
		}
	}

	// Make request to target server
	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(proxyReq)
	if err != nil {
		// 请求失败，标记当前目标为不健康并尝试切换
		log.Printf("❌ 请求失败: %v, 目标: %s", err, currentTarget.URL)
		p.mutex.Lock()
		currentTarget.IsHealthy = false
		p.mutex.Unlock()

		// 尝试切换到下一个目标
		if p.switchToNextTarget() {
			// 递归重试（只重试一次）
			p.handleProxyRoot(w, r)
			return
		}

		http.Error(w, "Failed to proxy request", http.StatusBadGateway)
		return
	}
	defer resp.Body.Close()

	// Read response body
	responseBody, err := io.ReadAll(resp.Body)
	if err != nil {
		http.Error(w, "Failed to read response body", http.StatusInternalServerError)
		return
	}

	// 解压缩响应体（如果需要）
	responseBody, err = decompressResponseBody(responseBody, resp.Header)
	if err != nil {
		log.Printf("Warning: Failed to decompress response body: %v", err)
		// 继续使用原始内容
	}

	fmt.Println("responseBody", string(responseBody))

	// Copy response headers
	for name, values := range resp.Header {
		for _, value := range values {
			w.Header().Add(name, value)
		}
	}

	// Write response
	w.WriteHeader(resp.StatusCode)
	w.Write(responseBody)

	// Log the request/response
	duration := time.Since(startTime).Milliseconds()

	// 获取Content-Type
	requestContentType := r.Header.Get("Content-Type")
	responseContentType := resp.Header.Get("Content-Type")

	// 编码请求体和响应体
	encodedRequestBody, requestBodyType := models.EncodeBody(requestBody, requestContentType)
	encodedResponseBody, responseBodyType := models.EncodeBody(responseBody, responseContentType)

	httpLog := models.HTTPLog{
		ID:               logID,
		Timestamp:        startTime,
		Method:           r.Method,
		URL:              r.URL.String(),
		RequestHeaders:   r.Header,
		RequestBody:      encodedRequestBody,
		RequestBodyType:  requestBodyType,
		ResponseHeaders:  resp.Header,
		ResponseBody:     encodedResponseBody,
		ResponseBodyType: responseBodyType,
		StatusCode:       resp.StatusCode,
		Duration:         duration,
	}

	p.addLog(httpLog)
}

// handleProxy handles requests to the /proxy/ endpoint (alternative method)
func (p *ProxyServer) handleProxy(w http.ResponseWriter, r *http.Request) {
	// This is an alternative endpoint if needed
	p.handleProxyRoot(w, r)
}

// addLog adds a new log entry and notifies WebSocket clients
func (p *ProxyServer) addLog(httpLog models.HTTPLog) {
	// 检查是否正在监听
	p.mutex.RLock()
	isListening := p.isListening
	p.mutex.RUnlock()

	if !isListening {
		log.Printf("⚠️ 日志未记录：监听状态为停止 (请求: %s %s)", httpLog.Method, httpLog.URL)
		return
	}

	p.mutex.Lock()
	defer p.mutex.Unlock()

	// Add log
	p.logs = append(p.logs, httpLog)

	// Limit number of logs
	if len(p.logs) > p.maxLogs {
		p.logs = p.logs[len(p.logs)-p.maxLogs:]
	}

	// Notify WebSocket clients
	clientCount := p.wsHub.GetClientCount()
	log.Printf("📤 发送WebSocket消息: new_log (ID: %s, 客户端数: %d)", httpLog.ID, clientCount)
	p.wsHub.Broadcast(models.WebSocketMessage{
		Type: "new_log",
		Data: httpLog,
	})
}

// handleGetLogs returns all logs with optional filtering
func (p *ProxyServer) handleGetLogs(w http.ResponseWriter, r *http.Request) {
	p.mutex.RLock()
	defer p.mutex.RUnlock()

	// Parse query parameters for filtering
	query := r.URL.Query()
	var filteredLogs []models.HTTPLog

	for _, log := range p.logs {
		if p.matchesFilter(log, query) {
			filteredLogs = append(filteredLogs, log)
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(filteredLogs)
}

// matchesFilter checks if a log matches the filter criteria
func (p *ProxyServer) matchesFilter(log models.HTTPLog, query map[string][]string) bool {
	// URL filter
	if urlValues, exists := query["url"]; exists && len(urlValues) > 0 && urlValues[0] != "" {
		if !strings.Contains(strings.ToLower(log.URL), strings.ToLower(urlValues[0])) {
			return false
		}
	}

	// Method filter
	if methodValues, exists := query["method"]; exists && len(methodValues) > 0 && methodValues[0] != "" {
		if !strings.EqualFold(log.Method, methodValues[0]) {
			return false
		}
	}

	// Status code filter
	if statusValues, exists := query["status_code"]; exists && len(statusValues) > 0 && statusValues[0] != "" {
		if status, err := strconv.Atoi(statusValues[0]); err == nil {
			if log.StatusCode != status {
				return false
			}
		}
	}

	return true
}

// handleClearLogs clears all logs
func (p *ProxyServer) handleClearLogs(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	p.mutex.Lock()
	p.logs = make([]models.HTTPLog, 0)
	p.mutex.Unlock()

	w.WriteHeader(http.StatusOK)
	fmt.Fprintln(w, "Logs cleared")
}

// corsMiddleware adds CORS headers
func (p *ProxyServer) corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}

// handleStartListening starts listening for new HTTP requests
func (p *ProxyServer) handleStartListening(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	p.mutex.Lock()
	p.isListening = true
	p.mutex.Unlock()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":    "success",
		"message":   "开始监听HTTP请求",
		"listening": true,
	})
}

// handleStopListening stops listening for new HTTP requests
func (p *ProxyServer) handleStopListening(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	p.mutex.Lock()
	p.isListening = false
	p.mutex.Unlock()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":    "success",
		"message":   "停止监听HTTP请求",
		"listening": false,
	})
}

// handleListeningStatus returns the current listening status
func (p *ProxyServer) handleListeningStatus(w http.ResponseWriter, r *http.Request) {
	p.mutex.RLock()
	listening := p.isListening
	p.mutex.RUnlock()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"listening": listening,
		"message":   "正在监听",
	})
}

// handleGetTargets returns the status of all target servers
func (p *ProxyServer) handleGetTargets(w http.ResponseWriter, r *http.Request) {
	p.mutex.RLock()
	defer p.mutex.RUnlock()

	targets := make([]map[string]interface{}, 0, len(p.targetURLs))
	for i, server := range p.targetURLs {
		targets = append(targets, map[string]interface{}{
			"index":      i,
			"url":        server.URL,
			"is_healthy": server.IsHealthy,
			"is_active":  i == p.currentIndex,
			"last_check": server.LastCheck.Format(time.RFC3339),
		})
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"targets":        targets,
		"current_index":  p.currentIndex,
		"current_target": p.targetURLs[p.currentIndex].URL,
	})
}
