import Foundation

struct Song: Codable, Identifiable, Hashable {
    let id: Int64
    let title: String
    let trackNumber: Int
    let discNumber: Int
    let duration: Double
    let fileFormat: String
    let fileSize: Int64
    let bitrate: Int
    let artistId: Int64
    let artistName: String
    let albumId: Int64
    let albumTitle: String
    let filePath: String

    var formattedDuration: String {
        let m = Int(duration) / 60
        let s = Int(duration) % 60
        return "\(m):\(String(format: "%02d", s))"
    }
}

struct Album: Codable, Identifiable, Hashable {
    let id: Int64
    let title: String
    let artistId: Int64
    let artistName: String
    let year: Int
    let genre: String
    let songCount: Int
    let duration: Double
    let hasArtwork: Bool
}

struct Artist: Codable, Identifiable, Hashable {
    let id: Int64
    let name: String
    let sortName: String
    let albumCount: Int
}

struct SearchResult: Codable {
    let songs: [Song]
    let albums: [Album]
    let artists: [Artist]
}

struct LibraryStats: Codable {
    let songCount: Int
    let albumCount: Int
    let artistCount: Int
    let totalDuration: Double
    let totalSize: Int64
}

struct AlbumDetailResponse: Codable {
    let album: Album
    let songs: [Song]
}

struct ArtistDetailResponse: Codable {
    let artist: Artist
    let albums: [Album]
}
