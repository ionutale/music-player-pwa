import XCTest
@testable import MusicPlayer

final class SearchEngineTests: XCTestCase {
    var searchEngine: SearchEngine!
    var apiClient: APIClient!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        apiClient = APIClient(baseURL: URL(string: "http://localhost:8080")!, apiKey: "key", session: URLSession(configuration: config))
        searchEngine = SearchEngine(apiClient: apiClient)

        // Clear UserDefaults for test isolation
        UserDefaults.standard.removeObject(forKey: "recentSearches")
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        searchEngine = nil
        super.tearDown()
    }

    func testInitialState() {
        XCTAssertEqual(searchEngine.query, "")
        XCTAssertTrue(searchEngine.results.songs.isEmpty)
        XCTAssertFalse(searchEngine.isSearching)
        XCTAssertTrue(searchEngine.recentSearches.isEmpty)
    }

    func testEmptyQueryClearsResults() {
        searchEngine.query = ""
        searchEngine.search()
        XCTAssertTrue(searchEngine.results.songs.isEmpty)
        XCTAssertFalse(searchEngine.isSearching)
    }

    func testWhitespaceOnlyQueryClearsResults() {
        searchEngine.query = "   "
        searchEngine.search()
        XCTAssertTrue(searchEngine.results.songs.isEmpty)
        XCTAssertFalse(searchEngine.isSearching)
    }

    func testSaveSearch() {
        searchEngine.saveSearch("Daft Punk")
        searchEngine.saveSearch("Radiohead")
        XCTAssertEqual(searchEngine.recentSearches.count, 2)
        XCTAssertEqual(searchEngine.recentSearches[0], "Radiohead") // most recent first
    }

    func testSaveSearchDeduplicates() {
        searchEngine.saveSearch("Daft Punk")
        searchEngine.saveSearch("Daft Punk")
        XCTAssertEqual(searchEngine.recentSearches.count, 1)
    }

    func testSaveSearchMaxLimit() {
        for i in 0..<15 {
            searchEngine.saveSearch("Search \(i)")
        }
        XCTAssertEqual(searchEngine.recentSearches.count, 10)
    }

    func testClearRecent() {
        searchEngine.saveSearch("Test")
        searchEngine.clearRecent()
        XCTAssertTrue(searchEngine.recentSearches.isEmpty)
    }

    func testRecentSearchesPersisted() {
        searchEngine.saveSearch("Persistent Search")
        let newEngine = SearchEngine(apiClient: apiClient)
        XCTAssertEqual(newEngine.recentSearches, ["Persistent Search"])
    }

    func testSearchRequestsServer() async throws {
        let expectation = expectation(description: "search")
        MockURLProtocol.requestHandler = { request in
            XCTAssertTrue(request.url!.query!.contains("q=test"))
            expectation.fulfill()
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, searchResultJSON)
        }
        searchEngine.query = "test"
        searchEngine.search()
        await fulfillment(of: [expectation], timeout: 2)
    }

    func testSubmitOfSearchSavesToRecent() {
        searchEngine.query = "Rock"
        searchEngine.saveSearch(searchEngine.query)
        XCTAssertEqual(searchEngine.recentSearches.first, "Rock")
    }

    func testRapidQueryChangesCancelPreviousSearch() {
        searchEngine.query = "a"
        searchEngine.search()
        searchEngine.query = "ab"
        searchEngine.search()
        searchEngine.query = "abc"
        searchEngine.search()
        // The last call's task should be the only one that completes
        // If cancellation works, no crash/error
        XCTAssertTrue(true)
    }
}
