package scanner

import (
	"os"
	"path/filepath"
	"testing"

	"music-server/internal/db"
)

func newTestDB(t *testing.T) *db.Database {
	t.Helper()
	f, err := os.CreateTemp("", "music-scanner-test-*.db")
	if err != nil {
		t.Fatal(err)
	}
	f.Close()
	t.Cleanup(func() { os.Remove(f.Name()) })
	database, err := db.New(f.Name())
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { database.Close() })
	return database
}

func createMinimalMP3(t *testing.T, path, title, artist, album string) {
	t.Helper()
	// Build ID3v2.3 tag with minimal frames
	id3 := make([]byte, 0, 1024)
	id3 = append(id3, "ID3"...)
	id3 = append(id3, 3, 0)   // version 2.3
	id3 = append(id3, 0)      // flags

	padSize := 2048

	// Frame builder: encoding byte (0x00 = ISO-8859-1) + string
	frameData := func(frameID, data string) []byte {
		raw := append([]byte{0}, []byte(data)...) // encoding byte prefix
		f := make([]byte, 10+len(raw))
		copy(f[0:4], frameID)
		f[4] = byte(len(raw) >> 24)
		f[5] = byte(len(raw) >> 16)
		f[6] = byte(len(raw) >> 8)
		f[7] = byte(len(raw))
		f[8] = 0          // flags
		f[9] = 0          // flags
		copy(f[10:], raw)
		return f
	}

	titleFrame := frameData("TIT2", title)
	artistFrame := frameData("TPE1", artist)
	albumFrame := frameData("TALB", album)

	frames := append(titleFrame, artistFrame...)
	frames = append(frames, albumFrame...)

	// ID3 size = frames + padding
	tagSize := len(frames) + padSize
	// synchsafe encoding
	id3 = append(id3, byte((tagSize>>21)&0x7f))
	id3 = append(id3, byte((tagSize>>14)&0x7f))
	id3 = append(id3, byte((tagSize>>7)&0x7f))
	id3 = append(id3, byte(tagSize&0x7f))
	id3 = append(id3, frames...)
	// padding (zeros)
	for range padSize {
		id3 = append(id3, 0)
	}

	// Append a minimal MPEG audio frame sync (silent frame)
	id3 = append(id3, 0xFF, 0xFB, 0x90, 0x00)
	for range 413 {
		id3 = append(id3, 0)
	}

	if err := os.WriteFile(path, id3, 0644); err != nil {
		t.Fatal(err)
	}
}

func createNonAudioFile(t *testing.T, path string) {
	t.Helper()
	if err := os.WriteFile(path, []byte("not an audio file"), 0644); err != nil {
		t.Fatal(err)
	}
}

// sortString tests

func TestSortString_HandlesThePrefix(t *testing.T) {
	tests := []struct {
		input, expected string
	}{
		{"The Beatles", "Beatles, The"},
		{"The Rolling Stones", "Rolling Stones, The"},
		{"THE CURE", "THE CURE"}, // case sensitive
	}
	for _, tc := range tests {
		got := sortString(tc.input)
		if got != tc.expected {
			t.Errorf("sortString(%q) = %q, want %q", tc.input, got, tc.expected)
		}
	}
}

func TestSortString_HandlesAAndAn(t *testing.T) {
	tests := []struct {
		input, expected string
	}{
		{"A Tribe Called Quest", "Tribe Called Quest, A"},
		{"An Atheist", "Atheist, An"},
	}
	for _, tc := range tests {
		got := sortString(tc.input)
		if got != tc.expected {
			t.Errorf("sortString(%q) = %q, want %q", tc.input, got, tc.expected)
		}
	}
}

func TestSortString_NoPrefix(t *testing.T) {
	got := sortString("Radiohead")
	if got != "Radiohead" {
		t.Errorf("sortString(%q) = %q, want %q", "Radiohead", got, "Radiohead")
	}
}

func TestSortString_TrimsSpaces(t *testing.T) {
	got := sortString("  The Clash  ")
	if got != "Clash, The" {
		t.Errorf("sortString(%q) = %q, want %q", "  The Clash  ", got, "Clash, The")
	}
}

func TestSortString_Empty(t *testing.T) {
	got := sortString("")
	if got != "" {
		t.Errorf("sortString(%q) = %q, want %q", "", got, "")
	}
}

// isAudioFile tests

func TestIsAudioFile_ValidExtensions(t *testing.T) {
	s := &Scanner{}
	exts := []string{"/path/to/song.mp3", "/path/to/song.m4a", "/path/to/song.flac", "/path/to/song.ogg"}
	for _, path := range exts {
		if !s.isAudioFile(path) {
			t.Errorf("isAudioFile(%q) = false, want true", path)
		}
	}
}

func TestIsAudioFile_CaseInsensitive(t *testing.T) {
	s := &Scanner{}
	if !s.isAudioFile("/path/to/song.MP3") {
		t.Error("isAudioFile should be case insensitive for .MP3")
	}
}

func TestIsAudioFile_InvalidExtensions(t *testing.T) {
	s := &Scanner{}
	invalid := []string{"/path/to/song.wav", "/path/to/song.aac", "/path/to/song.txt", "/path/to/song", "/path/to/"}
	for _, path := range invalid {
		if s.isAudioFile(path) {
			t.Errorf("isAudioFile(%q) = true, want false", path)
		}
	}
}

func TestIsAudioFile_Directory(t *testing.T) {
	s := &Scanner{}
	if s.isAudioFile("/path/to/songs") {
		t.Error("isAudioFile should return false for paths without extension")
	}
}

// Scan integration tests

func TestScan_ProcessesMP3Files(t *testing.T) {
	database := newTestDB(t)
	musicDir := t.TempDir()
	artworkDir := t.TempDir()

	createMinimalMP3(t, filepath.Join(musicDir, "song1.mp3"), "Song One", "Test Artist", "Test Album")
	createMinimalMP3(t, filepath.Join(musicDir, "song2.mp3"), "Song Two", "Test Artist", "Test Album")

	s := New(database, musicDir, artworkDir)
	if err := s.Scan(); err != nil {
		t.Fatal(err)
	}

	songs, err := database.GetSongs(1, 50)
	if err != nil {
		t.Fatal(err)
	}
	if len(songs) != 2 {
		t.Fatalf("expected 2 songs, got %d", len(songs))
	}
	titles := map[string]bool{}
	for _, s := range songs {
		titles[s.Title] = true
	}
	if !titles["Song One"] {
		t.Errorf("expected Song One in results, got %v", titles)
	}
	if !titles["Song Two"] {
		t.Errorf("expected Song Two in results, got %v", titles)
	}
}

func TestScan_SkipsNonAudioFiles(t *testing.T) {
	database := newTestDB(t)
	musicDir := t.TempDir()
	artworkDir := t.TempDir()

	createMinimalMP3(t, filepath.Join(musicDir, "valid.mp3"), "Real Song", "Artist", "Album")
	createNonAudioFile(t, filepath.Join(musicDir, "notes.txt"))
	createNonAudioFile(t, filepath.Join(musicDir, "cover.jpg"))

	s := New(database, musicDir, artworkDir)
	if err := s.Scan(); err != nil {
		t.Fatal(err)
	}

	songs, _ := database.GetSongs(1, 50)
	if len(songs) != 1 {
		t.Fatalf("expected 1 song (only mp3), got %d", len(songs))
	}
}

func TestScan_HandlesNestedDirectories(t *testing.T) {
	database := newTestDB(t)
	musicDir := t.TempDir()
	artworkDir := t.TempDir()

	subDir := filepath.Join(musicDir, "subfolder", "deeper")
	if err := os.MkdirAll(subDir, 0755); err != nil {
		t.Fatal(err)
	}

	createMinimalMP3(t, filepath.Join(subDir, "nested.mp3"), "Nested Song", "Deep Artist", "Deep Album")

	s := New(database, musicDir, artworkDir)
	if err := s.Scan(); err != nil {
		t.Fatal(err)
	}

	songs, _ := database.GetSongs(1, 50)
	if len(songs) != 1 {
		t.Fatalf("expected 1 song from nested dir, got %d", len(songs))
	}
}

func TestScan_EmptyDirectory(t *testing.T) {
	database := newTestDB(t)
	musicDir := t.TempDir()
	artworkDir := t.TempDir()

	s := New(database, musicDir, artworkDir)
	if err := s.Scan(); err != nil {
		t.Fatal(err)
	}

	songs, _ := database.GetSongs(1, 50)
	if len(songs) != 0 {
		t.Fatalf("expected 0 songs in empty dir, got %d", len(songs))
	}
}

func TestScan_IncrementalUpdate(t *testing.T) {
	database := newTestDB(t)
	musicDir := t.TempDir()
	artworkDir := t.TempDir()

	createMinimalMP3(t, filepath.Join(musicDir, "song.mp3"), "Original Title", "Artist", "Album")

	s := New(database, musicDir, artworkDir)
	if err := s.Scan(); err != nil {
		t.Fatal(err)
	}

	// Verify original
	songs, _ := database.GetSongs(1, 50)
	if len(songs) != 1 || songs[0].Title != "Original Title" {
		t.Fatalf("expected 'Original Title', got %q (len songs=%d)", songs[0].Title, len(songs))
	}

	// Modify file with updated title
	createMinimalMP3(t, filepath.Join(musicDir, "song.mp3"), "Updated Title", "Artist", "Album")
	if err := s.Scan(); err != nil {
		t.Fatal(err)
	}

	// Verify update (upsert by path)
	songs, _ = database.GetSongs(1, 50)
	if len(songs) != 1 {
		t.Fatalf("expected 1 song after update, got %d", len(songs))
	}
	if songs[0].Title != "Updated Title" {
		t.Errorf("expected 'Updated Title', got %q", songs[0].Title)
	}
}
