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
                        MapPolyline(coordinates: [userCoord, server.coordinate])
                            .stroke(
                                lineColor(for: server),
                                style: StrokeStyle(lineWidth: lineWidth(for: server), dash: [8, 4])
                            )
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, emphasis: .muted))
            .mapControls {
                MapCompass()
                MapZoomStepper()
            }

            // Overlay: stats panel
            VStack {
                HStack {
                    Spacer()
                    if showStats {
                        mapStatsPanel
                    }
                }
                Spacer()
                // Bottom bar: selected server info + controls
                HStack {
                    if let server = selectedServer {
                        selectedServerBar(server)
                    }
                    Spacer()
                    mapControls
                }
            }
            .padding()
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
        .frame(width: 200)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Selected server info bar
    private func selectedServerBar(_ server: ServerLocation) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(server.geo.city.isEmpty ? server.geo.country : "\(server.geo.city), \(server.geo.country)")
                    .fontWeight(.semibold)
                Text(server.geo.org)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider().frame(height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(server.connectionCount) connection\(server.connectionCount > 1 ? "s" : "")")
                    .font(.caption)
                let apps = Set(server.connections.map(\.processName))
                Text(apps.joined(separator: ", "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let myLoc = viewModel.myLocation {
                Divider().frame(height: 30)
                let dist = server.geo.distance(to: myLoc)
                Text(dist < 1000 ? "\(Int(dist)) km" : String(format: "%.1fk km", dist / 1000))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Map controls
    private var mapControls: some View {
        VStack(spacing: 8) {
            Button {
                withAnimation {
                    cameraPosition = .automatic
                }
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption)
                    .padding(8)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .help("Fit all connections")

            Button {
                showStats.toggle()
            } label: {
                Image(systemName: showStats ? "sidebar.right" : "sidebar.left")
                    .font(.caption)
                    .padding(8)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .help("Toggle stats panel")
        }
    }

    // MARK: - Helpers
    private func lineColor(for server: ServerLocation) -> Color {
        if selectedServer?.id == server.id {
            return .accentColor
        }
        return AppColors.color(for: server.primaryState).opacity(0.4)
    }

    private func lineWidth(for server: ServerLocation) -> CGFloat {
        if selectedServer?.id == server.id { return 2.5 }
        return min(CGFloat(server.connectionCount), 4) * 0.5 + 0.5
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
