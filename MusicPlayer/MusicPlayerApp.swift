import SwiftUI

@main
struct MusicPlayerApp: App {
    @State private var isConfigured = UserDefaults.standard.string(forKey: "serverURL") != nil
    @State private var serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? ""
    @State private var apiKey = UserDefaults.standard.string(forKey: "apiKey") ?? ""

    var body: some Scene {
        WindowGroup {
            if isConfigured {
                let client = APIClient(baseURL: URL(string: serverURL)!, apiKey: apiKey)
                ContentView(
                    apiClient: client,
                    audioPlayer: AudioPlayer(apiClient: client),
                    downloadManager: DownloadManager(apiClient: client),
                    searchEngine: SearchEngine(apiClient: client)
                )
            } else {
                SetupView()
            }
        }
    }
}

struct SetupView: View {
    @State private var serverURL = ""
    @State private var apiKey = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Server Connection") {
                    TextField("Server URL", text: $serverURL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    TextField("API Key", text: $apiKey)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                Section {
                    Button("Connect") {
                        UserDefaults.standard.set(serverURL, forKey: "serverURL")
                        UserDefaults.standard.set(apiKey, forKey: "apiKey")
                        NotificationCenter.default.post(name: NSNotification.Name("ServerConfigured"), object: nil)
                    }
                    .disabled(serverURL.isEmpty || apiKey.isEmpty)
                }
            }
            .navigationTitle("Welcome")
            .interactiveDismissDisabled()
        }
    }
}
