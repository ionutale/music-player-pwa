import SwiftUI

struct ArtistDetailView: View {
    let artistId: Int64
    let apiClient: APIClient
    @StateObject var audioPlayer: AudioPlayer
    @StateObject var downloadManager: DownloadManager

    @State private var detail: ArtistDetailResponse?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let detail = detail {
                List {
                    Section {
                        Text(detail.artist.name).font(.largeTitle).bold()
                        Text("\(detail.artist.albumCount) albums")
                            .foregroundColor(.secondary)
                    }

                    Section("Albums") {
                        ForEach(detail.albums) { album in
                            NavigationLink(destination: AlbumDetailView(
                                albumId: album.id,
                                apiClient: apiClient,
                                audioPlayer: audioPlayer,
                                downloadManager: downloadManager
                            )) {
                                HStack {
                                    ArtworkView(albumId: album.id, apiClient: apiClient, size: 44)
                                    VStack(alignment: .leading) {
                                        Text(album.title).font(.body)
                                        Text("\(album.year)")
                                            .font(.caption).foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                .navigationTitle(detail.artist.name)
            }
        }
        .task {
            isLoading = true
            detail = try? await apiClient.getArtist(id: artistId)
            isLoading = false
        }
    }
}
