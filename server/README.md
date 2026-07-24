# Music Server

Dockerized Go server that serves your MP3 collection via REST API with artwork, search, and streaming.

## Quick Start

### 1. Prepare your music

Place your MP3 files (or M4A/FLAC/OGG) in a directory on your host machine. The scanner reads ID3 tags (artist, album, title, artwork) automatically.

### 2. Configure and run

```bash
# Edit docker-compose.yml to point MUSIC_DIR to your music folder
# Then:
docker compose up -d
```

The server will start on port 8080. Point your iOS app (or any HTTP client) to `http://<your-server-ip>:8080`.

### 3. Scan your library

```bash
curl -X POST http://localhost:8080/api/scan \
  -H "X-API-Key: your-secret-key"
```

### 4. Browse

```bash
# List all songs
curl http://localhost:8080/api/songs -H "X-API-Key: your-secret-key"

# List all albums
curl http://localhost:8080/api/albums -H "X-API-Key: your-secret-key"

# Search for "Daft Punk"
curl "http://localhost:8080/api/search?q=Daft" -H "X-API-Key: your-secret-key"
```

## Adding MP3 Files

1. Copy new MP3 files into your music directory (the one mounted in docker-compose.yml)
2. Run `POST /api/scan` — the server will detect new/changed files and update the database
3. Scans are incremental: only new and modified files are processed

## Configuration

| Env Variable | Default | Description |
|---|---|---|
| `API_KEY` | *(required)* | Secret key for API authentication |
| `LISTEN_ADDR` | `:8080` | Server listen address |
| `MUSIC_DIR` | `/music` | Path to music files |
| `DB_PATH` | `/data/music.db` | SQLite database location |
| `ARTWORK_DIR` | `/data/artwork` | Extracted album art location |

## API Endpoints

All endpoints (except scan, which is POST) are GET. All require `X-API-Key` header.

| Endpoint | Description |
|---|---|
| `GET /api/songs?page=&limit=` | Paginated song list |
| `GET /api/songs/:id` | Single song metadata |
| `GET /api/albums?page=&limit=` | Album list |
| `GET /api/albums/:id` | Album detail with track list |
| `GET /api/artists?page=&limit=` | Artist list |
| `GET /api/artists/:id` | Artist detail with albums |
| `GET /api/search?q=` | Search songs, albums, artists |
| `GET /api/artwork/:id` | Album artwork image (JPEG) |
| `GET /api/stream/:id` | Audio stream (supports seeking) |
| `POST /api/scan` | Trigger library rescan |
| `GET /api/stats` | Library statistics |

## Building

```bash
docker compose build
```

## Development

```bash
cd server
go run ./cmd/server
```

Requires Go 1.22+ and CGO_ENABLED=0 (the SQLite driver is pure Go).
