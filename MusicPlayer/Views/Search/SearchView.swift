import SwiftUI

struct SearchView: View {
    @StateObject var searchEngine: SearchEngine
    @StateObject var audioPlayer: AudioPlayer
    @StateObject var downloadManager: DownloadManager

    var body: some View {
        NavigationStack {
            List {
                if searchEngine.query.isEmpty {
                    Section("Recent Searches") {
                        ForEach(searchEngine.recentSearches, id: \.self) { text in
                            Button(text) {
                                searchEngine.query = text
                                searchEngine.search()
                            }
                        }
                        if !searchEngine.recentSearches.isEmpty {
                            Button("Clear", action: searchEngine.clearRecent)
                                .foregroundColor(.red)
                        }
                    }
                } else if searchEngine.isSearching {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else {
                    let results = searchEngine.results
                    if !results.artists.isEmpty {
                        Section("Artists") {
                            ForEach(results.artists) { artist in
                                NavigationLink(destination: ArtistDetailView(
                                    artistId: artist.id,
                                    apiClient: audioPlayer.apiClient,
                                    audioPlayer: audioPlayer,
                                    downloadManager: downloadManager
                                )) {
                                    Text(artist.name)
                                }
                            }
                        }
                    }
                    if !results.albums.isEmpty {
                        Section("Albums") {
                            ForEach(results.albums) { album in
                                NavigationLink(destination: AlbumDetailView(
                                    albumId: album.id,
                                    apiClient: audioPlayer.apiClient,
                                    audioPlayer: audioPlayer,
                                    downloadManager: downloadManager
                                )) {
                                    HStack {
                                        ArtworkView(albumId: album.id, apiClient: audioPlayer.apiClient, size: 44)
                                        VStack(alignment: .leading) {
                                            Text(album.title).font(.body)
                                            Text(album.artistName).font(.caption).foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    if !results.songs.isEmpty {
                        Section("Songs") {
                            ForEach(results.songs) { song in
                                SongRow(
                                    song: song,
                                    isDownloaded: downloadManager.isDownloaded(song),
                                    downloadAction: {
                                        Task { try? await downloadManager.download(song: song) }
                                    },
                                    removeAction: {
                                        downloadManager.removeDownload(song: song)
                                    }
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    searchEngine.saveSearch(searchEngine.query)
                                    audioPlayer.play(song: song)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchEngine.query)
            .onChange(of: searchEngine.query) { _ in
                searchEngine.search()
            }
            .onSubmit(of: .search) {
                searchEngine.saveSearch(searchEngine.query)
            }
            .navigationTitle("Search")
        }
    }
}
