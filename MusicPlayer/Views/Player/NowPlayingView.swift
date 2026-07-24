import SwiftUI

struct NowPlayingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var audioPlayer: AudioPlayer
    @StateObject var downloadManager: DownloadManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let song = audioPlayer.currentSong {
                    ArtworkView(
                        albumId: song.albumId,
                        apiClient: audioPlayer.apiClient,
                        size: 300
                    )
                    .shadow(radius: 10)

                    VStack(spacing: 4) {
                        Text(song.title)
                            .font(.title).bold()
                            .multilineTextAlignment(.center)
                        Text(song.artistName)
                            .font(.title3).foregroundColor(.secondary)
                        Text(song.albumTitle)
                            .font(.subheadline).foregroundColor(.secondary)
                    }

                    Slider(
                        value: Binding(
                            get: { audioPlayer.currentTime },
                            set: { audioPlayer.seek(to: $0) }
                        ),
                        in: 0...max(audioPlayer.duration, 1)
                    )
                    .padding(.horizontal)

                    HStack {
                        Text(audioPlayer.currentTime.formattedTime)
                        Spacer()
                        Text(audioPlayer.duration.formattedTime)
                    }
                    .font(.caption).foregroundColor(.secondary)
                    .padding(.horizontal)

                    HStack(spacing: 40) {
                        Button { audioPlayer.previousTrack() } label: {
                            Image(systemName: "backward.fill").font(.title)
                        }
                        Button { audioPlayer.togglePlayPause() } label: {
                            Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 64))
                        }
                        Button { audioPlayer.nextTrack() } label: {
                            Image(systemName: "forward.fill").font(.title)
                        }
                    }
                }
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

extension TimeInterval {
    var formattedTime: String {
        let m = Int(self) / 60
        let s = Int(self) % 60
        return "\(m):\(String(format: "%02d", s))"
    }
}
