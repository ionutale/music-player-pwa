package api

import (
	"net/http"

	"music-server/internal/model"
)

func (rt *Router) handleArtists(w http.ResponseWriter, r *http.Request) {
	page, limit := parsePageLimit(r)
	artists, err := rt.db.GetArtists(page, limit)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
		return
	}
	writeJSON(w, artists)
}

func (rt *Router) handleArtist(w http.ResponseWriter, r *http.Request) {
	id, err := idFromPath(r.URL.Path, "/api/artists/")
	if err != nil {
		http.Error(w, `{"error":"invalid id"}`, http.StatusBadRequest)
		return
	}
	artist, err := rt.db.GetArtist(id)
	if err != nil {
		http.Error(w, `{"error":"not found"}`, http.StatusNotFound)
		return
	}
	albums, _ := rt.db.GetAlbums(1, 1000)
	filtered := make([]model.Album, 0)
	for _, a := range albums {
		if a.ArtistID == id {
			filtered = append(filtered, a)
		}
	}
	writeJSON(w, map[string]any{"artist": artist, "albums": filtered})
}
