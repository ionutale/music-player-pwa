import SwiftUI

struct ArtworkView: View {
    let albumId: Int64
    let apiClient: APIClient
    var size: CGFloat = 44

    var body: some View {
        AsyncImage(url: apiClient.artworkURL(for: albumId)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                Rectangle()
                    .fill(.secondary)
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundColor(.white)
                    }
            case .empty:
                Rectangle()
                    .fill(.secondary)
                    .overlay {
                        ProgressView()
                    }
            @unknown default:
                EmptyView()
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
