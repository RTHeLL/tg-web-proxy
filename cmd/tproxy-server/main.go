package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/telegramdesktop/tproxy-server/internal/config"
	appserver "github.com/telegramdesktop/tproxy-server/internal/server"
	"github.com/telegramdesktop/tproxy-server/internal/session"
)

func main() {
	configPath := flag.String("config", "config.json", "path to server configuration")
	profilesPath := flag.String("profiles-file", "", "override profiles file path")
	check := flag.Bool("check", false, "validate configuration and exit")
	flag.Parse()

	value, err := config.Load(*configPath, *profilesPath)
	if err != nil {
		log.Fatalf("configuration error: %v", err)
	}
	if err := session.ValidateBudget(value); err != nil {
		log.Fatalf("configuration error: %v", err)
	}
	application, err := appserver.New(value)
	if err != nil {
		log.Fatalf("server initialization error: %v", err)
	}
	if *check {
		application.Shutdown()
		fmt.Println("configuration is valid")
		return
	}
	publicListener, err := net.Listen("tcp", value.Listen)
	if err != nil {
		log.Fatalf("public listener error: %v", err)
	}
	adminListener, err := net.Listen("tcp", value.AdminListen)
	if err != nil {
		_ = publicListener.Close()
		log.Fatalf("admin listener error: %v", err)
	}

	// ReadTimeout covers the whole request including a slow body; it must stay
	// well above long_poll because the server's background read would
	// otherwise cancel every parked long poll's context.
	readTimeout := 60 * time.Second
	if minimum := 2 * value.Timeouts.LongPoll.Value(); minimum > readTimeout {
		readTimeout = minimum
	}
	publicHTTP := &http.Server{
		Handler:           application.Handler(),
		ReadHeaderTimeout: value.Timeouts.ReadHeader.Value(),
		ReadTimeout:       readTimeout,
		IdleTimeout:       value.Timeouts.Idle.Value(),
		MaxHeaderBytes:    value.Limits.MaxHeaderBytes,
	}
	adminHTTP := &http.Server{
		Handler:           application.AdminHandler(),
		ReadHeaderTimeout: 5 * time.Second,
		IdleTimeout:       30 * time.Second,
		MaxHeaderBytes:    4096,
	}
	errors := make(chan error, 2)
	go func() { errors <- publicHTTP.Serve(publicListener) }()
	go func() { errors <- adminHTTP.Serve(adminListener) }()
	log.Printf("event=started public=%s admin=%s profiles=%d", value.Listen, value.AdminListen, len(value.Profiles))

	signals := make(chan os.Signal, 1)
	signal.Notify(signals, syscall.SIGINT, syscall.SIGTERM)
	select {
	case signal := <-signals:
		log.Printf("event=shutdown signal=%s", signal)
	case serveErr := <-errors:
		if serveErr != nil && serveErr != http.ErrServerClosed {
			log.Printf("event=listener_failed class=http")
		}
	}

	ctx, cancel := context.WithTimeout(context.Background(), value.Timeouts.Shutdown.Value())
	defer cancel()
	_ = publicHTTP.Shutdown(ctx)
	_ = adminHTTP.Shutdown(ctx)
	application.Shutdown()
	log.Printf("event=stopped")
}
