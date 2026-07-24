package main

import (
	"log"
	"net/http"
	"os"

	"music-server/internal/api"
	"music-server/internal/db"
	"music-server/internal/middleware"
)

func main() {
	addr := os.Getenv("LISTEN_ADDR")
	if addr == "" {
		addr = ":8080"
	}
	musicDir := os.Getenv("MUSIC_DIR")
	if musicDir == "" {
		musicDir = "/music"
	}
	dbPath := os.Getenv("DB_PATH")
	if dbPath == "" {
		dbPath = "/data/music.db"
	}
	artworkDir := os.Getenv("ARTWORK_DIR")
	if artworkDir == "" {
		artworkDir = "/data/artwork"
	}
	apiKey := os.Getenv("API_KEY")
	if apiKey == "" {
		log.Fatal("API_KEY environment variable is required")
	}

	database, err := db.New(dbPath)
	if err != nil {
		log.Fatalf("failed to open database: %v", err)
	}
	defer database.Close()

	router := api.NewRouter(database, musicDir, artworkDir)
	mux := middleware.Auth(router, apiKey)

	log.Printf("starting server on %s", addr)
	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatalf("server failed: %v", err)
	}
}
