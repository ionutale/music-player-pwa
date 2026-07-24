import XCTest
@testable import MusicPlayer

final class SongTests: XCTestCase {
    func testFormattedDuration() {
        let song = Song(id: 1, title: "Test", trackNumber: 1, discNumber: 1,
                       duration: 245.5, fileFormat: "mp3", fileSize: 1000,
                       bitrate: 320, artistId: 1, artistName: "A",
                       albumId: 1, albumTitle: "Al", filePath: "/m/t.mp3")
        XCTAssertEqual(song.formattedDuration, "4:05")
    }

    func testFormattedDuration_Zero() {
        let song = Song(id: 1, title: "T", trackNumber: 1, discNumber: 1,
                       duration: 0, fileFormat: "mp3", fileSize: 0,
                       bitrate: 0, artistId: 1, artistName: "A",
                       albumId: 1, albumTitle: "Al", filePath: "/m/t.mp3")
        XCTAssertEqual(song.formattedDuration, "0:00")
    }

    func testFormattedDuration_ShortSong() {
        let song = Song(id: 1, title: "T", trackNumber: 1, discNumber: 1,
                       duration: 7, fileFormat: "mp3", fileSize: 0,
                       bitrate: 0, artistId: 1, artistName: "A",
                       albumId: 1, albumTitle: "Al", filePath: "/m/t.mp3")
        XCTAssertEqual(song.formattedDuration, "0:07")
    }

    func testSongDecoding() throws {
        let data = """
        {
            "id": 1, "title": "Test", "track_number": 1, "disc_number": 1,
            "duration": 200.0, "file_format": "mp3", "file_size": 1000, "bitrate": 128,
            "artist_id": 1, "artist_name": "Test Artist",
            "album_id": 1, "album_title": "Test Album",
            "file_path": "/music/test.mp3"
        }
        """.data(using: .utf8)!
        let song = try JSONDecoder().decode(Song.self, from: data)
        XCTAssertEqual(song.title, "Test")
        XCTAssertEqual(song.artistName, "Test Artist")
        XCTAssertEqual(song.albumTitle, "Test Album")
    }

    func testSongDecoding_MinimalFields() throws {
        let data = """
        {"id": 1, "title": "S", "track_number": 0, "disc_number": 0,
         "duration": 0, "file_format": "mp3", "file_size": 0, "bitrate": 0,
         "artist_id": 0, "artist_name": "", "album_id": 0, "album_title": "",
         "file_path": ""}
        """.data(using: .utf8)!
        let song = try JSONDecoder().decode(Song.self, from: data)
        XCTAssertEqual(song.title, "S")
    }

    func testSongIdentifiable() {
        let s1 = Song(id: 1, title: "S1", trackNumber: 1, discNumber: 1,
                      duration: 100, fileFormat: "mp3", fileSize: 100,
                      bitrate: 128, artistId: 1, artistName: "A",
                      albumId: 1, albumTitle: "Al", filePath: "/m/s1.mp3")
        let s2 = Song(id: 1, title: "S1", trackNumber: 1, discNumber: 1,
                      duration: 100, fileFormat: "mp3", fileSize: 100,
                      bitrate: 128, artistId: 1, artistName: "A",
                      albumId: 1, albumTitle: "Al", filePath: "/m/s1.mp3")
        XCTAssertEqual(s1.id, s2.id)
    }
}

final class AlbumTests: XCTestCase {
    func testAlbumDecoding() throws {
        let data = """
        {"id": 1, "title": "Album", "artist_id": 1, "artist_name": "Artist",
         "year": 2024, "genre": "Rock", "song_count": 10, "duration": 3600.0, "has_artwork": true}
        """.data(using: .utf8)!
        let album = try JSONDecoder().decode(Album.self, from: data)
        XCTAssertEqual(album.title, "Album")
        XCTAssertEqual(album.year, 2024)
        XCTAssertTrue(album.hasArtwork)
    }
}

final class ArtistTests: XCTestCase {
    func testArtistDecoding() throws {
        let data = """
        {"id": 1, "name": "Artist", "sort_name": "Artist", "album_count": 5}
        """.data(using: .utf8)!
        let artist = try JSONDecoder().decode(Artist.self, from: data)
        XCTAssertEqual(artist.name, "Artist")
        XCTAssertEqual(artist.albumCount, 5)
    }
}

final class SearchResultTests: XCTestCase {
    func testSearchResultDecoding() throws {
        let data = """
        {"songs": [], "albums": [], "artists": []}
        """.data(using: .utf8)!
        let result = try JSONDecoder().decode(SearchResult.self, from: data)
        XCTAssertTrue(result.songs.isEmpty)
        XCTAssertTrue(result.albums.isEmpty)
        XCTAssertTrue(result.artists.isEmpty)
    }
}

final class LibraryStatsTests: XCTestCase {
    func testStatsDecoding() throws {
        let data = """
        {"song_count": 100, "album_count": 20, "artist_count": 10, "total_duration": 7200.0, "total_size": 500000000}
        """.data(using: .utf8)!
        let stats = try JSONDecoder().decode(LibraryStats.self, from: data)
        XCTAssertEqual(stats.songCount, 100)
        XCTAssertEqual(stats.artistCount, 10)
    }
}

final class AlbumDetailResponseTests: XCTestCase {
    func testDecoding() throws {
        let data = albumDetailJSON
        let response = try JSONDecoder().decode(AlbumDetailResponse.self, from: data)
        XCTAssertEqual(response.album.title, "Test Album")
        XCTAssertEqual(response.songs.count, 1)
    }
}

final class ArtistDetailResponseTests: XCTestCase {
    func testDecoding() throws {
        let data = artistDetailJSON
        let response = try JSONDecoder().decode(ArtistDetailResponse.self, from: data)
        XCTAssertEqual(response.artist.name, "Test Artist")
        XCTAssertEqual(response.albums.count, 1)
    }
}

final class TimeIntervalExtensionTests: XCTestCase {
    func testFormattedTime() {
        XCTAssertEqual(TimeInterval(0).formattedTime, "0:00")
        XCTAssertEqual(TimeInterval(65).formattedTime, "1:05")
        XCTAssertEqual(TimeInterval(3661).formattedTime, "61:01")
    }
}
