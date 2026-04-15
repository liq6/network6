import SwiftUI
import Network6Core

struct ConnectionsView: View {
    @EnvironmentObject var viewModel: NetworkViewModel

    var body: some View {
        VStack(spacing: 0) {
            StatsBarView()
                .environmentObject(viewModel)

            FilterBarView()
                .environmentObject(viewModel)

            HSplitView {
                connectionTable
                    .frame(minWidth: 600)

                if let selectedId = viewModel.selectedConnectionId,
                   let conn = viewModel.filteredConnections.first(where: { $0.id == selectedId }) {
                    ConnectionDetailView(connection: conn)
                        .frame(minWidth: 260, idealWidth: 300, maxWidth: 400)
                }
            }
        }
    }

    private var connectionTable: some View {
        Table(viewModel.filteredConnections, selection: $viewModel.selectedConnectionId) {
            TableColumn("") { conn in
                Circle()
                    .fill(AppColors.color(for: conn.state))
                    .frame(width: 8, height: 8)
            }
            .width(20)

            TableColumn("Application") { conn in
                HStack(spacing: 6) {
                    Image(systemName: "app.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Text(conn.processName)
                        .lineLimit(1)
                        .fontWeight(.medium)
                }
                .background(
                    viewModel.newConnectionIds.contains(conn.id)
                        ? AppColors.newHighlight : Color.clear
                )
            }
            .width(min: 120, ideal: 160)

            TableColumn("Remote") { conn in
                VStack(alignment: .leading, spacing: 1) {
                    Text(conn.remoteDisplay)
                        .lineLimit(1)
                        .font(.system(.body, design: .monospaced))
                    if let hostname = conn.hostname, hostname != conn.remoteAddress {
                        Text(conn.remoteAddress)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .width(min: 140, ideal: 200)

            TableColumn("Port") { conn in
                Text(conn.portLabel.map { "\(conn.remotePort)/\($0)" } ?? "\(conn.remotePort)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(conn.portLabel != nil ? .primary : .secondary)
            }
            .width(min: 70, ideal: 90)

            TableColumn("Proto") { conn in
                ProtocolBadge(proto: conn.protocol)
            }
            .width(50)

            TableColumn("State") { conn in
                StatusBadge(state: conn.state)
            }
            .width(min: 80, ideal: 100)

            TableColumn("Location") { conn in
                CountryLabel(geo: conn.geoLocation)
            }
            .width(min: 100, ideal: 150)

            TableColumn("Distance") { conn in
                Text(conn.distanceDisplay)
                    .foregroundStyle(.secondary)
            }
            .width(min: 60, ideal: 80)

            TableColumn("Org") { conn in
                Text(conn.geoLocation?.org ?? "—")
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
            .width(min: 80, ideal: 130)

            TableColumn("Time") { conn in
                Text(conn.duration)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .width(60)
        }
        .contextMenu(forSelectionType: ConnectionInfo.ID.self) { ids in
            if let id = ids.first, let conn = viewModel.filteredConnections.first(where: { $0.id == id }) {
                Button("Copy IP Address") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(conn.remoteAddress, forType: .string)
                }
                Button("Copy Hostname") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(conn.hostname ?? conn.remoteAddress, forType: .string)
                }
                Divider()
                Button("Copy All Info") {
                    let info = """
                    Application: \(conn.processName) (PID: \(conn.pid))
                    Remote: \(conn.remoteDisplay) (\(conn.remoteAddress):\(conn.remotePort))
                    Protocol: \(conn.protocol.shortName) | State: \(conn.state.rawValue)
                    Location: \(conn.locationDisplay)
                    Org: \(conn.geoLocation?.org ?? "—")
                    Distance: \(conn.distanceDisplay)
                    """
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(info, forType: .string)
                }
            }
        }
    }
}

import AppKit
