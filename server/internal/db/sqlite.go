package db

import (
	"database/sql"
	"fmt"

	_ "modernc.org/sqlite"
)

type Database struct {
	*sql.DB
}

func New(dbPath string) (*Database, error) {
	db, err := sql.Open("sqlite", dbPath+"?_journal_mode=WAL&_busy_timeout=5000")
	if err != nil {
		return nil, fmt.Errorf("open db: %w", err)
	}
	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("ping db: %w", err)
	}
	d := &Database{db}
	if err := d.migrate(); err != nil {
		return nil, fmt.Errorf("migrate: %w", err)
	}
	return d, nil
}

func (d *Database) migrate() error {
	schema := `
	CREATE TABLE IF NOT EXISTS artists (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		name TEXT NOT NULL UNIQUE,
		sort_name TEXT NOT NULL DEFAULT ''
	);
	CREATE TABLE IF NOT EXISTS albums (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		title TEXT NOT NULL,
		artist_id INTEGER NOT NULL REFERENCES artists(id),
		year INTEGER DEFAULT 0,
		genre TEXT DEFAULT '',
		artwork_id INTEGER DEFAULT 0,
		UNIQUE(title, artist_id)
	);
	CREATE TABLE IF NOT EXISTS songs (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		title TEXT NOT NULL,
		track_number INTEGER DEFAULT 0,
		disc_number INTEGER DEFAULT 0,
		duration REAL DEFAULT 0,
		file_format TEXT DEFAULT 'mp3',
		file_size INTEGER DEFAULT 0,
		bitrate INTEGER DEFAULT 0,
		artist_id INTEGER NOT NULL REFERENCES artists(id),
		album_id INTEGER NOT NULL REFERENCES albums(id),
		file_path TEXT NOT NULL UNIQUE
	);
	CREATE INDEX IF NOT EXISTS idx_albums_artist ON albums(artist_id);
	CREATE INDEX IF NOT EXISTS idx_songs_album ON songs(album_id);
	CREATE INDEX IF NOT EXISTS idx_songs_artist ON songs(artist_id);
	`
	_, err := d.Exec(schema)
	return err
}
