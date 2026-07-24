package api

import "net/http"

func (rt *Router) handleAlbums(w http.ResponseWriter, r *http.Request) {
	page, limit := parsePageLimit(r)
	albums, err := rt.db.GetAlbums(page, limit)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
		return
	}
	writeJSON(w, albums)
}

func (rt *Router) handleAlbum(w http.ResponseWriter, r *http.Request) {
	id, err := idFromPath(r.URL.Path, "/api/albums/")
	if err != nil {
		http.Error(w, `{"error":"invalid id"}`, http.StatusBadRequest)
		return
	}
	album, songs, err := rt.db.GetAlbum(id)
	if err != nil {
		http.Error(w, `{"error":"not found"}`, http.StatusNotFound)
		return
	}
	writeJSON(w, map[string]any{"album": album, "songs": songs})
}
