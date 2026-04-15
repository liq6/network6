import SwiftUI
import Network6Core

struct FilterBarView: View {
    @EnvironmentObject var viewModel: NetworkViewModel

    var body: some View {
        HStack(spacing: 8) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search apps, IPs, countries…", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: 300)

            Divider().frame(height: 16)

            // Protocol filter chips
            filterChip("TCP", isActive: viewModel.selectedProtocols.contains(.tcp)) {
                toggleProtocol(.tcp)
            }
            filterChip("UDP", isActive: viewModel.selectedProtocols.contains(.udp)) {
                toggleProtocol(.udp)
            }

            Divider().frame(height: 16)

            // Quick state filters
            filterChip("Established", color: .green, isActive: viewModel.selectedStates.contains(.established)) {
                viewModel.toggleStateFilter(.established)
            }
            filterChip("Listen", color: .blue, isActive: viewModel.selectedStates.contains(.listen)) {
                viewModel.toggleStateFilter(.listen)
            }

            Spacer()

            // Active filter count
            if viewModel.hasActiveFilters {
                Button {
                    viewModel.clearFilters()
                } label: {
                    Label("Clear filters", systemImage: "xmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            // Toggle options
            Toggle(isOn: $viewModel.showAll) {
                Text("All")
                    .font(.caption)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private func filterChip(_ title: String, color: Color = .accentColor, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isActive ? .semibold : .regular)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .foregroundStyle(isActive ? .white : .primary)
                .background(isActive ? color : Color.clear, in: Capsule())
                .overlay(Capsule().stroke(color.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func toggleProtocol(_ proto: ConnectionProtocol) {
        if viewModel.selectedProtocols.contains(proto) {
            viewModel.selectedProtocols.remove(proto)
        } else {
            viewModel.selectedProtocols.insert(proto)
        }
    }
}
