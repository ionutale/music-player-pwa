import Foundation
@testable import MusicPlayer

let testSong = Song(
    id: 1,
    title: "Test Song",
    trackNumber: 1,
    discNumber: 1,
    duration: 200.5,
    fileFormat: "mp3",
    fileSize: 5000000,
    bitrate: 320,
    artistId: 1,
    artistName: "Test Artist",
    albumId: 1,
    albumTitle: "Test Album",
    filePath: "/music/test.mp3"
)

let testAlbum = Album(
    id: 1,
    title: "Test Album",
    artistId: 1,
    artistName: "Test Artist",
    year: 2024,
    genre: "Rock",
    songCount: 1,
    duration: 200.5,
    hasArtwork: true
)

let testArtist = Artist(
    id: 1,
    name: "Test Artist",
    sortName: "Artist, Test",
    albumCount: 1
)

func makeMockJSON(_ value: Any) -> Data {
    try! JSONSerialization.data(withJSONObject: value, options: [])
}

let songsJSON = """
[
  {
    "id": 1, "title": "Test Song", "track_number": 1, "disc_number": 1,
    "duration": 200.5, "file_format": "mp3", "file_size": 5000000, "bitrate": 320,
    "artist_id": 1, "artist_name": "Test Artist",
    "album_id": 1, "album_title": "Test Album",
    "file_path": "/music/test.mp3"
  }
]
""".data(using: .utf8)!

let albumsJSON = """
[
  {
    "id": 1, "title": "Test Album", "artist_id": 1, "artist_name": "Test Artist",
    "year": 2024, "genre": "Rock", "song_count": 1, "duration": 200.5, "has_artwork": true
  }
]
""".data(using: .utf8)!

let artistsJSON = """
[
  {
    "id": 1, "name": "Test Artist", "sort_name": "Artist, Test", "album_count": 1
  }
]
""".data(using: .utf8)!

let albumDetailJSON = """
{
  "album": { "id": 1, "title": "Test Album", "artist_id": 1, "artist_name": "Test Artist", "year": 2024, "genre": "Rock", "song_count": 1, "duration": 200.5, "has_artwork": true },
  "songs": [{"id": 1, "title": "Test Song", "track_number": 1, "disc_number": 1, "duration": 200.5, "file_format": "mp3", "file_size": 5000000, "bitrate": 320, "artist_id": 1, "artist_name": "Test Artist", "album_id": 1, "album_title": "Test Album", "file_path": "/music/test.mp3"}]
}
""".data(using: .utf8)!

let artistDetailJSON = """
{
  "artist": { "id": 1, "name": "Test Artist", "sort_name": "Artist, Test", "album_count": 1 },
  "albums": [{"id": 1, "title": "Test Album", "artist_id": 1, "artist_name": "Test Artist", "year": 2024, "genre": "Rock", "song_count": 1, "duration": 200.5, "has_artwork": true}]
}
""".data(using: .utf8)!

let searchResultJSON = """
{
  "songs": [{"id": 1, "title": "Test Song", "track_number": 1, "disc_number": 1, "duration": 200.5, "file_format": "mp3", "file_size": 5000000, "bitrate": 320, "artist_id": 1, "artist_name": "Test Artist", "album_id": 1, "album_title": "Test Album", "file_path": "/music/test.mp3"}],
  "albums": [{"id": 1, "title": "Test Album", "artist_id": 1, "artist_name": "Test Artist", "year": 2024, "genre": "Rock", "song_count": 1, "duration": 200.5, "has_artwork": true}],
  "artists": [{"id": 1, "name": "Test Artist", "sort_name": "Artist, Test", "album_count": 1}]
}
""".data(using: .utf8)!

let statsJSON = """
{
  "song_count": 10, "album_count": 2, "artist_count": 3, "total_duration": 3600.0, "total_size": 100000000
}
""".data(using: .utf8)!

let scanResponseJSON = """
{"status": "started"}
""".data(using: .utf8)!
