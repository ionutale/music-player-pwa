import SwiftUI

struct LibraryView: View {
    let apiClient: APIClient
    @StateObject var audioPlayer: AudioPlayer
    @StateObject var downloadManager: DownloadManager
    @StateObject var searchEngine: SearchEngine

    @State private var artists: [Artist] = []
    @State private var albums: [Album] = []
    @State private var songs: [Song] = []
    @State private var selectedTab = 0
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading library...")
                } else {
                    Picker("View", selection: $selectedTab) {
                        Text("Artists").tag(0)
                        Text("Albums").tag(1)
                        Text("Songs").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    switch selectedTab {
                    case 0:
                        ArtistList(artists: artists, apiClient: apiClient, audioPlayer: audioPlayer, downloadManager: downloadManager)
                    case 1:
                        AlbumGrid(albums: albums, apiClient: apiClient, audioPlayer: audioPlayer, downloadManager: downloadManager)
                    case 2:
                        SongList(songs: songs, audioPlayer: audioPlayer, downloadManager: downloadManager)
                    default:
                        EmptyView()
                    }
                }
            }
            .navigationTitle("Library")
            .task {
                await loadLibrary()
            }
        }
    }

    func loadLibrary() async {
        isLoading = true
        do {
            async let artistsTask = apiClient.getArtists(limit: 200)
            async let albumsTask = apiClient.getAlbums(limit: 200)
            async let songsTask = apiClient.getSongs(limit: 500)
            (artists, albums, songs) = try await (artistsTask, albumsTask, songsTask)
        } catch {}
        isLoading = false
    }
}

struct ArtistList: View {
    let artists: [Artist]
    let apiClient: APIClient
    let audioPlayer: AudioPlayer
    let downloadManager: DownloadManager

    var body: some View {
        List(artists) { artist in
            NavigationLink(destination: ArtistDetailView(
                artistId: artist.id,
                apiClient: apiClient,
                audioPlayer: audioPlayer,
                downloadManager: downloadManager
            )) {
                HStack {
                    Image(systemName: "person.crop.square")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    VStack(alignment: .leading) {
                        Text(artist.name).font(.body)
                        Text("\(artist.albumCount) albums")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

struct AlbumGrid: View {
    let albums: [Album]
    let apiClient: APIClient
    let audioPlayer: AudioPlayer
    let downloadManager: DownloadManager

    let columns = [GridItem(.adaptive(minimum: 160))]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(albums) { album in
                    NavigationLink(destination: AlbumDetailView(
                        albumId: album.id,
                        apiClient: apiClient,
                        audioPlayer: audioPlayer,
                        downloadManager: downloadManager
                    )) {
                        VStack(alignment: .leading) {
                            ArtworkView(albumId: album.id, apiClient: apiClient, size: 160)
                            Text(album.title)
                                .font(.caption).lineLimit(1)
                            Text(album.artistName)
                                .font(.caption2).foregroundColor(.secondary).lineLimit(1)
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct SongList: View {
    let songs: [Song]
    let audioPlayer: AudioPlayer
    let downloadManager: DownloadManager

    var body: some View {
        List(songs) { song in
            SongRow(
                song: song,
                isDownloaded: downloadManager.isDownloaded(song),
                downloadAction: { Task { try? await downloadManager.download(song: song) } },
                removeAction: { downloadManager.removeDownload(song: song) }
            )
            .contentShape(Rectangle())
            .onTapGesture {
                audioPlayer.playQueue(songs: songs, startIndex: songs.firstIndex(of: song) ?? 0)
            }
        }
    }
}
