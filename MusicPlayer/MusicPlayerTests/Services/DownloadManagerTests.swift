import XCTest
@testable import MusicPlayer

final class DownloadManagerTests: XCTestCase {
    var downloadManager: DownloadManager!
    var apiClient: APIClient!
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        apiClient = APIClient(baseURL: URL(string: "http://localhost:8080")!, apiKey: "key", session: URLSession(configuration: config))

        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("MusicTest")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        downloadManager = DownloadManager(apiClient: apiClient)
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        downloadManager = nil
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testInitialState() {
        XCTAssertTrue(downloadManager.downloadedSongIDs.isEmpty)
        XCTAssertTrue(downloadManager.downloadingIDs.isEmpty)
        XCTAssertTrue(downloadManager.progress.isEmpty)
    }

    func testIsDownloaded_ReturnsFalseForUnknown() {
        XCTAssertFalse(downloadManager.isDownloaded(testSong))
    }

    func testIsDownloaded_ReturnsTrueAfterDownload() {
        downloadManager.downloadedSongIDs.insert(testSong.id)
        XCTAssertTrue(downloadManager.isDownloaded(testSong))
    }

    func testDownloadAddsToDownloadingSet() async throws {
        MockURLProtocol.requestHandler = { request in
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("audio data".utf8))
        }
        try await downloadManager.download(song: testSong)
        XCTAssertTrue(downloadManager.isDownloaded(testSong))
        XCTAssertFalse(downloadManager.downloadingIDs.contains(testSong.id))
    }

    func testDownloadProgress() async throws {
        MockURLProtocol.requestHandler = { request in
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("audio data".utf8))
        }
        try await downloadManager.download(song: testSong)
        XCTAssertEqual(downloadManager.progress[testSong.id], 1.0)
    }

    func testRemoveDownload() {
        downloadManager.downloadedSongIDs.insert(testSong.id)
        downloadManager.removeDownload(song: testSong)
        XCTAssertFalse(downloadManager.isDownloaded(testSong))
    }

    func testDownloadingStateDuringDownload() async throws {
        MockURLProtocol.requestHandler = { request in
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("audio".utf8))
        }

        let task = Task {
            try await downloadManager.download(song: testSong)
        }
        try await Task.sleep(nanoseconds: 10_000_000)
        XCTAssertTrue(downloadManager.downloadingIDs.contains(testSong.id))
        try await task.value
    }

    func testDownloadFileSaved() async throws {
        let testContent = "audio content".data(using: .utf8)!
        MockURLProtocol.requestHandler = { request in
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, testContent)
        }
        try await downloadManager.download(song: testSong)

        let localURL = downloadManager.localURL(for: testSong)
        let savedData = try Data(contentsOf: localURL)
        XCTAssertEqual(savedData, testContent)
    }

    func testConsecutiveDownloads() async throws {
        let song2 = Song(id: 2, title: "Song 2", trackNumber: 2, discNumber: 1,
                        duration: 180, fileFormat: "mp3", fileSize: 300,
                        bitrate: 256, artistId: 1, artistName: "A",
                        albumId: 1, albumTitle: "Al", filePath: "/m/s2.mp3")

        MockURLProtocol.requestHandler = { request in
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("x".utf8))
        }

        try await downloadManager.download(song: testSong)
        try await downloadManager.download(song: song2)

        XCTAssertTrue(downloadManager.isDownloaded(testSong))
        XCTAssertTrue(downloadManager.isDownloaded(song2))
        XCTAssertEqual(downloadManager.downloadedSongIDs.count, 2)
    }

    func testRemoveNonExistentDownloadDoesNotCrash() {
        downloadManager.removeDownload(song: testSong)
        XCTAssertFalse(downloadManager.isDownloaded(testSong))
    }

    func testLocalURLIsCorrect() {
        let url = downloadManager.localURL(for: testSong)
        XCTAssertTrue(url.absoluteString.hasSuffix("1.mp3"))
    }

    func testProgressAfterRemove() {
        downloadManager.downloadedSongIDs.insert(testSong.id)
        downloadManager.progress[testSong.id] = 1.0
        downloadManager.removeDownload(song: testSong)
        XCTAssertNil(downloadManager.progress[testSong.id])
    }

    func testDownloadNetworkError() async {
        MockURLProtocol.requestHandler = { request in
            throw URLError(.timedOut)
        }
        do {
            try await downloadManager.download(song: testSong)
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(error is URLError)
        }
        // Should clean up downloading state even on error
        XCTAssertFalse(downloadManager.downloadingIDs.contains(testSong.id))
    }
}
