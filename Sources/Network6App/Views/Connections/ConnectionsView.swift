import SwiftUI
import Network6Core

struct ConnectionsView: View {
    @EnvironmentObject var viewModel: NetworkViewModel
    @State private var showDetail = true
    @State private var sortOrder = [KeyPathComparator(\ConnectionInfo.processName)]

    private var sortedConnections: [ConnectionInfo] {
        viewModel.filteredConnections.sorted(using: sortOrder)
    }

    var body: some View {
        VStack(spacing: 0) {
            StatsBarView()
                .environmentObject(viewModel)

            FilterBarView()
                .environmentObject(viewModel)

            HSplitView {
                connectionTable
                    .frame(minWidth: 600)
                    .overlay(alignment: .topTrailing) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showDetail.toggle()
                            }
                        } label: {
                            Image(systemName: showDetail ? "sidebar.trailing" : "sidebar.leading")
                                .font(.system(size: 12, weight: .medium))
                                .frame(width: 28, height: 28)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .help(showDetail ? "Hide details" : "Show details")
                        .padding(8)
                    }

                if showDetail,
                   let selectedId = viewModel.selectedConnectionId,
                   let conn = viewModel.filteredConnections.first(where: { $0.id == selectedId }) {
                    ConnectionDetailView(connection: conn)
                        .frame(minWidth: 260, idealWidth: 300, maxWidth: 400)
                }
            }
        }
    }

    private var connectionTable: some View {
        Table(sortedConnections, selection: $viewModel.selectedConnectionId, sortOrder: $sortOrder) {
            TableColumn("") { conn in
                Circle()
                    .fill(AppColors.color(for: conn.state))
                    .frame(width: 8, height: 8)
            }
            .width(20)

            TableColumn("Application", value: \.processName) { conn in
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

            TableColumn("Remote", value: \.remoteDisplay) { conn in
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

            TableColumn("Port", value: \.remotePort) { conn in
                HStack(spacing: 4) {
                    Text(conn.portLabel.map { "\(conn.remotePort)/\($0)" } ?? "\(conn.remotePort)")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(conn.portLabel != nil ? .primary : .secondary)
                    ProtocolBadge(proto: conn.protocol)
                }
            }
            .width(min: 90, ideal: 120)

            TableColumn("State", value: \.stateSortKey) { conn in
                StatusBadge(state: conn.state)
            }
            .width(min: 80, ideal: 100)

            TableColumn("Location", value: \.locationSortKey) { conn in
                CountryLabel(geo: conn.geoLocation)
            }
            .width(min: 100, ideal: 150)

            TableColumn("Distance", value: \.distanceSortKey) { conn in
                Text(conn.distanceDisplay)
                    .foregroundStyle(.secondary)
            }
            .width(min: 60, ideal: 80)

            TableColumn("Org", value: \.orgSortKey) { conn in
                Text(conn.geoLocation?.org ?? "—")
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
            .width(min: 80, ideal: 130)
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
