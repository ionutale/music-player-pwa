import AVFoundation
import UIKit

@MainActor
class AudioPlayer: ObservableObject {
    let apiClient: APIClient

    @Published var currentSong: Song?
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var queue: [Song] = []
    @Published var queueIndex = -1

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var itemObserver: Any?

    init(apiClient: APIClient) {
        self.apiClient = apiClient
        configureAudioSession()
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true)
    }

    func play(song: Song) {
        let url = apiClient.streamURL(for: song.id)
        let playerItem = AVPlayerItem(url: url)
        player?.pause()
        player = AVPlayer(playerItem: playerItem)
        currentSong = song
        duration = song.duration
        isPlaying = true
        player?.play()
        observeTime()
        observeEnd()
    }

    func playQueue(songs: [Song], startIndex: Int) {
        queue = songs
        queueIndex = startIndex
        play(song: songs[startIndex])
    }

    func togglePlayPause() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        isPlaying = player?.timeControlStatus == .playing
    }

    func seek(to time: TimeInterval) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 1000))
    }

    func nextTrack() {
        guard queueIndex + 1 < queue.count else { return }
        queueIndex += 1
        play(song: queue[queueIndex])
    }

    func previousTrack() {
        guard currentTime > 3 else {
            guard queueIndex - 1 >= 0 else { return }
            queueIndex -= 1
            play(song: queue[queueIndex])
            return
        }
        seek(to: 0)
    }

    private func observeTime() {
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 1000),
            queue: .main
        ) { [weak self] time in
            self?.currentTime = time.seconds
        }
    }

    private func observeEnd() {
        itemObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.nextTrack()
        }
    }

    deinit {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
    }
}
