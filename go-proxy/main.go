package main

import (
	"debug-view/proxy"
	"flag"
	"log"
)

func main() {
	// Command line flags
	var (
		targetURL = flag.String("target", "http://localhost:8080", "Target API server URL")
		proxyPort = flag.String("proxy-port", "8090", "Proxy server port")
		webPort   = flag.String("web-port", "8091", "Web interface port")
		maxLogs   = flag.Int("max-logs", 1000, "Maximum number of logs to keep in memory")
	)
	flag.Parse()

	log.Printf("HTTP调试代理服务启动中...")
	log.Printf("目标API服务: %s", *targetURL)
	log.Printf("代理端口: %s", *proxyPort)
	log.Printf("Web界面端口: %s", *webPort)
	log.Printf("最大日志数: %d", *maxLogs)

	// Create and start proxy server
	proxyServer := proxy.NewProxyServer(*targetURL, *maxLogs)
	if err := proxyServer.Start(*proxyPort, *webPort); err != nil {
		log.Fatalf("Failed to start proxy server: %v", err)
	}
}
