import SwiftUI
import MapKit
import Network6Core

struct WorldMapView: View {
    @EnvironmentObject var viewModel: NetworkViewModel
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedServer: ServerLocation?
    @State private var showStats = true

    var body: some View {
        ZStack {
            Map(position: $cameraPosition, selection: $selectedServer) {
                // User location pin
                if let myLoc = viewModel.myLocation, myLoc.lat != 0 || myLoc.lon != 0 {
                    Annotation("You", coordinate: CLLocationCoordinate2D(latitude: myLoc.lat, longitude: myLoc.lon)) {
                        UserPinView()
                    }
                    .annotationTitles(.hidden)
                }

                // Server pins
                ForEach(viewModel.serverLocations) { server in
                    Annotation(
                        server.geo.city.isEmpty ? server.geo.country : server.geo.city,
                        coordinate: server.coordinate
                    ) {
                        ServerPinView(
                            server: server,
                            isSelected: selectedServer?.id == server.id
                        )
                    }
                    .tag(server)
                    .annotationTitles(.hidden)
                }

                // Connection lines from user to servers
                if let myLoc = viewModel.myLocation {
                    let userCoord = CLLocationCoordinate2D(latitude: myLoc.lat, longitude: myLoc.lon)
                    ForEach(viewModel.serverLocations) { server in
                        let isSelected = selectedServer?.id == server.id
                        let serverColor = AppColors.color(for: server.primaryState)
                        MapPolyline(coordinates: arcPoints(from: userCoord, to: server.coordinate))
                            .stroke(
                                .linearGradient(
                                    colors: [.blue, serverColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(
                                    lineWidth: isSelected ? 3.5 : lineWidth(for: server),
                                    lineCap: .round
                                )
                            )
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, emphasis: .muted))
            .mapControls {
                MapCompass()
                MapZoomStepper()
            }

            // Overlay panels
            VStack(spacing: 0) {
                // Top row: Network Map stats
                HStack(alignment: .top) {
                    Spacer()
                    if showStats {
                        mapStatsPanel
                    }
                }
                .padding(.top, 4)
                .padding(.horizontal)

                // Info widget below stats (right-aligned)
                HStack(alignment: .top) {
                    Spacer()
                    if let server = selectedServer {
                        ServerInfoWidget(server: server, myLocation: viewModel.myLocation) {
                            withAnimation(.easeOut(duration: 0.2)) { selectedServer = nil }
                        }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer()

                // Bottom controls
                HStack {
                    Spacer()
                    mapControls
                }
                .padding()
            }
        }
    }

    // MARK: - Stats overlay panel
    private var mapStatsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Network Map")
                .font(.headline)

            if let myLoc = viewModel.myLocation {
                HStack(spacing: 4) {
                    Text("📍")
                    Text("\(myLoc.city), \(myLoc.country)")
                        .font(.caption)
                }
            }

            Divider()

            HStack(spacing: 12) {
                VStack {
                    Text("\(viewModel.serverLocations.count)")
                        .font(.title3).fontWeight(.bold)
                    Text("Servers")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(viewModel.stats.countries)")
                        .font(.title3).fontWeight(.bold)
                    Text("Countries")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }

            // Top countries
            if !viewModel.uniqueCountries.isEmpty {
                Divider()
                Text("Top Countries")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(viewModel.uniqueCountries.prefix(5), id: \.code) { country in
                    HStack {
                        Text(country.flag)
                        Text(country.name)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text("\(country.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 280)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Map controls
    private var mapControls: some View {
        VStack(spacing: 6) {
            // Zoom in
            Button {
                zoomIn()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 32, height: 32)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .help("Zoom in")
            .keyboardShortcut("+", modifiers: [.command])

            // Zoom out
            Button {
                zoomOut()
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 32, height: 32)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .help("Zoom out")
            .keyboardShortcut("-", modifiers: [.command])

            Divider().frame(width: 20)

            // Fit all
            Button {
                fitAll()
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 32, height: 32)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .help("Fit all connections")
            .keyboardShortcut("0", modifiers: [.command])

            // Zoom to user
            if viewModel.myLocation != nil {
                Button {
                    zoomToUser()
                } label: {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 32, height: 32)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .help("Zoom to your location")
            }

            Divider().frame(width: 20)

            // Toggle stats panel
            Button {
                showStats.toggle()
            } label: {
                Image(systemName: showStats ? "sidebar.right" : "sidebar.left")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 32, height: 32)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .help("Toggle stats panel")
        }
    }

    // MARK: - Zoom actions
    @State private var currentSpan: Double = 80 // degrees

    private func zoomIn() {
        currentSpan = max(1, currentSpan * 0.5)
        applyZoom()
    }

    private func zoomOut() {
        currentSpan = min(160, currentSpan * 2)
        applyZoom()
    }

    private func applyZoom() {
        let center = currentCenter()
        withAnimation(.easeInOut(duration: 0.3)) {
            cameraPosition = .region(MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: currentSpan, longitudeDelta: currentSpan)
            ))
        }
    }

    private func currentCenter() -> CLLocationCoordinate2D {
        if let myLoc = viewModel.myLocation {
            return CLLocationCoordinate2D(latitude: myLoc.lat, longitude: myLoc.lon)
        }
        return CLLocationCoordinate2D(latitude: 30, longitude: 0)
    }

    private func fitAll() {
        withAnimation(.easeInOut(duration: 0.5)) {
            cameraPosition = .automatic
        }
        currentSpan = 80
    }

    private func zoomToUser() {
        guard let myLoc = viewModel.myLocation else { return }
        currentSpan = 20
        withAnimation(.easeInOut(duration: 0.5)) {
            cameraPosition = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: myLoc.lat, longitude: myLoc.lon),
                span: MKCoordinateSpan(latitudeDelta: 20, longitudeDelta: 20)
            ))
        }
    }

    // MARK: - Helpers

    /// Generate curved arc points between two coordinates (great-circle-like curve)
    private func arcPoints(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, segments: Int = 30) -> [CLLocationCoordinate2D] {
        var points: [CLLocationCoordinate2D] = []
        let midLat = (start.latitude + end.latitude) / 2
        let midLon = (start.longitude + end.longitude) / 2

        // Offset perpendicular to the line for the curve bulge
        let dLat = end.latitude - start.latitude
        let dLon = end.longitude - start.longitude
        let distance = sqrt(dLat * dLat + dLon * dLon)
        let bulge = distance * 0.15 // 15% of distance as curve height

        // Perpendicular offset (rotated 90°)
        let perpLat = -dLon / distance * bulge
        let perpLon = dLat / distance * bulge

        let controlLat = midLat + perpLat
        let controlLon = midLon + perpLon

        for i in 0...segments {
            let t = Double(i) / Double(segments)
            let u = 1.0 - t
            // Quadratic Bézier: B(t) = (1-t)²·P0 + 2(1-t)t·P1 + t²·P2
            let lat = u * u * start.latitude + 2 * u * t * controlLat + t * t * end.latitude
            let lon = u * u * start.longitude + 2 * u * t * controlLon + t * t * end.longitude
            points.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
        return points
    }

    private func lineWidth(for server: ServerLocation) -> CGFloat {
        let base: CGFloat = 1.5
        let extra = min(CGFloat(server.connectionCount - 1), 4) * 0.5
        return base + extra
    }
}

// MARK: - Pin views
struct UserPinView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.blue.opacity(0.2))
                .frame(width: 30, height: 30)
            Circle()
                .fill(.blue)
                .frame(width: 14, height: 14)
            Circle()
                .stroke(.white, lineWidth: 2)
                .frame(width: 14, height: 14)
        }
    }
}

struct ServerPinView: View {
    let server: ServerLocation
    let isSelected: Bool

    var body: some View {
        ZStack {
            // Outer glow for selected
            if isSelected {
                Circle()
                    .fill(AppColors.color(for: server.primaryState).opacity(0.3))
                    .frame(width: 28, height: 28)
            }

            Circle()
                .fill(AppColors.color(for: server.primaryState))
                .frame(width: pinSize, height: pinSize)
                .overlay {
                    if server.connectionCount > 1 {
                        Text("\(server.connectionCount)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .overlay(Circle().stroke(.white, lineWidth: 1.5))
        }
    }

    private var pinSize: CGFloat {
        let base: CGFloat = 12
        let extra = min(CGFloat(server.connectionCount - 1) * 2, 10)
        return base + extra
    }
}

// Make ServerLocation Hashable for Map selection
extension ServerLocation: Hashable {
    static func == (lhs: ServerLocation, rhs: ServerLocation) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Server Info Widget

struct ServerInfoWidget: View {
    let server: ServerLocation
    let myLocation: GeoLocation?
    let onClose: () -> Void

    private var apps: [(name: String, ports: String, count: Int)] {
        let grouped = Dictionary(grouping: server.connections, by: \.processName)
        return grouped.map { (name, conns) in
            let ports = Set(conns.map(\.remotePort)).sorted().prefix(5)
            let portStr = ports.map(String.init).joined(separator: ", ")
                + (conns.map(\.remotePort).count > 5 ? "…" : "")
            return (name: name, ports: portStr, count: conns.count)
        }
        .sorted { $0.count > $1.count }
    }

    private var stateCounts: [(state: ConnectionState, count: Int)] {
        let grouped = Dictionary(grouping: server.connections, by: \.state)
        return grouped.map { ($0.key, $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    private var protocolCounts: [(proto: String, count: Int)] {
        let grouped = Dictionary(grouping: server.connections, by: { $0.protocol.shortName })
        return grouped.map { ($0.key, $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            header
            Divider().padding(.horizontal, 12)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    locationSection
                    Divider()
                    networkSection
                    Divider()
                    connectionsSection
                    Divider()
                    appsSection
                }
                .padding(12)
            }
        }
        .frame(width: 280)
        .frame(maxHeight: 600)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(countryFlag(server.geo.countryCode))
                        .font(.title2)
                    Text(server.geo.city.isEmpty ? server.geo.country : server.geo.city)
                        .font(.headline)
                }
                if !server.geo.city.isEmpty {
                    Text("\(server.geo.region.isEmpty ? "" : "\(server.geo.region), ")\(server.geo.country)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
    }

    // MARK: - Location

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Location", icon: "mappin.and.ellipse")

            InfoRow(label: "Coordinates",
                    value: String(format: "%.4f, %.4f", server.geo.lat, server.geo.lon))

            if let myLoc = myLocation {
                let dist = server.geo.distance(to: myLoc)
                InfoRow(label: "Distance",
                        value: dist < 1 ? "<1 km" : dist < 1000 ? "\(Int(dist)) km" : String(format: "%.1f k km", dist / 1000),
                        valueColor: distanceColor(dist))
                InfoRow(label: "Latency estimate",
                        value: estimatedLatency(dist))
            }
        }
    }

    // MARK: - Network / Organization

    private var networkSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Network", icon: "building.2")

            if !server.geo.org.isEmpty {
                InfoRow(label: "Organization", value: server.geo.org)
            }
            if !server.geo.isp.isEmpty && server.geo.isp != server.geo.org {
                InfoRow(label: "ISP", value: server.geo.isp)
            }
            if !server.geo.asNumber.isEmpty {
                InfoRow(label: "AS Number", value: server.geo.asNumber)
            }
            InfoRow(label: "IP", value: server.geo.ip)
        }
    }

    // MARK: - Connection stats

    private var connectionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Connections", icon: "arrow.left.arrow.right")

            HStack(spacing: 16) {
                StatPill(value: "\(server.connectionCount)", label: "Total", color: .accentColor)
                ForEach(protocolCounts, id: \.proto) { item in
                    StatPill(value: "\(item.count)", label: item.proto,
                             color: item.proto == "TCP" ? .blue : .orange)
                }
            }

            // State breakdown
            HStack(spacing: 6) {
                ForEach(stateCounts, id: \.state) { item in
                    HStack(spacing: 3) {
                        Circle()
                            .fill(AppColors.color(for: item.state))
                            .frame(width: 7, height: 7)
                        Text("\(item.count)")
                            .font(.caption2)
                            .fontWeight(.medium)
                        Text(item.state.rawValue.lowercased())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Ports used
            let allPorts = Set(server.connections.map(\.remotePort)).sorted()
            if !allPorts.isEmpty {
                let portDisplay = allPorts.prefix(8).map { port -> String in
                    if let label = server.connections.first(where: { $0.remotePort == port })?.portLabel {
                        return "\(port)/\(label)"
                    }
                    return "\(port)"
                }
                InfoRow(label: "Ports",
                        value: portDisplay.joined(separator: ", ") + (allPorts.count > 8 ? " …" : ""))
            }
        }
    }

    // MARK: - Applications

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Applications", icon: "app.badge")

            ForEach(apps, id: \.name) { app in
                HStack(spacing: 8) {
                    Image(systemName: "app.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack {
                            Text(app.name)
                                .font(.callout)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            Spacer()
                            Text("\(app.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(.quaternary, in: Capsule())
                        }
                        Text("ports: \(app.ports)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.primary)
    }

    private func distanceColor(_ km: Double) -> Color {
        if km < 500 { return .green }
        if km < 3000 { return .orange }
        return .red
    }

    /// Rough latency estimate based on distance (speed of light in fiber ≈ 200,000 km/s, RTT)
    private func estimatedLatency(_ km: Double) -> String {
        let oneWayMs = km / 200.0 // ~200 km/ms in fiber
        let rtt = oneWayMs * 2
        if rtt < 1 { return "<1 ms" }
        return String(format: "~%.0f ms", rtt)
    }
}

// MARK: - Reusable row components

private struct InfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .trailing)
            Text(value)
                .font(.caption)
                .foregroundStyle(valueColor)
                .textSelection(.enabled)
            Spacer()
        }
    }
}

private struct StatPill: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 40)
    }
}


