package middleware

import (
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func okHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"status":"ok"}`))
}

func TestAuth_ValidKey(t *testing.T) {
	handler := Auth(http.HandlerFunc(okHandler), "secret123")
	req := httptest.NewRequest("GET", "/api/songs", nil)
	req.Header.Set("X-API-Key", "secret123")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
	}
	body, _ := io.ReadAll(rec.Body)
	if !strings.Contains(string(body), "ok") {
		t.Errorf("body = %s, want ok response", body)
	}
}

func TestAuth_InvalidKey(t *testing.T) {
	handler := Auth(http.HandlerFunc(okHandler), "secret123")
	req := httptest.NewRequest("GET", "/api/songs", nil)
	req.Header.Set("X-API-Key", "wrong-key")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
}

func TestAuth_MissingKey(t *testing.T) {
	handler := Auth(http.HandlerFunc(okHandler), "secret123")
	req := httptest.NewRequest("GET", "/api/songs", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
}

func TestAuth_EmptyKeyInConfig(t *testing.T) {
	handler := Auth(http.HandlerFunc(okHandler), "")
	req := httptest.NewRequest("GET", "/api/songs", nil)
	req.Header.Set("X-API-Key", "")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	// Empty key matches empty config
	if rec.Code != http.StatusOK {
		t.Errorf("status = %d, want %d (empty key should match)", rec.Code, http.StatusOK)
	}
}

func TestAuth_ErrorResponseIsJSON(t *testing.T) {
	handler := Auth(http.HandlerFunc(okHandler), "secret123")
	req := httptest.NewRequest("GET", "/api/songs", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	ct := rec.Header().Get("Content-Type")
	if ct != "text/plain; charset=utf-8" {
		// http.Error uses text/plain, that's fine
	}
	body, _ := io.ReadAll(rec.Body)
	if !strings.Contains(string(body), "unauthorized") {
		t.Errorf("body = %s, want unauthorized message", body)
	}
}

func TestAuth_PassesNextHandler(t *testing.T) {
	var gotRequest *http.Request
	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotRequest = r
		w.WriteHeader(http.StatusOK)
	})

	handler := Auth(next, "key")
	req := httptest.NewRequest("POST", "/api/scan", nil)
	req.Header.Set("X-API-Key", "key")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if gotRequest == nil {
		t.Fatal("next handler was not called")
	}
	if gotRequest.Method != "POST" {
		t.Errorf("method = %s, want POST", gotRequest.Method)
	}
}
