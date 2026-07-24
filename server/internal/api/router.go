package api

import (
	"encoding/json"
	"net/http"
	"strconv"

	"music-server/internal/db"
	"music-server/internal/scanner"
)

type Router struct {
	db         *db.Database
	scanner    *scanner.Scanner
	musicDir   string
	artworkDir string
}

func NewRouter(database *db.Database, musicDir, artworkDir string) *Router {
	return &Router{
		db:         database,
		scanner:    scanner.New(database, musicDir, artworkDir),
		musicDir:   musicDir,
		artworkDir: artworkDir,
	}
}

func (rt *Router) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	switch {
	case r.Method == "GET" && r.URL.Path == "/api/songs":
		rt.handleSongs(w, r)
	case r.Method == "GET" && matchPath(r.URL.Path, "/api/songs/"):
		rt.handleSong(w, r)
	case r.Method == "GET" && r.URL.Path == "/api/albums":
		rt.handleAlbums(w, r)
	case r.Method == "GET" && matchPath(r.URL.Path, "/api/albums/"):
		rt.handleAlbum(w, r)
	case r.Method == "GET" && r.URL.Path == "/api/artists":
		rt.handleArtists(w, r)
	case r.Method == "GET" && matchPath(r.URL.Path, "/api/artists/"):
		rt.handleArtist(w, r)
	case r.Method == "GET" && r.URL.Path == "/api/search":
		rt.handleSearch(w, r)
	case r.Method == "GET" && matchPath(r.URL.Path, "/api/artwork/"):
		rt.handleArtwork(w, r)
	case r.Method == "GET" && matchPath(r.URL.Path, "/api/stream/"):
		rt.handleStream(w, r)
	case r.Method == "POST" && r.URL.Path == "/api/scan":
		rt.handleScan(w, r)
	case r.Method == "GET" && r.URL.Path == "/api/stats":
		rt.handleStats(w, r)
	default:
		http.Error(w, `{"error":"not found"}`, http.StatusNotFound)
	}
}

func matchPath(path, prefix string) bool {
	return len(path) > len(prefix) && path[:len(prefix)] == prefix
}

func idFromPath(path, prefix string) (int64, error) {
	return strconv.ParseInt(path[len(prefix):], 10, 64)
}

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(v)
}

func parsePageLimit(r *http.Request) (int, int) {
	page, _ := strconv.Atoi(r.URL.Query().Get("page"))
	if page < 1 {
		page = 1
	}
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	if limit < 1 || limit > 100 {
		limit = 50
	}
	return page, limit
}
