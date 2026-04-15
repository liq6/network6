import SwiftUI
import MapKit

struct ContentView: View {
    @EnvironmentObject var viewModel: NetworkViewModel
    @State private var selectedSection: SidebarSection = .connections
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selectedSection: $selectedSection)
                .environmentObject(viewModel)
                .navigationSplitViewColumnWidth(min: 180, ideal: 240, max: 400)
        } detail: {
            switch selectedSection {
            case .connections:
                ConnectionsView()
                    .environmentObject(viewModel)
            case .map:
                WorldMapView()
                    .environmentObject(viewModel)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .task {
            await viewModel.startMonitoring()
        }
    }
}

enum SidebarSection: String, CaseIterable, Identifiable {
    case connections = "Connections"
    case map = "World Map"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .connections: return "network"
        case .map: return "globe"
        }
    }
}
