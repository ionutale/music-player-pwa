import Foundation

@MainActor
class SearchEngine: ObservableObject {
    @Published var query = ""
    @Published var results = SearchResult(songs: [], albums: [], artists: [])
    @Published var isSearching = false
    @Published var recentSearches: [String] = []

    private let apiClient: APIClient
    private var task: Task<Void, Never>?
    private let defaults = UserDefaults.standard

    init(apiClient: APIClient) {
        self.apiClient = apiClient
        recentSearches = defaults.stringArray(forKey: "recentSearches") ?? []
    }

    func search() {
        task?.cancel()
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = SearchResult(songs: [], albums: [], artists: [])
            isSearching = false
            return
        }
        isSearching = true
        task = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            do {
                let result = try await apiClient.search(query: query)
                if !Task.isCancelled {
                    self.results = result
                    self.isSearching = false
                }
            } catch {
                if !Task.isCancelled {
                    self.isSearching = false
                }
            }
        }
    }

    func saveSearch(_ text: String) {
        recentSearches.removeAll { $0 == text }
        recentSearches.insert(text, at: 0)
        if recentSearches.count > 10 { recentSearches = Array(recentSearches.prefix(10)) }
        defaults.set(recentSearches, forKey: "recentSearches")
    }

    func clearRecent() {
        recentSearches.removeAll()
        defaults.removeObject(forKey: "recentSearches")
    }
}
