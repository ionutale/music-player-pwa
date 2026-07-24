package scanner

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"

	"github.com/dhowden/tag"
	"music-server/internal/db"
)

type Scanner struct {
	db         *db.Database
	musicDir   string
	artworkDir string
}

func New(database *db.Database, musicDir, artworkDir string) *Scanner {
	return &Scanner{db: database, musicDir: musicDir, artworkDir: artworkDir}
}

func (s *Scanner) Scan() error {
	if err := os.MkdirAll(s.artworkDir, 0755); err != nil {
		return fmt.Errorf("create artwork dir: %w", err)
	}
	count := 0
	err := filepath.Walk(s.musicDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() || !s.isAudioFile(path) {
			return nil
		}
		if err := s.processFile(path); err != nil {
			log.Printf("error processing %s: %v", path, err)
		} else {
			count++
		}
		return nil
	})
	log.Printf("scan complete: %d files processed", count)
	return err
}

func (s *Scanner) isAudioFile(path string) bool {
	ext := strings.ToLower(filepath.Ext(path))
	return ext == ".mp3" || ext == ".m4a" || ext == ".flac" || ext == ".ogg"
}

func (s *Scanner) processFile(path string) error {
	f, err := os.Open(path)
	if err != nil {
		return err
	}
	defer f.Close()

	meta, err := tag.ReadFrom(f)
	if err != nil {
		return fmt.Errorf("read tags: %w", err)
	}

	artistName := meta.Artist()
	if artistName == "" {
		artistName = "Unknown Artist"
	}
	albumTitle := meta.Album()
	if albumTitle == "" {
		albumTitle = "Unknown Album"
	}
	songTitle := meta.Title()
	if songTitle == "" {
		songTitle = filepath.Base(path)
	}

	sortName := sortString(artistName)

	artistID, err := s.db.UpsertArtist(artistName, sortName)
	if err != nil {
		return fmt.Errorf("upsert artist: %w", err)
	}

	year := meta.Year()
	genre := meta.Genre()

	albumID, err := s.db.UpsertAlbum(albumTitle, artistID, year, genre)
	if err != nil {
		return fmt.Errorf("upsert album: %w", err)
	}

	trackNum, _ := meta.Track()
	discNum, _ := meta.Disc()
	duration := 0.0
	bitrate := 0

	info, _ := f.Stat()
	fileSize := info.Size()
	ext := strings.TrimPrefix(filepath.Ext(path), ".")

	songID, err := s.db.UpsertSong(
		songTitle, trackNum, discNum, duration, ext, fileSize, bitrate,
		artistID, albumID, path)
	if err != nil {
		return fmt.Errorf("upsert song: %w", err)
	}
	_ = songID

	artwork := meta.Picture()
	if artwork != nil {
		artPath := filepath.Join(s.artworkDir, fmt.Sprintf("%d.jpg", albumID))
		if err := os.WriteFile(artPath, artwork.Data, 0644); err == nil {
			s.db.SetAlbumArtwork(albumID, artPath)
		}
	}

	return nil
}

func sortString(s string) string {
	s = strings.TrimSpace(s)
	for _, prefix := range []string{"The ", "A ", "An "} {
		if strings.HasPrefix(s, prefix) {
			return s[len(prefix):] + ", " + strings.TrimSuffix(prefix, " ")
		}
	}
	return s
}
