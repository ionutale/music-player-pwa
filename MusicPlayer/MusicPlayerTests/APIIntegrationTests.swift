import XCTest
@testable import MusicPlayer

final class APIIntegrationTests: XCTestCase {
    var apiClient: APIClient!
    var baseURL: URL!

    override func setUp() {
        super.setUp()
        baseURL = URL(string: "http://localhost:8080")!
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        apiClient = APIClient(baseURL: baseURL, apiKey: "test-key", session: URLSession(configuration: config))
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        apiClient = nil
        super.tearDown()
    }

    // MARK: - Full Library Load Flow

    func testFullLibraryLoadFlow() async throws {
        var requestCount = 0
        MockURLProtocol.requestHandler = { request in
            requestCount += 1
            switch request.url!.path {
            case "/api/songs":
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, songsJSON)
            case "/api/albums":
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, albumsJSON)
            case "/api/artists":
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, artistsJSON)
            case "/api/stats":
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, statsJSON)
            default:
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }
        }

        async let songs = apiClient.getSongs()
        async let albums = apiClient.getAlbums()
        async let artists = apiClient.getArtists()
        async let stats = apiClient.getStats()

        let (s, al, ar, st) = try await (songs, albums, artists, stats)

        XCTAssertEqual(s.count, 1)
        XCTAssertEqual(al.count, 1)
        XCTAssertEqual(ar.count, 1)
        XCTAssertEqual(st.songCount, 10)
        XCTAssertEqual(requestCount, 4)
    }

    // MARK: - Search Then Detail Flow

    func testSearchThenAlbumDetailFlow() async throws {
        var paths: [String] = []
        MockURLProtocol.requestHandler = { request in
            paths.append(request.url!.path)
            if request.url!.path == "/api/search" {
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, searchResultJSON)
            }
            if request.url!.path == "/api/albums/1" {
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, albumDetailJSON)
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
        }

        let searchResult = try await apiClient.search(query: "Test")
        XCTAssertEqual(searchResult.albums.count, 1)

        let albumId = searchResult.albums[0].id
        let detail = try await apiClient.getAlbum(id: albumId)

        XCTAssertEqual(detail.album.title, "Test Album")
        XCTAssertEqual(detail.songs.count, 1)
        XCTAssertEqual(paths.count, 2)
    }

    // MARK: - Search Then Play Flow

    func testSearchThenPlayFlow() async throws {
        MockURLProtocol.requestHandler = { request in
            if request.url!.path == "/api/search" {
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, searchResultJSON)
            }
            if request.url!.path == "/api/songs/1" {
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, songsJSON)
            }
            if request.url!.path == "/api/stream/1" {
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("audio data".utf8))
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
        }

        let searchResult = try await apiClient.search(query: "Test")
        let songId = searchResult.songs[0].id
        let song = try await apiClient.getSong(id: songId)
        let streamURL = apiClient.streamURL(for: song.id)

        XCTAssertEqual(song.title, "Test Song")
        XCTAssertTrue(streamURL.absoluteString.hasSuffix("/api/stream/1"))
    }

    // MARK: - Empty Library

    func testEmptyLibrary() async throws {
        MockURLProtocol.requestHandler = { request in
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, "[]".data(using: .utf8)!)
        }
        let songs = try await apiClient.getSongs()
        XCTAssertTrue(songs.isEmpty)
    }

    // MARK: - Concurrent Requests

    func testConcurrentAlbumAndArtistRequests() async throws {
        MockURLProtocol.requestHandler = { request in
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms delay
            if request.url!.path == "/api/albums/1" {
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, albumDetailJSON)
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, artistDetailJSON)
        }

        async let album = apiClient.getAlbum(id: 1)
        async let artist = apiClient.getArtist(id: 1)

        let (a, ar) = try await (album, artist)
        XCTAssertEqual(a.album.title, "Test Album")
        XCTAssertEqual(ar.artist.name, "Test Artist")
    }

    // MARK: - Timeout Handling

    func testRequestTimeout() async {
        MockURLProtocol.requestHandler = { request in
            try await Task.sleep(nanoseconds: 5_000_000_000) // 5s delay
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }
        do {
            _ = try await apiClient.getSongs()
            XCTFail("Expected timeout error")
        } catch {
            XCTAssertTrue(error is URLError || error is DecodingError)
        }
    }
}
