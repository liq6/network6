import SwiftUI
import Foundation
import Network6Core

@MainActor
class NetworkViewModel: ObservableObject {
    // MARK: - Published state
    @Published var connections: [ConnectionInfo] = []
    @Published var myLocation: GeoLocation?
    @Published var isLoading = true
    @Published var loadingStatus = "Starting…"
    @Published var isRefreshing = false
    @Published var searchText = ""
    @Published var selectedStates: Set<ConnectionState> = []
    @Published var selectedApps: Set<String> = []
    @Published var selectedCountries: Set<String> = []
    @Published var selectedProtocols: Set<ConnectionProtocol> = []
    @Published var selectedConnectionId: ConnectionInfo.ID?
    @Published var showListenPorts = false
    @Published var showAll = false
    @Published var refreshInterval: Double = 2.0
    @Published var lastRefresh = Date()
    @Published var newConnectionIds: Set<String> = []

    // MARK: - Core services
    private let monitor = ConnectionMonitor()
    private let dnsResolver = DNSResolver()
    private let geoResolver = GeoIPResolver()
    private let processResolver = ProcessResolver()
    private var monitoringTask: Task<Void, Never>?

    // MARK: - Computed: filtered & sorted connections
    var filteredConnections: [ConnectionInfo] {
        var result = connections

        // State filters
        if !showAll {
            if !showListenPorts {
                result = result.filter { $0.state != .listen }
            }
            result = result.filter { conn in
                !conn.remoteAddress.isEmpty || conn.state == .listen
            }
        }

        if !selectedStates.isEmpty {
            result = result.filter { selectedStates.contains($0.state) }
        }

        if !selectedApps.isEmpty {
            result = result.filter { selectedApps.contains($0.processName) }
        }

        if !selectedCountries.isEmpty {
            result = result.filter { conn in
                guard let geo = conn.geoLocation else { return false }
                return selectedCountries.contains(geo.countryCode)
            }
        }

        if !selectedProtocols.isEmpty {
            result = result.filter { selectedProtocols.contains($0.protocol) }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { conn in
                conn.processName.lowercased().contains(query) ||
                conn.remoteAddress.lowercased().contains(query) ||
                (conn.hostname?.lowercased().contains(query) ?? false) ||
                (conn.geoLocation?.country.lowercased().contains(query) ?? false) ||
                (conn.geoLocation?.city.lowercased().contains(query) ?? false) ||
                (conn.geoLocation?.org.lowercased().contains(query) ?? false) ||
                conn.portLabel?.lowercased().contains(query) ?? false ||
                "\(conn.remotePort)".contains(query)
            }
        }

        return result.sorted { $0.processName.lowercased() < $1.processName.lowercased() }
    }

    // MARK: - Computed: sidebar data
    var uniqueApps: [(name: String, count: Int)] {
        let grouped = Dictionary(grouping: connections) { $0.processName }
        return grouped.map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    var uniqueCountries: [(name: String, code: String, flag: String, count: Int)] {
        let withGeo = connections.compactMap { $0.geoLocation }
        let grouped = Dictionary(grouping: withGeo) { $0.countryCode }
        return grouped.compactMap { code, geos in
            guard let first = geos.first, !code.isEmpty else { return nil }
            return (
                name: first.country,
                code: code,
                flag: countryFlag(code),
                count: geos.count
            )
        }.sorted { $0.count > $1.count }
    }

    var uniqueStates: [(state: ConnectionState, count: Int)] {
        let grouped = Dictionary(grouping: connections) { $0.state }
        return grouped.map { (state: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    var stats: ConnectionStats {
        let filtered = filteredConnections
        let apps = Set(filtered.map(\.processName)).count
        let countries = Set(filtered.compactMap { $0.geoLocation?.countryCode }).count
        let established = filtered.filter { $0.state == .established }.count
        let avgDistance = filtered.compactMap(\.distanceKm).reduce(0, +) / max(1, Double(filtered.compactMap(\.distanceKm).count))
        return ConnectionStats(
            total: filtered.count,
            apps: apps,
            countries: countries,
            established: established,
            avgDistanceKm: avgDistance
        )
    }

    var hasActiveFilters: Bool {
        !searchText.isEmpty || !selectedStates.isEmpty || !selectedApps.isEmpty ||
        !selectedCountries.isEmpty || !selectedProtocols.isEmpty
    }

    // MARK: - Server locations for map
    var serverLocations: [ServerLocation] {
        var locationMap: [String: ServerLocation] = [:]
        for conn in filteredConnections {
            guard let geo = conn.geoLocation, geo.lat != 0 || geo.lon != 0 else { continue }
            let key = "\(geo.lat),\(geo.lon)"
            if var existing = locationMap[key] {
                existing.connections.append(conn)
                locationMap[key] = existing
            } else {
                locationMap[key] = ServerLocation(
                    coordinate: CLLocationCoordinate2D(latitude: geo.lat, longitude: geo.lon),
                    geo: geo,
                    connections: [conn]
                )
            }
        }
        return Array(locationMap.values)
    }

    // MARK: - Actions
    func startMonitoring() async {
        isLoading = true
        loadingStatus = "Scanning connections…"

        // Run location resolve and first connection scan in parallel
        async let locationTask: GeoLocation? = {
            // 5 second timeout on geolocation
            return await withTaskGroup(of: GeoLocation?.self) { group in
                group.addTask { await self.geoResolver.resolveMyLocation() }
                group.addTask {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    return nil
                }
                // Return whichever finishes first
                for await result in group {
                    if result != nil {
                        group.cancelAll()
                        return result
                    }
                }
                return nil
            }
        }()
        async let scanTask: Void = refresh()

        let loc = await locationTask
        _ = await scanTask
        myLocation = loc
        isLoading = false

        monitoringTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(refreshInterval * 1_000_000_000))
                await refresh()
            }
        }
    }

    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            var conns = try await monitor.refresh()
            let previousIds = Set(connections.map(\.id))

            // Enrich with process paths
            for i in conns.indices {
                let path = processResolver.resolvePath(pid: conns[i].pid)
                if !path.isEmpty {
                    conns[i] = ConnectionInfo(
                        pid: conns[i].pid,
                        processName: conns[i].processName,
                        processPath: path,
                        user: conns[i].user,
                        protocol: conns[i].protocol,
                        state: conns[i].state,
                        localAddress: conns[i].localAddress,
                        localPort: conns[i].localPort,
                        remoteAddress: conns[i].remoteAddress,
                        remotePort: conns[i].remotePort,
                        portLabel: conns[i].portLabel,
                        hostname: conns[i].hostname,
                        geoLocation: conns[i].geoLocation,
                        firstSeen: conns[i].firstSeen
                    )
                }
            }

            // DNS resolution
            let ips = conns.compactMap { $0.remoteAddress.isEmpty ? nil : $0.remoteAddress }
            let hostnames = await dnsResolver.resolveAll(ips)
            for i in conns.indices {
                if let hostname = hostnames[conns[i].remoteAddress] {
                    conns[i].hostname = hostname
                }
            }

            // GeoIP resolution
            let geos = await geoResolver.resolveAll(ips)
            let myLoc = await geoResolver.getMyLocation()
            for i in conns.indices {
                if let geo = geos[conns[i].remoteAddress] {
                    conns[i].geoLocation = geo
                    if let myLoc = myLoc {
                        conns[i].distanceKm = myLoc.distance(to: geo)
                    }
                }
            }

            // Track new connections
            let currentIds = Set(conns.map(\.id))
            let newIds = currentIds.subtracting(previousIds)
            newConnectionIds = newIds

            // Clear "new" highlight after delay
            if !newIds.isEmpty {
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    newConnectionIds.subtract(newIds)
                }
            }

            connections = conns
            lastRefresh = Date()
        } catch {
            // Silently handle errors
        }
    }

    // MARK: - Filter toggles
    func toggleAppFilter(_ app: String) {
        if selectedApps.contains(app) {
            selectedApps.remove(app)
        } else {
            selectedApps.insert(app)
        }
    }

    func toggleCountryFilter(_ code: String) {
        if selectedCountries.contains(code) {
            selectedCountries.remove(code)
        } else {
            selectedCountries.insert(code)
        }
    }

    func toggleStateFilter(_ state: ConnectionState) {
        if selectedStates.contains(state) {
            selectedStates.remove(state)
        } else {
            selectedStates.insert(state)
        }
    }

    func clearFilters() {
        searchText = ""
        selectedStates.removeAll()
        selectedApps.removeAll()
        selectedCountries.removeAll()
        selectedProtocols.removeAll()
    }

    // MARK: - Export
    func exportCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "network6-export.csv"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let csv = self.buildCSV()
            try? csv.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    func exportJSON() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "network6-export.json"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let json = self.buildJSON()
            try? json.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func buildCSV() -> String {
        var csv = "Application,PID,Protocol,State,Local Address,Local Port,Remote Address,Remote Port,Hostname,Country,City,Org,Distance (km),Duration\n"
        for conn in filteredConnections {
            let line = [
                conn.processName,
                "\(conn.pid)",
                conn.protocol.shortName,
                conn.state.rawValue,
                conn.localAddress,
                "\(conn.localPort)",
                conn.remoteAddress,
                "\(conn.remotePort)",
                conn.hostname ?? "",
                conn.geoLocation?.country ?? "",
                conn.geoLocation?.city ?? "",
                conn.geoLocation?.org ?? "",
                conn.distanceKm.map { "\(Int($0))" } ?? "",
                conn.duration
            ].map { "\"\($0)\"" }.joined(separator: ",")
            csv += line + "\n"
        }
        return csv
    }

    private func buildJSON() -> String {
        var items: [[String: Any]] = []
        for conn in filteredConnections {
            var dict: [String: Any] = [
                "application": conn.processName,
                "pid": conn.pid,
                "protocol": conn.protocol.shortName,
                "state": conn.state.rawValue,
                "localAddress": conn.localAddress,
                "localPort": conn.localPort,
                "remoteAddress": conn.remoteAddress,
                "remotePort": conn.remotePort,
                "duration": conn.duration
            ]
            if let h = conn.hostname { dict["hostname"] = h }
            if let g = conn.geoLocation {
                dict["country"] = g.country
                dict["city"] = g.city
                dict["org"] = g.org
                dict["lat"] = g.lat
                dict["lon"] = g.lon
            }
            if let d = conn.distanceKm { dict["distanceKm"] = Int(d) }
            items.append(dict)
        }
        guard let data = try? JSONSerialization.data(withJSONObject: items, options: .prettyPrinted),
              let str = String(data: data, encoding: .utf8) else { return "[]" }
        return str
    }

    // MARK: - Helpers
    private func countryFlag(_ code: String) -> String {
        let base: UInt32 = 127397
        return code.uppercased().unicodeScalars.compactMap { UnicodeScalar(base + $0.value) }
            .map { String($0) }.joined()
    }
}

// MARK: - Supporting types
struct ConnectionStats {
    let total: Int
    let apps: Int
    let countries: Int
    let established: Int
    let avgDistanceKm: Double
}

struct ServerLocation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let geo: GeoLocation
    var connections: [ConnectionInfo]

    var connectionCount: Int { connections.count }
    var primaryState: ConnectionState {
        let states = connections.map(\.state)
        return states.first(where: { $0 == .established }) ?? states.first ?? .unknown
    }
}

import AppKit
import UniformTypeIdentifiers
import CoreLocation
