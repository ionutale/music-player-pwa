import XCTest
@testable import MusicPlayer

final class APIClientTests: XCTestCase {
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

    func testGetSongs() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertTrue(request.url!.path.contains("/api/songs"))
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "test-key")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, songsJSON)
        }
        let songs = try await apiClient.getSongs()
        XCTAssertEqual(songs.count, 1)
        XCTAssertEqual(songs[0].title, "Test Song")
    }

    func testGetAlbums() async throws {
        MockURLProtocol.requestHandler = { request in
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, albumsJSON)
        }
        let albums = try await apiClient.getAlbums()
        XCTAssertEqual(albums.count, 1)
        XCTAssertEqual(albums[0].title, "Test Album")
    }

    func testGetArtists() async throws {
        MockURLProtocol.requestHandler = { request in
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, artistsJSON)
        }
        let artists = try await apiClient.getArtists()
        XCTAssertEqual(artists.count, 1)
        XCTAssertEqual(artists[0].name, "Test Artist")
    }

    func testGetAlbumDetail() async throws {
        MockURLProtocol.requestHandler = { request in
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, albumDetailJSON)
        }
        let detail = try await apiClient.getAlbum(id: 1)
        XCTAssertEqual(detail.album.title, "Test Album")
        XCTAssertEqual(detail.songs.count, 1)
    }

    func testGetArtistDetail() async throws {
        MockURLProtocol.requestHandler = { request in
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, artistDetailJSON)
        }
        let detail = try await apiClient.getArtist(id: 1)
        XCTAssertEqual(detail.artist.name, "Test Artist")
        XCTAssertEqual(detail.albums.count, 1)
    }

    func testSearch() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertTrue(request.url!.query!.contains("q=test"))
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, searchResultJSON)
        }
        let result = try await apiClient.search(query: "test")
        XCTAssertEqual(result.songs.count, 1)
        XCTAssertEqual(result.albums.count, 1)
        XCTAssertEqual(result.artists.count, 1)
    }

    func testGetStats() async throws {
        MockURLProtocol.requestHandler = { request in
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, statsJSON)
        }
        let stats = try await apiClient.getStats()
        XCTAssertEqual(stats.songCount, 10)
        XCTAssertEqual(stats.artistCount, 3)
    }

    func testTriggerScan() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, scanResponseJSON)
        }
        let response = try await apiClient.triggerScan()
        XCTAssertEqual(response["status"], "started")
    }

    func testArtworkURL() {
        let url = apiClient.artworkURL(for: 42)
        XCTAssertTrue(url.absoluteString.hasSuffix("/api/artwork/42"))
    }

    func testStreamURL() {
        let url = apiClient.streamURL(for: 99)
        XCTAssertTrue(url.absoluteString.hasSuffix("/api/stream/99"))
    }

    func testGetSongs_WithPagination() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertTrue(request.url!.query!.contains("page=2"))
            XCTAssertTrue(request.url!.query!.contains("limit=10"))
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, songsJSON)
        }
        let songs = try await apiClient.getSongs(page: 2, limit: 10)
        XCTAssertEqual(songs.count, 1)
    }

    func testNetworkError() async {
        MockURLProtocol.requestHandler = { request in
            throw URLError(.notConnectedToInternet)
        }
        do {
            _ = try await apiClient.getSongs()
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(error is URLError)
        }
    }

    func testServerError() async throws {
        MockURLProtocol.requestHandler = { request in
            return (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
        }
        // The APIClient doesn't check status codes, but decodes JSON.
        // With empty data, decoding should fail.
        do {
            _ = try await apiClient.getSongs()
            XCTFail("Expected decoding error with empty 500 response")
        } catch {
            XCTAssertTrue(error is DecodingError)
        }
    }

    func testMalformedJSON() async throws {
        MockURLProtocol.requestHandler = { request in
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, "not json".data(using: .utf8)!)
        }
        do {
            _ = try await apiClient.getSongs()
            XCTFail("Expected decoding error")
        } catch {
            XCTAssertTrue(error is DecodingError)
        }
    }

    func testInvalidServerURL() {
        let client = APIClient(baseURL: URL(string: "not-a-url")!, apiKey: "key")
        let url = client.artworkURL(for: 1)
        // Should still produce a valid URL even with unusual base
        XCTAssertFalse(url.absoluteString.isEmpty)
    }

    func testSearchEncodesQuery() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertTrue(request.url!.absoluteString.contains("q=Daft+Punk"))
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, searchResultJSON)
        }
        let result = try await apiClient.search(query: "Daft Punk")
        XCTAssertEqual(result.songs.count, 1)
    }
}
