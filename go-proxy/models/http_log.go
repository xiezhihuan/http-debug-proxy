package models

import (
	"time"
)

// HTTPLog represents a logged HTTP request and response
type HTTPLog struct {
	ID              string              `json:"id"`
	Timestamp       time.Time           `json:"timestamp"`
	Method          string              `json:"method"`
	URL             string              `json:"url"`
	RequestHeaders  map[string][]string `json:"request_headers"`
	RequestBody     string              `json:"request_body"`
	ResponseHeaders map[string][]string `json:"response_headers"`
	ResponseBody    string              `json:"response_body"`
	StatusCode      int                 `json:"status_code"`
	Duration        int64               `json:"duration"` // in milliseconds
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
