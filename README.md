# Network6

> Open-source macOS network monitor — visualize all your connections in real time, Little Snitch style.

Network6 ships as both a **terminal CLI** (`network6`) and a native **SwiftUI desktop app** (`Network6.app`), powered by a shared `Network6Core` library.

## Features

### Core

- 🔍 **Real-time monitoring** of every TCP/UDP connection (flicker-free, `top`-style refresh)
- 🌍 **GeoIP resolution** — country, city, region, and organization for every remote IP
- 🔗 **Reverse DNS** with built-in cache
- 📋 **Rich metadata** — application name, PID, process path, protocol, state, ports, user
- 🏷️ **Port labels** — automatic service identification (HTTPS, SSH, DNS, …)
- 📏 **Distance calculation** — see how far each server is from your location

### SwiftUI Desktop App ✨ _New_

- 🗺️ **Interactive world map** — server pins with arc lines from your location, color-coded by connection state
- 📊 **Live stats bar** — total connections, unique apps, countries, established count, average distance
- 🔎 **Advanced filtering** — search across apps/IPs/countries, filter by protocol (TCP/UDP), state, organization, or country
- 🗂️ **Sidebar navigation** — browse by organization, country, or connection state with live counts
- 📄 **Connection detail panel** — full info for the selected connection (hostname, IP, port, location, org, distance, duration)
- 📤 **CSV & JSON export** — export filtered connections via `⌘E` / `⇧⌘E`
- 📋 **Context-menu actions** — copy IP, hostname, or full connection details with a right-click
- 💿 **DMG distribution** — build script generates a ready-to-install `.app` bundle and `.dmg`

### CLI

- 🎨 **Colorized ANSI output** with alternate screen buffer (no scroll pollution)
- ⚡ **Lightweight** — single binary, no dependencies at runtime
- 🔧 **Flexible options** — filter, sort, toggle DNS/GeoIP, show all or established-only

## Requirements

- macOS 14 (Sonoma) or later
- Swift 5.9+

## Installation

### CLI

```bash
git clone https://github.com/liq6/Network6.git
cd Network6
swift build -c release

# Install the binary
cp .build/release/network6 /usr/local/bin/
```

### Desktop App

```bash
# Build the .app bundle and DMG
./scripts/build-dmg.sh 1.0.0

# Output:
#   dist/Network6.app   — drag to /Applications
#   dist/Network6-1.0.0.dmg
```

Or build directly with Swift:

```bash
swift build -c release --product Network6App
```

## CLI Usage

```bash
# Start monitoring (user mode)
network6

# Run as root for full visibility (recommended)
sudo network6

# Refresh every 5 seconds
network6 --refresh 5

# Filter by application name
network6 --filter Safari

# Show only ESTABLISHED connections
network6 --established

# Include LISTEN ports
network6 --listen

# Show everything (LISTEN, bound UDP, etc.)
network6 --all

# Sort by country
network6 --sort country

# Sort by distance from your location
network6 --sort distance

# Skip DNS and/or GeoIP for faster output
network6 --no-dns --no-geo
```

## CLI Options

| Option | Description | Default |
|--------|-------------|---------|
| `--refresh, -r` | Refresh interval in seconds | 2.0 |
| `--filter, -f` | Filter by application name (substring) | — |
| `--sort, -s` | Sort by: `app`, `remote`, `port`, `state`, `country`, `pid`, `distance` | `app` |
| `--established` | Show only ESTABLISHED connections | `false` |
| `--listen` | Include LISTEN ports | `false` |
| `--all, -a` | Show all connections (LISTEN, UDP bound, etc.) | `false` |
| `--no-dns` | Disable reverse DNS resolution | `false` |
| `--no-geo` | Disable GeoIP resolution | `false` |

## CLI Columns

| Column | Description |
|--------|-------------|
| APPLICATION | Process name |
| PID | Process identifier |
| PROTO | TCP / UDP |
| STATE | ESTABLISHED, LISTEN, TIME_WAIT, … |
| LOCAL | Local address and port |
| REMOTE | Hostname or remote IP |
| PORT | Remote port + service label |
| LOCATION | Country and city of the server |
| DIST | Distance from your location (km) |
| ORG | Organization that owns the IP |
| TIME | Connection duration |

## Architecture

```
Network6/
├── Sources/
│   ├── Network6Core/            # Shared library (reusable by CLI & App)
│   │   ├── Models/              # ConnectionInfo, GeoLocation
│   │   ├── Monitors/            # ConnectionMonitor (lsof-based capture)
│   │   └── Resolvers/           # DNS, GeoIP, Process path, Port labels
│   ├── Network6CLI/             # Terminal application
│   │   ├── Network6App.swift    # CLI entry point (ArgumentParser)
│   │   └── ConsoleRenderer.swift# Flicker-free ANSI renderer
│   └── Network6App/             # SwiftUI desktop application
│       ├── Views/               # ContentView, Sidebar, Connections, Map
│       ├── ViewModels/          # NetworkViewModel (reactive state)
│       └── Helpers/             # Colors, utilities
├── Tests/
│   └── Network6CoreTests/       # Unit tests
├── scripts/
│   ├── build-dmg.sh             # Builds .app bundle + DMG
│   └── generate-icon.swift      # Programmatic app icon generator
└── dist/                        # Build artifacts (app, dmg)
```

`Network6Core` is a pure Swift library with no UI dependencies — it can be imported by the CLI, the SwiftUI app, or any future target without modification.

## License

MIT — see [LICENSE](LICENSE)

