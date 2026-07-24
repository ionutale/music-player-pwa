package db

import (
	"database/sql"
	"music-server/internal/model"
)

func (d *Database) GetSongs(page, limit int) ([]model.Song, error) {
	offset := (page - 1) * limit
	rows, err := d.Query(`
		SELECT s.id, s.title, s.track_number, s.disc_number, s.duration,
		       s.file_format, s.file_size, s.bitrate,
		       s.artist_id, a.name, s.album_id, al.title, s.file_path
		FROM songs s
		JOIN artists a ON a.id = s.artist_id
		JOIN albums al ON al.id = s.album_id
		ORDER BY a.sort_name, s.disc_number, s.track_number
		LIMIT ? OFFSET ?`, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanSongs(rows)
}

func (d *Database) GetSong(id int64) (*model.Song, error) {
	row := d.QueryRow(`
		SELECT s.id, s.title, s.track_number, s.disc_number, s.duration,
		       s.file_format, s.file_size, s.bitrate,
		       s.artist_id, a.name, s.album_id, al.title, s.file_path
		FROM songs s
		JOIN artists a ON a.id = s.artist_id
		JOIN albums al ON al.id = s.album_id
		WHERE s.id = ?`, id)
	return scanSong(row)
}

func (d *Database) GetAlbums(page, limit int) ([]model.Album, error) {
	offset := (page - 1) * limit
	rows, err := d.Query(`
		SELECT al.id, al.title, al.artist_id, a.name, al.year, al.genre,
		       COUNT(s.id) as song_count,
		       COALESCE(SUM(s.duration), 0) as duration,
		       CASE WHEN al.artwork_id > 0 THEN 1 ELSE 0 END
		FROM albums al
		JOIN artists a ON a.id = al.artist_id
		LEFT JOIN songs s ON s.album_id = al.id
		GROUP BY al.id
		ORDER BY al.year DESC, al.title
		LIMIT ? OFFSET ?`, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanAlbums(rows)
}

func (d *Database) GetAlbum(id int64) (*model.Album, []model.Song, error) {
	row := d.QueryRow(`
		SELECT al.id, al.title, al.artist_id, a.name, al.year, al.genre,
		       (SELECT COUNT(*) FROM songs WHERE album_id = al.id),
		       COALESCE((SELECT SUM(duration) FROM songs WHERE album_id = al.id), 0),
		       CASE WHEN al.artwork_id > 0 THEN 1 ELSE 0 END
		FROM albums al
		JOIN artists a ON a.id = al.artist_id
		WHERE al.id = ?`, id)
	album, err := scanAlbum(row)
	if err != nil {
		return nil, nil, err
	}
	rows, err := d.Query(`
		SELECT s.id, s.title, s.track_number, s.disc_number, s.duration,
		       s.file_format, s.file_size, s.bitrate,
		       s.artist_id, a.name, s.album_id, al.title, s.file_path
		FROM songs s
		JOIN artists a ON a.id = s.artist_id
		JOIN albums al ON al.id = s.album_id
		WHERE s.album_id = ?
		ORDER BY s.disc_number, s.track_number`, id)
	if err != nil {
		return nil, nil, err
	}
	defer rows.Close()
	songs, err := scanSongs(rows)
	if err != nil {
		return nil, nil, err
	}
	return album, songs, nil
}

func (d *Database) GetArtists(page, limit int) ([]model.Artist, error) {
	offset := (page - 1) * limit
	rows, err := d.Query(`
		SELECT a.id, a.name, a.sort_name, COUNT(al.id)
		FROM artists a
		LEFT JOIN albums al ON al.artist_id = a.id
		GROUP BY a.id
		ORDER BY a.sort_name
		LIMIT ? OFFSET ?`, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanArtists(rows)
}

func (d *Database) GetArtist(id int64) (*model.Artist, error) {
	row := d.QueryRow(`
		SELECT a.id, a.name, a.sort_name, (SELECT COUNT(*) FROM albums WHERE artist_id = a.id)
		FROM artists a WHERE a.id = ?`, id)
	return scanArtist(row)
}

func (d *Database) Search(query string) (*model.SearchResult, error) {
	like := "%" + query + "%"
	result := &model.SearchResult{}

	songs, err := d.Query(`
		SELECT s.id, s.title, s.track_number, s.disc_number, s.duration,
		       s.file_format, s.file_size, s.bitrate,
		       s.artist_id, a.name, s.album_id, al.title, s.file_path
		FROM songs s
		JOIN artists a ON a.id = s.artist_id
		JOIN albums al ON al.id = s.album_id
		WHERE s.title LIKE ? OR a.name LIKE ? OR al.title LIKE ?
		LIMIT 50`, like, like, like)
	if err != nil {
		return nil, err
	}
	defer songs.Close()
	result.Songs, _ = scanSongs(songs)

	albums, err := d.Query(`
		SELECT al.id, al.title, al.artist_id, a.name, al.year, al.genre,
		       (SELECT COUNT(*) FROM albums WHERE artist_id = a.id),
		       COALESCE((SELECT SUM(duration) FROM songs WHERE album_id = al.id), 0),
		       CASE WHEN al.artwork_id > 0 THEN 1 ELSE 0 END
		FROM albums al
		JOIN artists a ON a.id = al.artist_id
		WHERE al.title LIKE ? OR a.name LIKE ?
		LIMIT 25`, like, like)
	if err != nil {
		return nil, err
	}
	defer albums.Close()
	result.Albums, _ = scanAlbums(albums)

	artists, err := d.Query(`
		SELECT a.id, a.name, a.sort_name,
		       (SELECT COUNT(*) FROM albums WHERE artist_id = a.id)
		FROM artists a
		WHERE a.name LIKE ?
		LIMIT 25`, like)
	if err != nil {
		return nil, err
	}
	defer artists.Close()
	result.Artists, _ = scanArtists(artists)

	return result, nil
}

func (d *Database) GetStats() (*model.Stats, error) {
	row := d.QueryRow(`
		SELECT
			(SELECT COUNT(*) FROM songs),
			(SELECT COUNT(*) FROM albums),
			(SELECT COUNT(*) FROM artists),
			COALESCE((SELECT SUM(duration) FROM songs), 0),
			COALESCE((SELECT SUM(file_size) FROM songs), 0)`)
	s := &model.Stats{}
	err := row.Scan(&s.SongCount, &s.AlbumCount, &s.ArtistCount, &s.TotalDuration, &s.TotalSize)
	if err != nil {
		return nil, err
	}
	return s, nil
}

func (d *Database) UpsertArtist(name, sortName string) (int64, error) {
	var id int64
	err := d.QueryRow(
		`INSERT INTO artists(name, sort_name) VALUES (?, ?)
		 ON CONFLICT(name) DO UPDATE SET sort_name=excluded.sort_name
		 RETURNING id`, name, sortName).Scan(&id)
	return id, err
}

func (d *Database) UpsertAlbum(title string, artistID int64, year int, genre string) (int64, error) {
	var id int64
	err := d.QueryRow(
		`INSERT INTO albums(title, artist_id, year, genre) VALUES (?, ?, ?, ?)
		 ON CONFLICT(title, artist_id) DO UPDATE SET year=excluded.year, genre=excluded.genre
		 RETURNING id`, title, artistID, year, genre).Scan(&id)
	return id, err
}

func (d *Database) UpsertSong(title string, trackNumber, discNumber int, duration float64,
	fileFormat string, fileSize int64, bitrate int, artistID, albumID int64, filePath string) (int64, error) {
	var id int64
	err := d.QueryRow(
		`INSERT INTO songs(title, track_number, disc_number, duration, file_format, file_size, bitrate, artist_id, album_id, file_path)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		 ON CONFLICT(file_path) DO UPDATE SET
		   title=excluded.title, track_number=excluded.track_number, disc_number=excluded.disc_number,
		   duration=excluded.duration, file_format=excluded.file_format, file_size=excluded.file_size,
		   bitrate=excluded.bitrate, artist_id=excluded.artist_id, album_id=excluded.album_id
		 RETURNING id`,
		title, trackNumber, discNumber, duration, fileFormat, fileSize, bitrate, artistID, albumID, filePath).Scan(&id)
	return id, err
}

func (d *Database) SetAlbumArtwork(albumID int64, artworkPath string) error {
	_, err := d.Exec(`UPDATE albums SET artwork_id = ? WHERE id = ?`, 1, albumID)
	return err
}

func scanSongs(rows *sql.Rows) ([]model.Song, error) {
	var songs []model.Song
	for rows.Next() {
		s, err := scanSongWriter(rows)
		if err != nil {
			return nil, err
		}
		songs = append(songs, *s)
	}
	return songs, rows.Err()
}

func scanSongWriter(row interface{ Scan(...any) error }) (*model.Song, error) {
	s := &model.Song{}
	err := row.Scan(&s.ID, &s.Title, &s.TrackNumber, &s.DiscNumber, &s.Duration,
		&s.FileFormat, &s.FileSize, &s.Bitrate,
		&s.ArtistID, &s.ArtistName, &s.AlbumID, &s.AlbumTitle, &s.FilePath)
	return s, err
}

func scanSong(row *sql.Row) (*model.Song, error) {
	return scanSongWriter(row)
}

func scanAlbums(rows *sql.Rows) ([]model.Album, error) {
	var albums []model.Album
	for rows.Next() {
		a, err := scanAlbumWriter(rows)
		if err != nil {
			return nil, err
		}
		albums = append(albums, *a)
	}
	return albums, rows.Err()
}

func scanAlbumWriter(row interface{ Scan(...any) error }) (*model.Album, error) {
	a := &model.Album{}
	var hasArtwork int
	err := row.Scan(&a.ID, &a.Title, &a.ArtistID, &a.ArtistName, &a.Year, &a.Genre,
		&a.SongCount, &a.Duration, &hasArtwork)
	a.HasArtwork = hasArtwork == 1
	return a, err
}

func scanAlbum(row *sql.Row) (*model.Album, error) {
	return scanAlbumWriter(row)
}

func scanArtists(rows *sql.Rows) ([]model.Artist, error) {
	var artists []model.Artist
	for rows.Next() {
		a, err := scanArtistWriter(rows)
		if err != nil {
			return nil, err
		}
		artists = append(artists, *a)
	}
	return artists, rows.Err()
}

func scanArtistWriter(row interface{ Scan(...any) error }) (*model.Artist, error) {
	a := &model.Artist{}
	err := row.Scan(&a.ID, &a.Name, &a.SortName, &a.AlbumCount)
	return a, err
}

func scanArtist(row *sql.Row) (*model.Artist, error) {
	return scanArtistWriter(row)
}
