import Foundation

actor APIClient {
    let baseURL: URL
    private let session: URLSession
    private let apiKey: String

    init(baseURL: URL, apiKey: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }

    private var defaultHeaders: [String: String] {
        ["X-API-Key": apiKey]
    }

    func getSongs(page: Int = 1, limit: Int = 50) async throws -> [Song] {
        try await get("/api/songs?page=\(page)&limit=\(limit)")
    }

    func getSong(id: Int64) async throws -> Song {
        try await get("/api/songs/\(id)")
    }

    func getAlbums(page: Int = 1, limit: Int = 50) async throws -> [Album] {
        try await get("/api/albums?page=\(page)&limit=\(limit)")
    }

    func getAlbum(id: Int64) async throws -> AlbumDetailResponse {
        try await get("/api/albums/\(id)")
    }

    func getArtists(page: Int = 1, limit: Int = 50) async throws -> [Artist] {
        try await get("/api/artists?page=\(page)&limit=\(limit)")
    }

    func getArtist(id: Int64) async throws -> ArtistDetailResponse {
        try await get("/api/artists/\(id)")
    }

    func search(query: String) async throws -> SearchResult {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await get("/api/search?q=\(encoded)")
    }

    func getStats() async throws -> LibraryStats {
        try await get("/api/stats")
    }

    func artworkURL(for albumId: Int64) -> URL {
        baseURL.appendingPathComponent("/api/artwork/\(albumId)")
    }

    func streamURL(for songId: Int64) -> URL {
        baseURL.appendingPathComponent("/api/stream/\(songId)")
    }

    func triggerScan() async throws -> [String: String] {
        var req = URLRequest(url: baseURL.appendingPathComponent("/api/scan"))
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        let (data, _) = try await session.data(for: req)
        return try JSONDecoder().decode([String: String].self, from: data)
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        let (data, _) = try await session.data(for: req)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
