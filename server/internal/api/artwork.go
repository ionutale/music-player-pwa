package api

import "net/http"

func (rt *Router) handleArtwork(w http.ResponseWriter, r *http.Request) {
	http.Error(w, `{"error":"not implemented"}`, http.StatusNotImplemented)
}
