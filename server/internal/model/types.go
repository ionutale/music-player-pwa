package model

type Artist struct {
	ID         int64  `json:"id"`
	Name       string `json:"name"`
	SortName   string `json:"sort_name"`
	AlbumCount int    `json:"album_count"`
}

type Album struct {
	ID         int64   `json:"id"`
	Title      string  `json:"title"`
	ArtistID   int64   `json:"artist_id"`
	ArtistName string  `json:"artist_name"`
	Year       int     `json:"year"`
	Genre      string  `json:"genre"`
	SongCount  int     `json:"song_count"`
	Duration   float64 `json:"duration"`
	HasArtwork bool    `json:"has_artwork"`
}

type Song struct {
	ID          int64   `json:"id"`
	Title       string  `json:"title"`
	TrackNumber int     `json:"track_number"`
	DiscNumber  int     `json:"disc_number"`
	Duration    float64 `json:"duration"`
	FileFormat  string  `json:"file_format"`
	FileSize    int64   `json:"file_size"`
	Bitrate     int     `json:"bitrate"`
	ArtistID    int64   `json:"artist_id"`
	ArtistName  string  `json:"artist_name"`
	AlbumID     int64   `json:"album_id"`
	AlbumTitle  string  `json:"album_title"`
	FilePath    string  `json:"file_path"`
}

type SearchResult struct {
	Songs   []Song   `json:"songs"`
	Albums  []Album  `json:"albums"`
	Artists []Artist `json:"artists"`
}

type Stats struct {
	SongCount     int     `json:"song_count"`
	AlbumCount    int     `json:"album_count"`
	ArtistCount   int     `json:"artist_count"`
	TotalDuration float64 `json:"total_duration"`
	TotalSize     int64   `json:"total_size"`
}
