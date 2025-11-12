package main

import (
	"debug-view/proxy"
	"flag"
	"log"
	"strings"
)

func main() {
	// Command line flags
	var (
		targetURLs = flag.String("target", "http://localhost:8080", "Target API server URLs (comma-separated)")
		proxyPort  = flag.String("proxy-port", "8090", "Proxy server port")
		webPort    = flag.String("web-port", "8091", "Web interface port")
		maxLogs    = flag.Int("max-logs", 1000, "Maximum number of logs to keep in memory")
	)
	flag.Parse()

	log.Printf("HTTP调试代理服务启动中...")

	// 解析多个目标 URL（逗号分隔）
	urls := strings.Split(*targetURLs, ",")
	targetList := make([]string, 0, len(urls))
	for _, url := range urls {
		url = strings.TrimSpace(url)
		if url != "" {
			targetList = append(targetList, url)
		}
	}

	if len(targetList) == 0 {
		log.Fatal("至少需要提供一个目标URL")
	}

	log.Printf("目标API服务 (%d个):", len(targetList))
	for i, url := range targetList {
		log.Printf("  [%d] %s", i+1, url)
	}
	log.Printf("代理端口: %s", *proxyPort)
	log.Printf("Web界面端口: %s", *webPort)
	log.Printf("最大日志数: %d", *maxLogs)
	log.Printf("故障转移: 已启用（自动切换）")

	// Create and start proxy server
	proxyServer := proxy.NewProxyServer(targetList, *maxLogs)
	if err := proxyServer.Start(*proxyPort, *webPort); err != nil {
		log.Fatalf("Failed to start proxy server: %v", err)
	}
}
