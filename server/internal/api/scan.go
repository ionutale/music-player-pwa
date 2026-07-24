package api

import "net/http"

func (rt *Router) handleScan(w http.ResponseWriter, r *http.Request) {
	go func() {
		rt.scanner.Scan()
	}()
	writeJSON(w, map[string]string{"status": "started"})
}
