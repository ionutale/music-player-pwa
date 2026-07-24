import SwiftUI

struct AlbumDetailView: View {
    let albumId: Int64
    @StateObject var apiClient: APIClient
    @StateObject var audioPlayer: AudioPlayer
    @StateObject var downloadManager: DownloadManager

    @State private var albumDetail: AlbumDetailResponse?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let detail = albumDetail {
                List {
                    Section {
                        HStack {
                            ArtworkView(albumId: albumId, apiClient: apiClient, size: 120)
                            VStack(alignment: .leading) {
                                Text(detail.album.title).font(.title2).bold()
                                Text(detail.album.artistName).foregroundColor(.secondary)
                                Text("\(detail.album.year)  •  \(detail.album.genre)")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }

                    Section("Tracks") {
                        ForEach(detail.songs) { song in
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
                                audioPlayer.playQueue(songs: detail.songs, startIndex: detail.songs.firstIndex(of: song) ?? 0)
                            }
                        }
                    }
                }
                .navigationTitle(detail.album.title)
            }
        }
        .task {
            isLoading = true
            albumDetail = try? await apiClient.getAlbum(id: albumId)
            isLoading = false
        }
    }
}
