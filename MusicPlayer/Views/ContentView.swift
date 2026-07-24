import SwiftUI

struct ContentView: View {
    let apiClient: APIClient
    @StateObject var audioPlayer: AudioPlayer
    @StateObject var downloadManager: DownloadManager
    @StateObject var searchEngine: SearchEngine
    @State private var showSettings = false
    @State private var showPlayer = false

    var body: some View {
        TabView {
            LibraryView(
                apiClient: apiClient,
                audioPlayer: audioPlayer,
                downloadManager: downloadManager,
                searchEngine: searchEngine
            )
            .tabItem { Label("Library", systemImage: "music.note.list") }

            SearchView(searchEngine: searchEngine, audioPlayer: audioPlayer, downloadManager: downloadManager)
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
        }
        .overlay(alignment: .bottom) {
            if audioPlayer.currentSong != nil {
                NowPlayingBar()
                    .onTapGesture { showPlayer = true }
            }
        }
        .sheet(isPresented: $showPlayer) {
            NowPlayingView(audioPlayer: audioPlayer, downloadManager: downloadManager)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(apiClient: apiClient)
        }
    }
}

struct NowPlayingBar: View {
    var body: some View {
        HStack {
            Text("Now Playing")
                .font(.subheadline).bold()
            Spacer()
            Image(systemName: "play.fill")
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}
