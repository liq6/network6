import SwiftUI
import Network6Core

struct ConnectionDetailView: View {
    let connection: ConnectionInfo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(connection.processName)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("PID: \(connection.pid)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusBadge(state: connection.state)
                }

                Divider()

                // Remote server
                detailSection("Remote Server", icon: "globe") {
                    detailRow("Hostname", connection.hostname ?? "—")
                    detailRow("IP Address", connection.remoteAddress)
                    detailRow("Port", connection.portLabel.map { "\(connection.remotePort) (\($0))" } ?? "\(connection.remotePort)")
                    detailRow("Protocol", connection.protocol.shortName)
                }

                // Location
                if let geo = connection.geoLocation {
                    detailSection("Location", icon: "map") {
                        detailRow("Country", "\(countryFlag(geo.countryCode)) \(geo.country)")
                        detailRow("City", geo.city.isEmpty ? "—" : geo.city)
                        detailRow("Region", geo.region.isEmpty ? "—" : geo.region)
                        detailRow("Organization", geo.org.isEmpty ? "—" : geo.org)
                        detailRow("ISP", geo.isp.isEmpty ? "—" : geo.isp)
                        detailRow("AS", geo.asNumber.isEmpty ? "—" : geo.asNumber)
                        detailRow("Coordinates", String(format: "%.4f, %.4f", geo.lat, geo.lon))
                    }
                }

                // Distance
                if let km = connection.distanceKm {
                    detailSection("Distance", icon: "location") {
                        detailRow("Distance", connection.distanceDisplay)
                        detailRow("Km", String(format: "%.1f km", km))
                    }
                }

                // Local
                detailSection("Local Endpoint", icon: "desktopcomputer") {
                    detailRow("Address", connection.localAddress)
                    detailRow("Port", "\(connection.localPort)")
                    detailRow("User", connection.user.isEmpty ? "—" : connection.user)
                }

                // Process
                detailSection("Process", icon: "gearshape") {
                    detailRow("Name", connection.processName)
                    detailRow("PID", "\(connection.pid)")
                    detailRow("Path", connection.processPath.isEmpty ? "—" : connection.processPath)
                    detailRow("Duration", connection.duration)
                }
            }
            .padding()
        }
        .background(.background)
    }

    private func detailSection(_ title: String, icon: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.primary)
            content()
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)
            Text(value)
                .font(.callout)
                .textSelection(.enabled)
            Spacer()
        }
    }
}
