package proxy

import (
	"bytes"
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

// ProxyServer represents the HTTP proxy server
type ProxyServer struct {
	targetURL   string
	logs        []models.HTTPLog
	mutex       sync.RWMutex
	maxLogs     int
	wsHub       *WebSocketHub
	isListening bool
}

// NewProxyServer creates a new proxy server instance
func NewProxyServer(targetURL string, maxLogs int) *ProxyServer {
	return &ProxyServer{
		targetURL:   targetURL,
		logs:        make([]models.HTTPLog, 0),
		maxLogs:     maxLogs,
		wsHub:       NewWebSocketHub(),
		isListening: true, // 默认开启监听
	}
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
	mux.HandleFunc("/api/ws", p.wsHub.HandleWebSocket)

	// Static file handler for Flutter web
	mux.Handle("/", http.FileServer(http.Dir("./web/static/")))

	log.Printf("Proxy server starting on port %s, target: %s", proxyPort, p.targetURL)
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

	// Create target URL
	targetURL := p.targetURL + r.URL.Path
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
func (p *ProxyServer) addLog(log models.HTTPLog) {
	// 检查是否正在监听
	if !p.isListening {
		return
	}

	p.mutex.Lock()
	defer p.mutex.Unlock()

	// Add log
	p.logs = append(p.logs, log)

	// Limit number of logs
	if len(p.logs) > p.maxLogs {
		p.logs = p.logs[len(p.logs)-p.maxLogs:]
	}

	// Notify WebSocket clients
	p.wsHub.Broadcast(models.WebSocketMessage{
		Type: "new_log",
		Data: log,
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
