package db

import (
	"fmt"
	"os"
	"testing"
)

func newTestDB(t *testing.T) *Database {
	t.Helper()
	f, err := os.CreateTemp("", "music-test-*.db")
	if err != nil {
		t.Fatal(err)
	}
	f.Close()
	database, err := New(f.Name())
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		database.Close()
		os.Remove(f.Name())
	})
	return database
}

func seedTestData(t *testing.T, db *Database) (artistID, albumID, songID int64) {
	t.Helper()
	var err error
	artistID, err = db.UpsertArtist("Test Artist", "Artist, Test")
	if err != nil {
		t.Fatal(err)
	}
	albumID, err = db.UpsertAlbum("Test Album", artistID, 2024, "Rock")
	if err != nil {
		t.Fatal(err)
	}
	songID, err = db.UpsertSong("Test Song", 1, 1, 180.5, "mp3", 5000000, 320, artistID, albumID, "/music/test.mp3")
	if err != nil {
		t.Fatal(err)
	}
	return
}

func TestNewAndMigrate(t *testing.T) {
	db := newTestDB(t)
	if db == nil {
		t.Fatal("expected non-nil database")
	}
	var count int
	err := db.QueryRow("SELECT COUNT(*) FROM artists").Scan(&count)
	if err != nil {
		t.Fatal(err)
	}
}

// Artist tests

func TestUpsertArtist_CreatesNew(t *testing.T) {
	db := newTestDB(t)
	id, err := db.UpsertArtist("Test Artist", "Artist, Test")
	if err != nil {
		t.Fatal(err)
	}
	if id == 0 {
		t.Fatal("expected non-zero id")
	}
	artist, err := db.GetArtist(id)
	if err != nil {
		t.Fatal(err)
	}
	if artist.Name != "Test Artist" {
		t.Errorf("name = %q, want %q", artist.Name, "Test Artist")
	}
	if artist.SortName != "Artist, Test" {
		t.Errorf("sortName = %q, want %q", artist.SortName, "Artist, Test")
	}
}

func TestUpsertArtist_DeduplicatesByName(t *testing.T) {
	db := newTestDB(t)
	id1, err := db.UpsertArtist("Unique Artist", "Unique, Artist")
	if err != nil {
		t.Fatal(err)
	}
	id2, err := db.UpsertArtist("Unique Artist", "Updated Sort")
	if err != nil {
		t.Fatal(err)
	}
	if id1 != id2 {
		t.Errorf("got id %d, want %d (same artist should reuse id)", id2, id1)
	}
	artist, _ := db.GetArtist(id1)
	if artist.SortName != "Updated Sort" {
		t.Errorf("sortName after upsert = %q, want %q", artist.SortName, "Updated Sort")
	}
}

func TestGetArtist_NotFound(t *testing.T) {
	db := newTestDB(t)
	_, err := db.GetArtist(999)
	if err == nil {
		t.Fatal("expected error for non-existent artist")
	}
}

func TestGetArtists_Pagination(t *testing.T) {
	db := newTestDB(t)
	for i := range 5 {
		_, err := db.UpsertArtist(fmt.Sprintf("Artist %d", i), fmt.Sprintf("Artist, %d", i))
		if err != nil {
			t.Fatal(err)
		}
	}
	page1, err := db.GetArtists(1, 2)
	if err != nil {
		t.Fatal(err)
	}
	if len(page1) != 2 {
		t.Fatalf("expected 2 artists on page 1, got %d", len(page1))
	}
	page3, err := db.GetArtists(3, 2)
	if err != nil {
		t.Fatal(err)
	}
	if len(page3) != 1 {
		t.Fatalf("expected 1 artist on page 3, got %d", len(page3))
	}
}

func TestGetArtists_Empty(t *testing.T) {
	db := newTestDB(t)
	artists, err := db.GetArtists(1, 50)
	if err != nil {
		t.Fatal(err)
	}
	if len(artists) != 0 {
		t.Fatalf("expected 0 artists, got %d", len(artists))
	}
}

// Album tests

func TestUpsertAlbum_CreatesNew(t *testing.T) {
	db := newTestDB(t)
	artistID, _ := db.UpsertArtist("Artist", "Artist")
	id, err := db.UpsertAlbum("Album Title", artistID, 2023, "Jazz")
	if err != nil {
		t.Fatal(err)
	}
	if id == 0 {
		t.Fatal("expected non-zero id")
	}
}

func TestUpsertAlbum_DeduplicatesByTitleAndArtist(t *testing.T) {
	db := newTestDB(t)
	artistID, _ := db.UpsertArtist("Artist", "Artist")
	id1, _ := db.UpsertAlbum("Same Album", artistID, 2023, "Jazz")
	id2, _ := db.UpsertAlbum("Same Album", artistID, 2023, "Rock")
	if id1 != id2 {
		t.Errorf("expected same album id, got %d vs %d", id1, id2)
	}
}

func TestGetAlbum_NotFound(t *testing.T) {
	db := newTestDB(t)
	_, _, err := db.GetAlbum(999)
	if err == nil {
		t.Fatal("expected error for non-existent album")
	}
}

func TestGetAlbum_WithSongs(t *testing.T) {
	db := newTestDB(t)
	artistID, _ := db.UpsertArtist("Artist", "Artist")
	albumID, _ := db.UpsertAlbum("Album", artistID, 2024, "Pop")
	db.UpsertSong("Song 1", 1, 1, 100, "mp3", 1000, 128, artistID, albumID, "/m/s1.mp3")
	db.UpsertSong("Song 2", 2, 1, 200, "mp3", 2000, 256, artistID, albumID, "/m/s2.mp3")

	album, songs, err := db.GetAlbum(albumID)
	if err != nil {
		t.Fatal(err)
	}
	if album.Title != "Album" {
		t.Errorf("album title = %q", album.Title)
	}
	if len(songs) != 2 {
		t.Fatalf("expected 2 songs, got %d", len(songs))
	}
	if songs[0].Title != "Song 1" || songs[1].Title != "Song 2" {
		t.Errorf("songs ordered incorrectly")
	}
}

func TestGetAlbums_Empty(t *testing.T) {
	db := newTestDB(t)
	albums, err := db.GetAlbums(1, 50)
	if err != nil {
		t.Fatal(err)
	}
	if len(albums) != 0 {
		t.Fatalf("expected 0 albums, got %d", len(albums))
	}
}

// Song tests

func TestUpsertSong_CreatesNew(t *testing.T) {
	db := newTestDB(t)
	artistID, _ := db.UpsertArtist("Artist", "Artist")
	albumID, _ := db.UpsertAlbum("Album", artistID, 2024, "Pop")
	id, err := db.UpsertSong("Song", 1, 1, 200, "mp3", 3000, 192, artistID, albumID, "/m/song.mp3")
	if err != nil {
		t.Fatal(err)
	}
	if id == 0 {
		t.Fatal("expected non-zero id")
	}
}

func TestUpsertSong_DeduplicatesByFilePath(t *testing.T) {
	db := newTestDB(t)
	artistID, _ := db.UpsertArtist("Artist", "Artist")
	albumID, _ := db.UpsertAlbum("Album", artistID, 2024, "Pop")
	id1, _ := db.UpsertSong("Song", 1, 1, 200, "mp3", 3000, 192, artistID, albumID, "/m/song.mp3")
	id2, _ := db.UpsertSong("Song Updated", 1, 1, 210, "mp3", 3100, 256, artistID, albumID, "/m/song.mp3")
	if id1 != id2 {
		t.Errorf("expected same song id for same path, got %d vs %d", id1, id2)
	}
	// Verify updated fields
	got, _ := db.GetSong(id1)
	if got.Title != "Song Updated" {
		t.Errorf("title after upsert = %q", got.Title)
	}
}

func TestGetSong_WithJoins(t *testing.T) {
	db := newTestDB(t)
	artistID, _ := db.UpsertArtist("Test Artist", "Artist, Test")
	albumID, _ := db.UpsertAlbum("Test Album", artistID, 2024, "Rock")
	songID, _ := db.UpsertSong("Test Song", 1, 1, 180, "mp3", 5000, 320, artistID, albumID, "/m/test.mp3")

	song, err := db.GetSong(songID)
	if err != nil {
		t.Fatal(err)
	}
	if song.ArtistName != "Test Artist" {
		t.Errorf("artist name = %q, want %q", song.ArtistName, "Test Artist")
	}
	if song.AlbumTitle != "Test Album" {
		t.Errorf("album title = %q, want %q", song.AlbumTitle, "Test Album")
	}
}

func TestGetSong_NotFound(t *testing.T) {
	db := newTestDB(t)
	_, err := db.GetSong(999)
	if err == nil {
		t.Fatal("expected error for non-existent song")
	}
}

func TestGetSongs_Pagination(t *testing.T) {
	db := newTestDB(t)
	artistID, _ := db.UpsertArtist("Artist", "Artist")
	albumID, _ := db.UpsertAlbum("Album", artistID, 2024, "Pop")
	for i := range 10 {
		db.UpsertSong(fmt.Sprintf("Song %d", i), i+1, 1, 100, "mp3", 1000, 128, artistID, albumID, fmt.Sprintf("/m/s%d.mp3", i))
	}

	page, err := db.GetSongs(1, 3)
	if err != nil {
		t.Fatal(err)
	}
	if len(page) != 3 {
		t.Fatalf("expected 3 songs on page 1, got %d", len(page))
	}
}

// Search tests

func TestSearch_FindsSongsAlbumsArtists(t *testing.T) {
	db := newTestDB(t)
	artistID, _ := db.UpsertArtist("Daft Punk", "Punk, Daft")
	albumID, _ := db.UpsertAlbum("Random Access Memories", artistID, 2013, "Electronic")
	db.UpsertSong("Get Lucky", 1, 1, 369, "mp3", 8000000, 320, artistID, albumID, "/m/gl.mp3")

	result, err := db.Search("Daft")
	if err != nil {
		t.Fatal(err)
	}
	if len(result.Artists) == 0 {
		t.Error("expected artists in search results")
	}
	if len(result.Songs) == 0 {
		t.Error("expected songs in search results")
	}
}

func TestSearch_FindsByAlbumTitle(t *testing.T) {
	db := newTestDB(t)
	artistID, _ := db.UpsertArtist("Some Artist", "Artist, Some")
	albumID, _ := db.UpsertAlbum("Random Access Memories", artistID, 2013, "Electronic")
	db.UpsertSong("Touch", 1, 1, 500, "mp3", 1000000, 320, artistID, albumID, "/m/touch.mp3")

	result, err := db.Search("Random")
	if err != nil {
		t.Fatal(err)
	}
	if len(result.Albums) == 0 {
		t.Error("expected albums in search results")
	}
	if len(result.Songs) == 0 {
		t.Error("expected songs in search results")
	}
}

func TestSearch_NoResults(t *testing.T) {
	db := newTestDB(t)
	result, err := db.Search("zzzznonexistent")
	if err != nil {
		t.Fatal(err)
	}
	if len(result.Artists) != 0 || len(result.Albums) != 0 || len(result.Songs) != 0 {
		t.Error("expected empty search results")
	}
}

// Stats tests

func TestGetStats(t *testing.T) {
	db := newTestDB(t)
	artistID, _ := db.UpsertArtist("A", "A")
	albumID, _ := db.UpsertAlbum("Al", artistID, 2024, "R")
	db.UpsertSong("S1", 1, 1, 100, "mp3", 1000, 128, artistID, albumID, "/m/s1.mp3")
	db.UpsertSong("S2", 2, 1, 200, "mp3", 2000, 128, artistID, albumID, "/m/s2.mp3")

	stats, err := db.GetStats()
	if err != nil {
		t.Fatal(err)
	}
	if stats.SongCount != 2 {
		t.Errorf("song count = %d, want 2", stats.SongCount)
	}
	if stats.AlbumCount != 1 {
		t.Errorf("album count = %d, want 1", stats.AlbumCount)
	}
	if stats.ArtistCount != 1 {
		t.Errorf("artist count = %d, want 1", stats.ArtistCount)
	}
	if stats.TotalDuration != 300 {
		t.Errorf("total duration = %f, want 300", stats.TotalDuration)
	}
	if stats.TotalSize != 3000 {
		t.Errorf("total size = %d, want 3000", stats.TotalSize)
	}
}

func TestGetStats_EmptyDatabase(t *testing.T) {
	db := newTestDB(t)
	stats, err := db.GetStats()
	if err != nil {
		t.Fatal(err)
	}
	if stats.SongCount != 0 || stats.AlbumCount != 0 || stats.ArtistCount != 0 {
		t.Error("expected zeros in empty database stats")
	}
}

// Artwork tests

func TestSetAlbumArtwork(t *testing.T) {
	db := newTestDB(t)
	artistID, _ := db.UpsertArtist("A", "A")
	albumID, _ := db.UpsertAlbum("Al", artistID, 2024, "R")
	err := db.SetAlbumArtwork(albumID, "/path/to/art.jpg")
	if err != nil {
		t.Fatal(err)
	}
	// Verify has_artwork flag
	album, _, _ := db.GetAlbum(albumID)
	if !album.HasArtwork {
		t.Error("expected HasArtwork to be true after SetAlbumArtwork")
	}
}

// Edge cases

func TestConsecutiveOperations(t *testing.T) {
	db := newTestDB(t)
	aID, _ := db.UpsertArtist("Artist", "Artist")
	alID, _ := db.UpsertAlbum("Album", aID, 2024, "Pop")
	sID, _ := db.UpsertSong("Song", 1, 1, 100, "mp3", 100, 128, aID, alID, "/m/s.mp3")

	song, _ := db.GetSong(sID)
	if song == nil {
		t.Fatal("expected song")
	}
	album, songs, _ := db.GetAlbum(alID)
	if album == nil {
		t.Fatal("expected album")
	}
	if len(songs) != 1 {
		t.Fatalf("expected 1 song, got %d", len(songs))
	}
	artist, _ := db.GetArtist(aID)
	if artist.AlbumCount != 1 {
		t.Errorf("album count = %d, want 1", artist.AlbumCount)
	}
}

func TestMultipleAlbumsPerArtist(t *testing.T) {
	db := newTestDB(t)
	artistID, _ := db.UpsertArtist("Prolific Artist", "Artist, Prolific")
	db.UpsertAlbum("Album One", artistID, 2020, "Rock")
	db.UpsertAlbum("Album Two", artistID, 2021, "Pop")

	artist, _ := db.GetArtist(artistID)
	if artist.AlbumCount != 2 {
		t.Errorf("album count = %d, want 2", artist.AlbumCount)
	}
}

func TestSongsOrderedByDiscAndTrack(t *testing.T) {
	db := newTestDB(t)
	aID, _ := db.UpsertArtist("A", "A")
	alID, _ := db.UpsertAlbum("Al", aID, 2024, "R")
	db.UpsertSong("S3", 3, 2, 100, "mp3", 100, 128, aID, alID, "/m/s3.mp3")
	db.UpsertSong("S1", 1, 1, 100, "mp3", 100, 128, aID, alID, "/m/s1.mp3")
	db.UpsertSong("S2", 2, 1, 100, "mp3", 100, 128, aID, alID, "/m/s2.mp3")

	_, songs, _ := db.GetAlbum(alID)
	if songs[0].Title != "S1" || songs[1].Title != "S2" || songs[2].Title != "S3" {
		t.Errorf("songs not in correct order: %v", songs)
	}
}

func TestGetAlbums_ReturnsArtistName(t *testing.T) {
	db := newTestDB(t)
	aID, _ := db.UpsertArtist("My Artist", "Artist, My")
	db.UpsertAlbum("My Album", aID, 2024, "Rock")
	albums, _ := db.GetAlbums(1, 50)
	if len(albums) > 0 && albums[0].ArtistName != "My Artist" {
		t.Errorf("artist name = %q, want %q", albums[0].ArtistName, "My Artist")
	}
}
