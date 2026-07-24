import SwiftUI

struct SettingsView: View {
    let apiClient: APIClient
    @State private var serverURL = ""
    @State private var apiKey = ""
    @State private var stats: LibraryStats?

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    TextField("Server URL", text: $serverURL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    TextField("API Key", text: $apiKey)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    Button("Save") {
                        UserDefaults.standard.set(serverURL, forKey: "serverURL")
                        UserDefaults.standard.set(apiKey, forKey: "apiKey")
                    }
                }

                Section("Library Stats") {
                    if let stats = stats {
                        LabeledContent("Songs", value: "\(stats.songCount)")
                        LabeledContent("Albums", value: "\(stats.albumCount)")
                        LabeledContent("Artists", value: "\(stats.artistCount)")
                        LabeledContent("Duration", value: "\(Int(stats.totalDuration) / 3600)h")
                        LabeledContent("Size", value: "\(stats.totalSize / 1_000_000)MB")
                    } else {
                        Text("Connect to server to see stats")
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Button("Rescan Library") {
                        Task { try? await apiClient.triggerScan() }
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? ""
                apiKey = UserDefaults.standard.string(forKey: "apiKey") ?? ""
                Task { stats = try? await apiClient.getStats() }
            }
        }
    }
}
