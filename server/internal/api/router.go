package api

import (
	"net/http"

	"music-server/internal/db"
)

func NewRouter(database *db.DB, musicDir, artworkDir string) http.Handler {
	return http.NewServeMux()
}
