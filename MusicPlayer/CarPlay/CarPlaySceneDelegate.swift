import CarPlay
import SwiftUI

class CarPlaySceneDelegate: NSObject, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private var audioPlayer: AudioPlayer?
    private var downloadManager: DownloadManager?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        setupCarPlay()
    }

    private func setupCarPlay() {
        let artistsItem = CPListItem(text: "Artists", detailText: nil)
        artistsItem.handler = { [weak self] _, completion in
            self?.showArtists()
            completion()
        }

        let albumsItem = CPListItem(text: "Albums", detailText: nil)
        albumsItem.handler = { [weak self] _, completion in
            self?.showAlbums()
            completion()
        }

        let songsItem = CPListItem(text: "Songs", detailText: nil)
        songsItem.handler = { [weak self] _, completion in
            self?.showSongs()
            completion()
        }

        let section = CPListSection(items: [artistsItem, albumsItem, songsItem])
        let rootList = CPListTemplate(title: "Music Library", sections: [section])
        Task { try? await interfaceController?.setRootTemplate(rootList, animated: true) }
    }

    private func showArtists() {
        Task {
            guard let client = audioPlayer?.apiClient,
                  let artists = try? await client.getArtists(limit: 100) else { return }

            let items = artists.map { artist in
                let item = CPListItem(text: artist.name, detailText: "\(artist.albumCount) albums")
                item.handler = { [weak self] _, completion in
                    self?.showArtistAlbums(artistId: artist.id)
                    completion()
                }
                return item
            }
            let section = CPListSection(items: items)
            let list = CPListTemplate(title: "Artists", sections: [section])
            try? await interfaceController?.pushTemplate(list, animated: true)
        }
    }

    private func showArtistAlbums(artistId: Int64) {
        Task {
            guard let client = audioPlayer?.apiClient,
                  let detail = try? await client.getArtist(id: artistId) else { return }

            let items = detail.albums.map { album -> CPListItem in
                let item = CPListItem(text: album.title, detailText: "\(album.year)")
                item.handler = { [weak self] _, completion in
                    self?.showAlbum(albumId: album.id)
                    completion()
                }
                return item
            }
            let section = CPListSection(items: items)
            let list = CPListTemplate(title: detail.artist.name, sections: [section])
            try? await interfaceController?.pushTemplate(list, animated: true)
        }
    }

    private func showAlbums() {
        Task {
            guard let client = audioPlayer?.apiClient,
                  let albums = try? await client.getAlbums(limit: 100) else { return }

            let gridItems = albums.map { album -> CPGridButton in
                CPGridButton(
                    titleVariants: [album.title],
                    image: UIImage(systemName: "music.note")!
                ) { [weak self] _ in
                    self?.showAlbum(albumId: album.id)
                }
            }
            let grid = CPGridTemplate(title: "Albums", gridButtons: gridItems)
            try? await interfaceController?.pushTemplate(grid, animated: true)
        }
    }

    private func showAlbum(albumId: Int64) {
        Task {
            guard let client = audioPlayer?.apiClient,
                  let detail = try? await client.getAlbum(id: albumId) else { return }

            let items = detail.songs.map { song -> CPListItem in
                let item = CPListItem(text: song.title, detailText: song.formattedDuration)
                item.handler = { [weak self] _, completion in
                    self?.audioPlayer?.playQueue(songs: detail.songs, startIndex: detail.songs.firstIndex(of: song) ?? 0)
                    let nowPlaying = CPNowPlayingTemplate.shared
                    Task { try? await self?.interfaceController?.pushTemplate(nowPlaying, animated: true) }
                    completion()
                }
                return item
            }
            let section = CPListSection(items: items)
            let list = CPListTemplate(title: detail.album.title, sections: [section])
            try? await interfaceController?.pushTemplate(list, animated: true)
        }
    }

    private func showSongs() {
        Task {
            guard let client = audioPlayer?.apiClient,
                  let songs = try? await client.getSongs(limit: 100) else { return }

            let items = songs.map { song -> CPListItem in
                let item = CPListItem(text: song.title, detailText: "\(song.artistName) • \(song.formattedDuration)")
                item.handler = { [weak self] _, completion in
                    self?.audioPlayer?.play(song: song)
                    let nowPlaying = CPNowPlayingTemplate.shared
                    Task { try? await self?.interfaceController?.pushTemplate(nowPlaying, animated: true) }
                    completion()
                }
                return item
            }
            let section = CPListSection(items: items)
            let list = CPListTemplate(title: "Songs", sections: [section])
            try? await interfaceController?.pushTemplate(list, animated: true)
        }
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
    }
}
