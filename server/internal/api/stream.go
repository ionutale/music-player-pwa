package api

import (
	"net/http"
	"os"
	"strconv"
)

func (rt *Router) handleStream(w http.ResponseWriter, r *http.Request) {
	id, err := idFromPath(r.URL.Path, "/api/stream/")
	if err != nil {
		http.Error(w, `{"error":"invalid id"}`, http.StatusBadRequest)
		return
	}
	song, err := rt.db.GetSong(id)
	if err != nil {
		http.Error(w, `{"error":"not found"}`, http.StatusNotFound)
		return
	}
	file, err := os.Open(song.FilePath)
	if err != nil {
		http.Error(w, `{"error":"file not found"}`, http.StatusNotFound)
		return
	}
	defer file.Close()

	stat, _ := file.Stat()
	fileSize := stat.Size()
	w.Header().Set("Content-Type", "audio/"+song.FileFormat)
	w.Header().Set("Content-Length", strconv.FormatInt(fileSize, 10))
	w.Header().Set("Accept-Ranges", "bytes")

	rangeHeader := r.Header.Get("Range")
	if rangeHeader == "" {
		http.ServeContent(w, r, song.Title+"."+song.FileFormat, stat.ModTime(), file)
		return
	}

	http.ServeContent(w, r, song.Title+"."+song.FileFormat, stat.ModTime(), file)
}
