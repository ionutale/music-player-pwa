package api

import (
	"net/http"
)

func (rt *Router) handleSongs(w http.ResponseWriter, r *http.Request) {
	page, limit := parsePageLimit(r)
	songs, err := rt.db.GetSongs(page, limit)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
		return
	}
	writeJSON(w, songs)
}

func (rt *Router) handleSong(w http.ResponseWriter, r *http.Request) {
	id, err := idFromPath(r.URL.Path, "/api/songs/")
	if err != nil {
		http.Error(w, `{"error":"invalid id"}`, http.StatusBadRequest)
		return
	}
	song, err := rt.db.GetSong(id)
	if err != nil {
		http.Error(w, `{"error":"not found"}`, http.StatusNotFound)
		return
	}
	writeJSON(w, song)
}
