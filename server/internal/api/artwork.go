package api

import (
	"fmt"
	"net/http"
	"os"
	"path/filepath"
)

func (rt *Router) handleArtwork(w http.ResponseWriter, r *http.Request) {
	id, err := idFromPath(r.URL.Path, "/api/artwork/")
	if err != nil {
		http.Error(w, `{"error":"invalid id"}`, http.StatusBadRequest)
		return
	}
	for _, ext := range []string{".jpg", ".png"} {
		path := filepath.Join(rt.artworkDir, fmt.Sprintf("%d%s", id, ext))
		if _, err := os.Stat(path); err == nil {
			w.Header().Set("Content-Type", "image/"+ext[1:])
			http.ServeFile(w, r, path)
			return
		}
	}
	http.Error(w, `{"error":"not found"}`, http.StatusNotFound)
}
