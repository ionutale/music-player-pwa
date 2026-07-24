package api

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"music-server/internal/db"
	"music-server/internal/model"
)

func newTestServer(t *testing.T) (*Router, *db.Database, string) {
	t.Helper()
	dbFile, err := os.CreateTemp("", "music-test-*.db")
	if err != nil {
		t.Fatal(err)
	}
	dbFile.Close()
	t.Cleanup(func() { os.Remove(dbFile.Name()) })

	artDir, err := os.MkdirTemp("", "music-artwork-*")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { os.RemoveAll(artDir) })

	musicDir, err := os.MkdirTemp("", "music-files-*")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { os.RemoveAll(musicDir) })

	database, err := db.New(dbFile.Name())
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { database.Close() })

	return NewRouter(database, musicDir, artDir), database, musicDir
}

func seedTestData(t *testing.T, database *db.Database, musicDir string) (artistID, albumID, songID int64) {
	t.Helper()
	artistID, err := database.UpsertArtist("Test Artist", "Artist, Test")
	if err != nil {
		t.Fatal(err)
	}
	albumID, err = database.UpsertAlbum("Test Album", artistID, 2024, "Rock")
	if err != nil {
		t.Fatal(err)
	}
	songFile := filepath.Join(musicDir, "test_song.mp3")
	if err := os.WriteFile(songFile, []byte("fake mp3 content"), 0644); err != nil {
		t.Fatal(err)
	}
	songID, err = database.UpsertSong("Test Song", 1, 1, 180.5, "mp3", 16, 320, artistID, albumID, songFile)
	if err != nil {
		t.Fatal(err)
	}
	return
}

func seedMultipleSongs(t *testing.T, database *db.Database, musicDir string, n int) {
	t.Helper()
	artistID, _ := database.UpsertArtist("Artist", "Artist")
	albumID, _ := database.UpsertAlbum("Album", artistID, 2024, "Pop")
	for i := range n {
		f := filepath.Join(musicDir, fmt.Sprintf("song_%d.mp3", i))
		os.WriteFile(f, []byte("x"), 0644)
		database.UpsertSong(fmt.Sprintf("Song %d", i+1), i+1, 1, 100, "mp3", 1, 128, artistID, albumID, f)
	}
}

func doRequest(t *testing.T, handler http.Handler, method, path string) (int, []byte) {
	t.Helper()
	req := httptest.NewRequest(method, path, nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	return rec.Code, rec.Body.Bytes()
}

// Songs

func TestHandleSongs_ReturnsList(t *testing.T) {
	router, database, musicDir := newTestServer(t)
	seedTestData(t, database, musicDir)

	status, body := doRequest(t, router, "GET", "/api/songs")
	if status != http.StatusOK {
		t.Fatalf("status = %d, want %d", status, http.StatusOK)
	}
	var songs []model.Song
	if err := json.Unmarshal(body, &songs); err != nil {
		t.Fatal(err)
	}
	if len(songs) != 1 {
		t.Fatalf("expected 1 song, got %d", len(songs))
	}
	if songs[0].Title != "Test Song" {
		t.Errorf("title = %q, want %q", songs[0].Title, "Test Song")
	}
}

func TestHandleSongs_Pagination(t *testing.T) {
	router, database, musicDir := newTestServer(t)
	seedMultipleSongs(t, database, musicDir, 5)

	status, body := doRequest(t, router, "GET", "/api/songs?page=1&limit=2")
	if status != http.StatusOK {
		t.Fatalf("status = %d, want %d", status, http.StatusOK)
	}
	var songs []model.Song
	json.Unmarshal(body, &songs)
	if len(songs) != 2 {
		t.Fatalf("expected 2 songs on page 1, got %d", len(songs))
	}
}

func TestHandleSong_ReturnsOne(t *testing.T) {
	router, database, musicDir := newTestServer(t)
	_, _, songID := seedTestData(t, database, musicDir)

	status, body := doRequest(t, router, "GET", fmt.Sprintf("/api/songs/%d", songID))
	if status != http.StatusOK {
		t.Fatalf("status = %d, want %d", status, http.StatusOK)
	}
	var song model.Song
	json.Unmarshal(body, &song)
	if song.Title != "Test Song" {
		t.Errorf("title = %q, want %q", song.Title, "Test Song")
	}
}

func TestHandleSong_NotFound(t *testing.T) {
	router, _, _ := newTestServer(t)
	status, _ := doRequest(t, router, "GET", "/api/songs/999")
	if status != http.StatusNotFound {
		t.Errorf("status = %d, want %d", status, http.StatusNotFound)
	}
}

// Albums

func TestHandleAlbums_ReturnsList(t *testing.T) {
	router, database, musicDir := newTestServer(t)
	seedTestData(t, database, musicDir)

	status, body := doRequest(t, router, "GET", "/api/albums")
	if status != http.StatusOK {
		t.Fatalf("status = %d, want %d", status, http.StatusOK)
	}
	var albums []model.Album
	json.Unmarshal(body, &albums)
	if len(albums) != 1 {
		t.Fatalf("expected 1 album, got %d", len(albums))
	}
	if albums[0].Title != "Test Album" {
		t.Errorf("title = %q, want %q", albums[0].Title, "Test Album")
	}
	if albums[0].SongCount != 1 {
		t.Errorf("song count = %d, want 1", albums[0].SongCount)
	}
}

func TestHandleAlbum_ReturnsWithSongs(t *testing.T) {
	router, database, musicDir := newTestServer(t)
	_, albumID, _ := seedTestData(t, database, musicDir)

	status, body := doRequest(t, router, "GET", fmt.Sprintf("/api/albums/%d", albumID))
	if status != http.StatusOK {
		t.Fatalf("status = %d, want %d", status, http.StatusOK)
	}
	var data map[string]any
	json.Unmarshal(body, &data)
	if data["album"] == nil {
		t.Error("expected album in response")
	}
	if data["songs"] == nil {
		t.Error("expected songs in response")
	}
}

func TestHandleAlbum_NotFound(t *testing.T) {
	router, _, _ := newTestServer(t)
	status, _ := doRequest(t, router, "GET", "/api/albums/999")
	if status != http.StatusNotFound {
		t.Errorf("status = %d, want %d", status, http.StatusNotFound)
	}
}

// Artists

func TestHandleArtists_ReturnsList(t *testing.T) {
	router, database, musicDir := newTestServer(t)
	seedTestData(t, database, musicDir)

	status, body := doRequest(t, router, "GET", "/api/artists")
	if status != http.StatusOK {
		t.Fatalf("status = %d, want %d", status, http.StatusOK)
	}
	var artists []model.Artist
	json.Unmarshal(body, &artists)
	if len(artists) != 1 {
		t.Fatalf("expected 1 artist, got %d", len(artists))
	}
}

func TestHandleArtist_ReturnsWithAlbums(t *testing.T) {
	router, database, musicDir := newTestServer(t)
	artistID, _, _ := seedTestData(t, database, musicDir)

	status, body := doRequest(t, router, "GET", fmt.Sprintf("/api/artists/%d", artistID))
	if status != http.StatusOK {
		t.Fatalf("status = %d, want %d", status, http.StatusOK)
	}
	var data map[string]any
	json.Unmarshal(body, &data)
	if data["artist"] == nil {
		t.Error("expected artist in response")
	}
	if data["albums"] == nil {
		t.Error("expected albums in response")
	}
}

func TestHandleArtist_NotFound(t *testing.T) {
	router, _, _ := newTestServer(t)
	status, _ := doRequest(t, router, "GET", "/api/artists/999")
	if status != http.StatusNotFound {
		t.Errorf("status = %d, want %d", status, http.StatusNotFound)
	}
}

// Search

func TestHandleSearch_FindsResults(t *testing.T) {
	router, database, musicDir := newTestServer(t)
	seedTestData(t, database, musicDir)

	status, body := doRequest(t, router, "GET", "/api/search?q=Test")
	if status != http.StatusOK {
		t.Fatalf("status = %d, want %d", status, http.StatusOK)
	}
	var result model.SearchResult
	json.Unmarshal(body, &result)
	if len(result.Songs) == 0 {
		t.Error("expected songs in search results")
	}
	if len(result.Albums) == 0 {
		t.Error("expected albums in search results")
	}
	if len(result.Artists) == 0 {
		t.Error("expected artists in search results")
	}
}

func TestHandleSearch_EmptyQuery(t *testing.T) {
	router, _, _ := newTestServer(t)
	status, _ := doRequest(t, router, "GET", "/api/search?q=")
	if status != http.StatusBadRequest {
		t.Errorf("status = %d, want %d", status, http.StatusBadRequest)
	}
}

func TestHandleSearch_NoResults(t *testing.T) {
	router, database, musicDir := newTestServer(t)
	seedTestData(t, database, musicDir)

	status, body := doRequest(t, router, "GET", "/api/search?q=zzzznonexistent")
	if status != http.StatusOK {
		t.Fatalf("status = %d, want %d", status, http.StatusOK)
	}
	var result model.SearchResult
	json.Unmarshal(body, &result)
	if len(result.Songs)+len(result.Albums)+len(result.Artists) != 0 {
		t.Error("expected empty search results for non-matching query")
	}
}

// Artwork

func TestHandleArtwork_NotFound(t *testing.T) {
	router, _, _ := newTestServer(t)
	status, _ := doRequest(t, router, "GET", "/api/artwork/999")
	if status != http.StatusNotFound {
		t.Errorf("status = %d, want %d (expected 404 for missing artwork)", status, http.StatusNotFound)
	}
}

// Stream

func TestHandleStream_ReturnsAudioContent(t *testing.T) {
	router, database, musicDir := newTestServer(t)
	_, _, songID := seedTestData(t, database, musicDir)

	status, _ := doRequest(t, router, "GET", fmt.Sprintf("/api/stream/%d", songID))
	if status != http.StatusOK {
		t.Fatalf("status = %d, want %d", status, http.StatusOK)
	}
}

func TestHandleStream_NotFound(t *testing.T) {
	router, _, _ := newTestServer(t)
	status, _ := doRequest(t, router, "GET", "/api/stream/999")
	if status != http.StatusNotFound {
		t.Errorf("status = %d, want %d", status, http.StatusNotFound)
	}
}

func TestHandleStream_SupportsRangeRequests(t *testing.T) {
	router, database, musicDir := newTestServer(t)
	_, _, songID := seedTestData(t, database, musicDir)

	req := httptest.NewRequest("GET", fmt.Sprintf("/api/stream/%d", songID), nil)
	req.Header.Set("Range", "bytes=0-4")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusPartialContent && rec.Code != http.StatusOK {
		t.Errorf("status = %d, want 206 or 200", rec.Code)
	}
}

// Scan

func TestHandleScan_ReturnsStarted(t *testing.T) {
	router, _, _ := newTestServer(t)
	status, body := doRequest(t, router, "POST", "/api/scan")
	if status != http.StatusOK {
		t.Fatalf("status = %d, want %d", status, http.StatusOK)
	}
	var data map[string]string
	json.Unmarshal(body, &data)
	if data["status"] != "started" {
		t.Errorf("status = %q, want %q", data["status"], "started")
	}
}

// Stats

func TestHandleStats(t *testing.T) {
	router, database, musicDir := newTestServer(t)
	seedTestData(t, database, musicDir)

	status, body := doRequest(t, router, "GET", "/api/stats")
	if status != http.StatusOK {
		t.Fatalf("status = %d, want %d", status, http.StatusOK)
	}
	var stats model.Stats
	json.Unmarshal(body, &stats)
	if stats.SongCount != 1 {
		t.Errorf("song count = %d, want 1", stats.SongCount)
	}
}

// 404 for unknown routes

func TestUnknownRoutes(t *testing.T) {
	router, _, _ := newTestServer(t)
	routes := []string{"/", "/api", "/api/unknown"}
	expect404 := map[string]int{"/": 404, "/api": 404, "/api/unknown": 404}
	for _, path := range routes {
		status, _ := doRequest(t, router, "GET", path)
		if status != expect404[path] {
			t.Errorf("GET %s: status = %d, want %d", path, status, expect404[path])
		}
	}
	// /api/songs/abc matches the route but has invalid id → 400
	status, _ := doRequest(t, router, "GET", "/api/songs/abc")
	if status != http.StatusBadRequest {
		t.Errorf("GET /api/songs/abc: status = %d, want %d (invalid id)", status, http.StatusBadRequest)
	}
}

// Wrong HTTP methods

func TestGetOnPostEndpoint_Returns404(t *testing.T) {
	router, _, _ := newTestServer(t)
	status, _ := doRequest(t, router, "GET", "/api/scan")
	if status != http.StatusNotFound {
		t.Errorf("status = %d, want %d", status, http.StatusNotFound)
	}
}

func TestPostOnGetEndpoint_Returns404(t *testing.T) {
	router, _, _ := newTestServer(t)
	status, _ := doRequest(t, router, "POST", "/api/songs")
	if status != http.StatusNotFound {
		t.Errorf("status = %d, want %d", status, http.StatusNotFound)
	}
}

// JSON content type

func TestEndpointsReturnJSON(t *testing.T) {
	router, database, musicDir := newTestServer(t)
	seedTestData(t, database, musicDir)

	endpoints := []string{"/api/songs", "/api/albums", "/api/artists", "/api/stats"}
	for _, ep := range endpoints {
		req := httptest.NewRequest("GET", ep, nil)
		rec := httptest.NewRecorder()
		router.ServeHTTP(rec, req)
		if rec.Code != http.StatusOK {
			continue
		}
		ct := rec.Header().Get("Content-Type")
		if !strings.Contains(ct, "json") {
			t.Errorf("%s: Content-Type = %q, want application/json", ep, ct)
		}
	}
}
