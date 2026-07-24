# Music Player PWA — Design Spec

## Overview

A personal music streaming system. Single-user, local-network server running Go in Docker serves MP3s + artwork to a Swift/SwiftUI iOS app with CarPlay support. Songs are downloaded to the device for offline playback.

---

## Server (Go + Docker)

### REST API

| Endpoint | Description |
|---|---|
| `GET /api/songs?page=&limit=` | Paginated song list |
| `GET /api/songs/:id` | Single song with metadata |
| `GET /api/albums?page=&limit=` | Album list |
| `GET /api/albums/:id` | Single album with track list |
| `GET /api/artists?page=&limit=` | Artist list |
| `GET /api/artists/:id` | Single artist with albums |
| `GET /api/search?q=&type=all` | Unified search (songs/albums/artists) |
| `GET /api/artwork/:id` | Album artwork (image/jpeg) |
| `GET /api/stream/:id` | Audio stream with HTTP range support |
| `POST /api/scan` | Trigger library rescan |
| `GET /api/stats` | Library statistics |

All responses JSON except artwork and stream (binary). HTTP range requests on stream for seeking. Authentication via static API key from env var.

### Project Structure

```
server/
├── cmd/server/main.go
├── internal/
│   ├── api/           — HTTP handlers
│   ├── db/            — SQLite init + queries
│   ├── scanner/       — ID3 tag parsing + DB population
│   ├── model/         — domain types
│   └── middleware/     — API key auth
├── Dockerfile
└── go.mod
```

### Data Model

- **Artist:** id, name, sort_name
- **Album:** id, title, artist_id, year, genre, artwork_path
- **Song:** id, title, track_number, disc_number, duration, artist_id, album_id, file_path, file_size, bitrate, format

### Scanning

`POST /api/scan` walks the music directory → reads ID3 tags (`github.com/dhowden/tag`) → upserts artists/albums/songs into SQLite → extracts artwork to `artwork/` directory. Incremental: skips unchanged files by mtime + size.

---

## iOS App (Swift/SwiftUI)

### Project Structure

```
MusicPlayer/
├── App/MusicPlayerApp.swift
├── Models/         — Song, Album, Artist, Library
├── Services/
│   ├── APIClient.swift        — networking
│   ├── AudioPlayer.swift      — AVFoundation wrapper
│   ├── DownloadManager.swift  — offline storage
│   ├── LibraryCache.swift     — CoreData cache
│   └── SearchEngine.swift     — local + remote search
├── Views/
│   ├── LibraryView.swift      — browse artists/albums/songs
│   ├── AlbumDetailView.swift
│   ├── ArtistDetailView.swift
│   ├── NowPlayingView.swift
│   ├── SearchView.swift
│   ├── DownloadsView.swift
│   └── SettingsView.swift     — server URL + API key
├── CarPlay/
│   └── CarPlaySceneDelegate.swift
└── Resources/Assets.xcassets
```

### Navigation

3-tab layout: Artists / Albums / Songs with a persistent search bar. Full-screen Now Playing player. Long-press downloads songs/albums.

### CarPlay

- Root: `CPListTemplate` (Artists, Albums, Songs, Recently Added)
- Albums: `CPGridTemplate` with artwork tiles
- Song list: `CPListTemplate`, tap to play
- Now Playing: `CPNowPlayingTemplate` with scrubber, skip, shuffle
- Tab bar: `CPTabBarTemplate` (Library / Now Playing)

Songs must be downloaded before appearing in CarPlay.

### Search

Real-time results as you type (debounced 300ms). Unified results grouped by type. Recent searches saved locally.
