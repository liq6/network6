import Foundation
import Network6Core
import ArgumentParser

@main
struct Network6App: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "network6",
        abstract: "Monitor network connections in real-time on macOS.",
        version: "0.1.0"
    )

    @Option(name: .shortAndLong, help: "Refresh interval in seconds.")
    var refresh: Double = 2.0

    @Option(name: .shortAndLong, help: "Filter by application name (substring match).")
    var filter: String?

    @Option(name: .shortAndLong, help: "Sort by column: app, remote, port, state, country, pid, distance.")
    var sort: SortColumn = .app

    @Flag(name: .long, help: "Skip DNS reverse resolution.")
    var noDns: Bool = false

    @Flag(name: .long, help: "Skip GeoIP resolution.")
    var noGeo: Bool = false

    @Flag(name: .long, help: "Show only ESTABLISHED connections.")
    var established: Bool = false

    @Flag(name: .long, help: "Include LISTEN ports.")
    var listen: Bool = false

    @Flag(name: .shortAndLong, help: "Show all connections (LISTEN, UDP bound, etc.).")
    var all: Bool = false

    enum SortColumn: String, ExpressibleByArgument, CaseIterable {
        case app, remote, port, state, country, pid, distance
    }

    func run() async throws {
        let monitor = ConnectionMonitor()
        let dnsResolver = DNSResolver()
        let geoResolver = GeoIPResolver()
        let processResolver = ProcessResolver()
        var renderer = ConsoleRenderer()
        let isRoot = getuid() == 0

        // Setup signal handler for clean exit
        signal(SIGINT) { _ in
            ConsoleRenderer.teardown()
            print("\nNetwork6 stopped.")
            Darwin.exit(0)
        }
        signal(SIGTERM) { _ in
            ConsoleRenderer.teardown()
            Darwin.exit(0)
        }

        // Enter alternate screen buffer, hide cursor
        renderer.setup()

        // Resolve user's own location once at startup
        if !noGeo {
            let _ = await geoResolver.resolveMyLocation()
        }

        while true {
            do {
                var connections = try await monitor.refresh()

                // Enrich with process paths
                for i in connections.indices {
                    let path = processResolver.resolvePath(pid: connections[i].pid)
                    if !path.isEmpty {
                        connections[i] = ConnectionInfo(
                            pid: connections[i].pid,
                            processName: connections[i].processName,
                            processPath: path,
                            user: connections[i].user,
                            protocol: connections[i].protocol,
                            state: connections[i].state,
                            localAddress: connections[i].localAddress,
                            localPort: connections[i].localPort,
                            remoteAddress: connections[i].remoteAddress,
                            remotePort: connections[i].remotePort,
                            portLabel: connections[i].portLabel,
                            hostname: connections[i].hostname,
                            geoLocation: connections[i].geoLocation,
                            firstSeen: connections[i].firstSeen
                        )
                    }
                }

                // DNS resolution
                if !noDns {
                    let ips = connections.compactMap { $0.remoteAddress.isEmpty ? nil : $0.remoteAddress }
                    let hostnames = await dnsResolver.resolveAll(ips)
                    for i in connections.indices {
                        if let hostname = hostnames[connections[i].remoteAddress] {
                            connections[i].hostname = hostname
                        }
                    }
                }

                // GeoIP resolution
                if !noGeo {
                    let ips = connections.compactMap { $0.remoteAddress.isEmpty ? nil : $0.remoteAddress }
                    let geos = await geoResolver.resolveAll(ips)
                    let myLocation = await geoResolver.getMyLocation()
                    for i in connections.indices {
                        if let geo = geos[connections[i].remoteAddress] {
                            connections[i].geoLocation = geo
                            if let myLoc = myLocation {
                                connections[i].distanceKm = myLoc.distance(to: geo)
                            }
                        }
                    }
                }

                // Filter
                if let filter = filter {
                    let lowerFilter = filter.lowercased()
                    connections = connections.filter {
                        $0.processName.lowercased().contains(lowerFilter)
                    }
                }

                if established {
                    connections = connections.filter { $0.state == .established }
                } else if !all {
                    // By default, hide LISTEN and UDP-bound (no remote) sockets
                    if !listen {
                        connections = connections.filter { $0.state != .listen }
                    }
                    connections = connections.filter { conn in
                        // Keep if it has a remote address, or if it's a LISTEN we chose to keep
                        !conn.remoteAddress.isEmpty || conn.state == .listen
                    }
                }

                // Sort
                connections.sort { a, b in
                    switch sort {
                    case .app: return a.processName.lowercased() < b.processName.lowercased()
                    case .remote: return a.remoteDisplay < b.remoteDisplay
                    case .port: return a.remotePort < b.remotePort
                    case .state: return a.state.rawValue < b.state.rawValue
                    case .country: return a.locationDisplay < b.locationDisplay
                    case .pid: return a.pid < b.pid
                    case .distance: return (a.distanceKm ?? .infinity) < (b.distanceKm ?? .infinity)
                    }
                }

                let myLoc = await geoResolver.getMyLocation()
                let myLocDisplay = myLoc?.summary
                renderer.render(connections: connections, isRoot: isRoot, myLocation: myLocDisplay)

            } catch {
                print("\u{1B}[31mError: \(error.localizedDescription)\u{1B}[0m")
            }

            try await Task.sleep(nanoseconds: UInt64(refresh * 1_000_000_000))
        }
    }
}
