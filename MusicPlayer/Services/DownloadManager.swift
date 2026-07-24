import Foundation

@MainActor
class DownloadManager: ObservableObject {
    @Published var downloadedSongIDs: Set<Int64> = []
    @Published var downloadingIDs: Set<Int64> = []
    @Published var progress: [Int64: Double] = [:]

    private let apiClient: APIClient
    private let fileManager = FileManager.default

    private var documentsDir: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Music", isDirectory: true)
    }

    init(apiClient: APIClient) {
        self.apiClient = apiClient
        try? fileManager.createDirectory(at: documentsDir, withIntermediateDirectories: true)
        loadDownloadedIDs()
    }

    var downloadedSongsDir: URL { documentsDir }

    func localURL(for song: Song) -> URL {
        documentsDir.appendingPathComponent("\(song.id).\(song.fileFormat)")
    }

    func isDownloaded(_ song: Song) -> Bool {
        downloadedSongIDs.contains(song.id)
    }

    func download(song: Song) async throws {
        downloadingIDs.insert(song.id)
        defer { downloadingIDs.remove(song.id) }

        let streamURL = apiClient.streamURL(for: song.id)
        let (data, _) = try await URLSession.shared.data(from: streamURL)
        let dest = localURL(for: song)
        try data.write(to: dest)

        downloadedSongIDs.insert(song.id)
        saveDownloadedIDs()
        progress[song.id] = 1.0
    }

    func removeDownload(song: Song) {
        let url = localURL(for: song)
        try? fileManager.removeItem(at: url)
        downloadedSongIDs.remove(song.id)
        saveDownloadedIDs()
    }

    func loadDownloadedIDs() {
        let url = documentsDir.appendingPathComponent(".downloaded.json")
        guard let data = try? Data(contentsOf: url),
              let ids = try? JSONDecoder().decode(Set<Int64>.self, from: data) else {
            return
        }
        downloadedSongIDs = ids.filter { id in
            let path = documentsDir.appendingPathComponent("\(id).mp3")
            return fileManager.fileExists(atPath: path.path)
        }
    }

    private func saveDownloadedIDs() {
        let url = documentsDir.appendingPathComponent(".downloaded.json")
        try? JSONEncoder().encode(downloadedSongIDs).write(to: url)
    }
}
