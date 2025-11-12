package proxy

import (
	"debug-view/models"
	"encoding/json"
	"log"
	"net/http"
	"time"

	"github.com/gorilla/websocket"
)

// WebSocketHub manages WebSocket connections
type WebSocketHub struct {
	clients    map[*WebSocketClient]bool
	register   chan *WebSocketClient
	unregister chan *WebSocketClient
	broadcast  chan models.WebSocketMessage
}

// GetClientCount returns the number of connected clients
func (h *WebSocketHub) GetClientCount() int {
	return len(h.clients)
}

// WebSocketClient represents a WebSocket client connection
type WebSocketClient struct {
	hub  *WebSocketHub
	conn *websocket.Conn
	send chan models.WebSocketMessage
}

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true // Allow all origins for development
	},
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
}

const (
	// Time allowed to write a message to the peer.
	writeWait = 10 * time.Second

	// Time allowed to read the next pong message from the peer.
	pongWait = 60 * time.Second

	// Send pings to peer with this period. Must be less than pongWait.
	pingPeriod = (pongWait * 9) / 10

	// Maximum message size allowed from peer.
	maxMessageSize = 512
)

// NewWebSocketHub creates a new WebSocket hub
func NewWebSocketHub() *WebSocketHub {
	hub := &WebSocketHub{
		clients:    make(map[*WebSocketClient]bool),
		register:   make(chan *WebSocketClient),
		unregister: make(chan *WebSocketClient),
		broadcast:  make(chan models.WebSocketMessage),
	}

	// 启动定期清理死连接的goroutine
	go hub.cleanupDeadConnections()

	return hub
}

// cleanupDeadConnections 定期清理死连接
func (h *WebSocketHub) cleanupDeadConnections() {
	ticker := time.NewTicker(10 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		clientCount := len(h.clients)
		if clientCount > 5 {
			log.Printf("检测到过多WebSocket连接 (%d)，开始清理死连接", clientCount)

			// 向所有客户端发送ping，无响应的将被清理
			deadClients := make([]*WebSocketClient, 0)
			for client := range h.clients {
				select {
				case client.send <- models.WebSocketMessage{Type: "ping", Data: "cleanup"}:
					// 成功发送ping
				default:
					// 发送失败，说明连接已死，标记清理
					deadClients = append(deadClients, client)
				}
			}

			// 清理死连接
			for _, client := range deadClients {
				close(client.send)
				client.conn.Close()
				delete(h.clients, client)
				log.Printf("清理死连接")
			}

			log.Printf("清理后WebSocket连接数: %d", len(h.clients))
		}
	}
}

// Run starts the WebSocket hub
func (h *WebSocketHub) Run() {
	for {
		select {
		case client := <-h.register:
			h.clients[client] = true
			log.Printf("📝 WebSocket客户端已注册. 总连接数: %d", len(h.clients))

		case client := <-h.unregister:
			if _, ok := h.clients[client]; ok {
				delete(h.clients, client)
				close(client.send)
				// 确保连接被关闭
				client.conn.Close()
				log.Printf("🔌 WebSocket客户端已断开. 剩余连接数: %d", len(h.clients))
			}

		case message := <-h.broadcast:
			clientCount := len(h.clients)
			if clientCount == 0 {
				continue
			}
			sentCount := 0
			for client := range h.clients {
				select {
				case client.send <- message:
					sentCount++
				default:
					// 发送失败，说明连接可能已断开，清理连接
					close(client.send)
					client.conn.Close()
					delete(h.clients, client)
					log.Printf("WebSocket client removed (send failed). Total clients: %d", len(h.clients))
				}
			}
			if sentCount > 0 {
				log.Printf("✅ WebSocket消息已发送到 %d/%d 个客户端 (类型: %s)", sentCount, clientCount, message.Type)
			} else {
				log.Printf("⚠️ WebSocket消息未发送到任何客户端 (类型: %s, 客户端数: %d)", message.Type, clientCount)
			}
		}
	}
}

// HandleWebSocket handles WebSocket upgrade requests
func (h *WebSocketHub) HandleWebSocket(w http.ResponseWriter, r *http.Request) {
	// 详细记录连接信息
	clientIP := r.RemoteAddr
	userAgent := r.Header.Get("User-Agent")
	origin := r.Header.Get("Origin")
	referer := r.Header.Get("Referer")

	log.Printf("🔍 WebSocket连接请求详情:")
	log.Printf("   IP: %s", clientIP)
	log.Printf("   Origin: %s", origin)
	log.Printf("   Referer: %s", referer)
	log.Printf("   User-Agent: %s", userAgent)
	log.Printf("   当前连接数: %d", len(h.clients))

	// 临时防护：如果连接数超过10，拒绝新连接
	if len(h.clients) >= 10 {
		log.Printf("⚠️ 连接数过多 (%d)，拒绝新连接 - IP: %s", len(h.clients), clientIP)
		http.Error(w, "Too many connections", http.StatusTooManyRequests)
		return
	}

	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("❌ WebSocket升级失败: %v - IP: %s", err, clientIP)
		return
	}

	client := &WebSocketClient{
		hub:  h,
		conn: conn,
		send: make(chan models.WebSocketMessage, 256),
	}

	log.Printf("✅ WebSocket连接成功 - IP: %s, 新连接数: %d", clientIP, len(h.clients)+1)

	client.hub.register <- client

	// Start goroutines for handling the connection
	go client.writePump()
	go client.readPump()
}

// Broadcast sends a message to all connected clients
func (h *WebSocketHub) Broadcast(message models.WebSocketMessage) {
	clientCount := len(h.clients)
	if clientCount == 0 {
		log.Printf("⚠️ 没有WebSocket客户端连接，消息未发送")
		return
	}

	select {
	case h.broadcast <- message:
		log.Printf("📨 消息已加入广播队列 (客户端数: %d, 类型: %s)", clientCount, message.Type)
	default:
		// Channel is full, skip this message
		log.Printf("❌ 广播通道已满，消息被跳过 (客户端数: %d)", clientCount)
	}
}

// readPump handles reading from the WebSocket connection
func (c *WebSocketClient) readPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()

	c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetReadLimit(maxMessageSize)
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	for {
		_, _, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("WebSocket read error: %v", err)
			}
			break
		}
	}
}

// writePump handles writing to the WebSocket connection
func (c *WebSocketClient) writePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				// The hub closed the channel.
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			data, err := json.Marshal(message)
			if err != nil {
				log.Printf("JSON marshal error: %v", err)
				continue
			}

			if err := c.conn.WriteMessage(websocket.TextMessage, data); err != nil {
				log.Printf("WebSocket write error: %v", err)
				return
			}

		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}
