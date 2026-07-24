import SwiftUI

struct SongRow: View {
    let song: Song
    let isDownloaded: Bool
    let downloadAction: () -> Void
    let removeAction: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.body)
                    .lineLimit(1)
                Text("\(song.artistName) • \(song.formattedDuration)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Menu {
                if isDownloaded {
                    Button("Remove Download", action: removeAction)
                } else {
                    Button("Download", action: downloadAction)
                }
            } label: {
                Image(systemName: isDownloaded ? "icloud.fill" : "icloud")
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 2)
    }
}
