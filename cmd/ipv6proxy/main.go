package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"sync"

	"github.com/qza1314526-debug/v6-ee/internal/config"
	"github.com/qza1314526-debug/v6-ee/internal/proxy"
	"github.com/qza1314526-debug/v6-ee/internal/sysutils"
)

func main() {
	log.SetOutput(os.Stdout)
	cfg := config.ParseFlags()
	if cfg.CIDR == "" {
		log.Fatal("CIDR is required")
	}

	if cfg.AutoForwarding {
		sysutils.SetV6Forwarding()
	}

	if cfg.AutoRoute {
		sysutils.AddV6Route(cfg.CIDR)
	}

	if cfg.AutoIpNoLocalBind {
		sysutils.SetIpNonLocalBind()
	}

	var wg sync.WaitGroup

	// 启动随机IPv6代理服务器
	randomIPv6Proxy := proxy.NewProxyServer(cfg, true)
	wg.Add(1)
	go func() {
		defer wg.Done()
		log.Printf("Starting random IPv6 proxy server on %s:%d", cfg.Bind, cfg.RandomIPv6Port)
		err := http.ListenAndServe(fmt.Sprintf("%s:%d", cfg.Bind, cfg.RandomIPv6Port), randomIPv6Proxy)
		if err != nil {
			log.Fatal(err)
		}
	}()

	// 如果有多IP配置，为每个IP启动代理服务器
	if len(cfg.MultiIPv4Config) > 0 {
		log.Printf("Starting multi-IPv4 proxy servers...")
		for _, ipConfig := range cfg.MultiIPv4Config {
			wg.Add(1)
			go func(ipCfg config.MultiIPConfig) {
				defer wg.Done()
				// 为每个IP创建专用的配置
				ipv4Cfg := *cfg
				ipv4Cfg.RealIPv4 = ipCfg.IPv4
				
				realIPv4Proxy := proxy.NewProxyServerWithSpecificIP(&ipv4Cfg, false, ipCfg.IPv4)
				log.Printf("Starting IPv4 proxy server for %s on port %d", ipCfg.IPv4, ipCfg.Port)
				err := http.ListenAndServe(fmt.Sprintf("%s:%d", ipCfg.IPv4, ipCfg.Port), realIPv4Proxy)
				if err != nil {
					log.Printf("Error starting proxy for %s:%d - %v", ipCfg.IPv4, ipCfg.Port, err)
				}
			}(ipConfig)
		}
	} else if cfg.RealIPv4 != "" {
		// 单IP模式（向后兼容）
		realIPv4Proxy := proxy.NewProxyServer(cfg, false)
		wg.Add(1)
		go func() {
			defer wg.Done()
			log.Printf("Starting real IPv4 proxy server on %s:%d", cfg.Bind, cfg.RealIPv4Port)
			err := http.ListenAndServe(fmt.Sprintf("%s:%d", cfg.Bind, cfg.RealIPv4Port), realIPv4Proxy)
			if err != nil {
				log.Fatal(err)
			}
		}()
	} else {
		log.Fatal("Either real-ipv4 or multi-ipv4 is required")
	}

	// 等待所有服务器
	wg.Wait()
}
