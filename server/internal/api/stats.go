package api

import "net/http"

func (rt *Router) handleStats(w http.ResponseWriter, r *http.Request) {
	stats, err := rt.db.GetStats()
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
		return
	}
	writeJSON(w, stats)
}
