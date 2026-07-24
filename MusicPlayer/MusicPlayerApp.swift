import SwiftUI

@main
struct MusicPlayerApp: App {
    @AppStorage("serverURL") private var serverURL = ""
    @AppStorage("apiKey") private var apiKey = ""

    private var isConfigured: Bool {
        !serverURL.isEmpty && !apiKey.isEmpty && URL(string: serverURL) != nil
    }

    var body: some Scene {
        WindowGroup {
            if isConfigured, let url = URL(string: serverURL) {
                let client = APIClient(baseURL: url, apiKey: apiKey)
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
    @AppStorage("serverURL") private var serverURL = ""
    @AppStorage("apiKey") private var apiKey = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Enter your server details to connect to your music library.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Section("Server") {
                    TextField("http://192.168.1.100:8080", text: $serverURL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    TextField("API Key", text: $apiKey)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }

                Section {
                    Button("Connect") {}
                        .disabled(serverURL.isEmpty || apiKey.isEmpty)
                }

                Section("How to find your server") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Make sure the Docker server is running")
                        Text("2. Find your server's local IP:")
                        Text("   macOS: System Settings → Network")
                        Text("   Then: http://<IP>:8080")
                        Text("3. Use the API_KEY from docker-compose.yml")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Connect to Server")
        }
    }
}
