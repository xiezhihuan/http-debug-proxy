package models

import (
	"encoding/base64"
	"strings"
	"time"
)

// HTTPLog represents a logged HTTP request and response
type HTTPLog struct {
	ID               string              `json:"id"`
	Timestamp        time.Time           `json:"timestamp"`
	Method           string              `json:"method"`
	URL              string              `json:"url"`
	RequestHeaders   map[string][]string `json:"request_headers"`
	RequestBody      string              `json:"request_body"`
	RequestBodyType  string              `json:"request_body_type"` // "text" or "binary"
	ResponseHeaders  map[string][]string `json:"response_headers"`
	ResponseBody     string              `json:"response_body"`
	ResponseBodyType string              `json:"response_body_type"` // "text" or "binary"
	StatusCode       int                 `json:"status_code"`
	Duration         int64               `json:"duration"` // in milliseconds
}

// HTTPLogFilter represents filter criteria for HTTP logs
type HTTPLogFilter struct {
	URL        string    `json:"url"`
	Method     string    `json:"method"`
	StatusCode int       `json:"status_code"`
	StartTime  time.Time `json:"start_time"`
	EndTime    time.Time `json:"end_time"`
}

// WebSocketMessage represents a message sent via WebSocket
type WebSocketMessage struct {
	Type string      `json:"type"` // "new_log", "log_list"
	Data interface{} `json:"data"`
}

// IsTextContent 判断是否为文本内容
func IsTextContent(contentType string) bool {
	if contentType == "" {
		return false
	}

	// 常见的文本类型
	textTypes := []string{
		"text/", "application/json", "application/xml", "application/javascript",
		"application/x-www-form-urlencoded", "multipart/form-data",
		"application/ld+json", "application/x-yaml", "application/yaml",
		"application/x-csv", "text/csv",
	}

	for _, textType := range textTypes {
		if len(contentType) >= len(textType) && contentType[:len(textType)] == textType {
			return true
		}
	}

	return false
}

// EncodeBody 编码body内容，文本直接返回，二进制转为base64
func EncodeBody(body []byte, contentType string) (string, string) {
	if IsTextContent(contentType) {
		// 对于文本内容，尝试清理和格式化
		cleanText := cleanTextContent(body, contentType)
		return cleanText, "text"
	}

	// 二进制内容转换为base64
	return base64.StdEncoding.EncodeToString(body), "binary"
}

// cleanTextContent 清理文本内容，解决乱码问题
func cleanTextContent(data []byte, contentType string) string {
	if len(data) == 0 {
		return ""
	}

	// 检查是否包含不可打印字符
	hasControlChars := false
	for _, b := range data {
		if b < 32 && b != 9 && b != 10 && b != 13 { // 除了制表符、换行符、回车符
			hasControlChars = true
			break
		}
	}

	// 如果包含控制字符，可能是二进制数据，转为base64
	if hasControlChars {
		return base64.StdEncoding.EncodeToString(data)
	}

	// 尝试转换为字符串，处理编码问题
	text := string(data)

	// 移除BOM标记
	if strings.HasPrefix(text, "\uFEFF") {
		text = strings.TrimPrefix(text, "\uFEFF")
	}

	// 清理常见的乱码字符
	text = strings.ReplaceAll(text, "\x00", "")
	text = strings.ReplaceAll(text, "\x01", "")
	text = strings.ReplaceAll(text, "\x02", "")
	text = strings.ReplaceAll(text, "\x03", "")
	text = strings.ReplaceAll(text, "\x04", "")
	text = strings.ReplaceAll(text, "\x05", "")
	text = strings.ReplaceAll(text, "\x06", "")
	text = strings.ReplaceAll(text, "\x07", "")
	text = strings.ReplaceAll(text, "\x08", "")
	text = strings.ReplaceAll(text, "\x0B", "")
	text = strings.ReplaceAll(text, "\x0C", "")
	text = strings.ReplaceAll(text, "\x0E", "")
	text = strings.ReplaceAll(text, "\x0F", "")

	return text
}
