package api

import (
	"net/http"

	"music-server/internal/db"
)

func NewRouter(database *db.Database, musicDir, artworkDir string) http.Handler {
	return http.NewServeMux()
}
