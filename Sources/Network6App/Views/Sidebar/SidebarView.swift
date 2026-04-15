import SwiftUI
import Network6Core

struct SidebarView: View {
    @Binding var selectedSection: SidebarSection
    @EnvironmentObject var viewModel: NetworkViewModel

    var body: some View {
        List(selection: $selectedSection) {
            Section("Views") {
                ForEach(SidebarSection.allCases) { section in
                    Label(section.rawValue, systemImage: section.icon)
                        .tag(section)
                }
            }

            Section("Applications") {
                ForEach(viewModel.uniqueApps, id: \.name) { app in
                    Button {
                        viewModel.toggleAppFilter(app.name)
                    } label: {
                        HStack {
                            Image(systemName: viewModel.selectedApps.contains(app.name) ? "checkmark.circle.fill" : "app")
                                .foregroundStyle(viewModel.selectedApps.contains(app.name) ? .blue : .secondary)
                                .frame(width: 20)
                            Text(app.name)
                                .lineLimit(1)
                            Spacer()
                            Text("\(app.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Countries") {
                ForEach(viewModel.uniqueCountries, id: \.code) { country in
                    Button {
                        viewModel.toggleCountryFilter(country.code)
                    } label: {
                        HStack {
                            Text(country.flag)
                                .frame(width: 20)
                            Text(country.name)
                                .lineLimit(1)
                            Spacer()
                            Text("\(country.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.quaternary, in: Capsule())
                        }
                        .foregroundStyle(viewModel.selectedCountries.contains(country.code) ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("States") {
                ForEach(viewModel.uniqueStates, id: \.state) { item in
                    Button {
                        viewModel.toggleStateFilter(item.state)
                    } label: {
                        HStack {
                            Circle()
                                .fill(AppColors.color(for: item.state))
                                .frame(width: 8, height: 8)
                            Text(item.state.rawValue)
                                .lineLimit(1)
                            Spacer()
                            Text("\(item.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.quaternary, in: Capsule())
                        }
                        .foregroundStyle(viewModel.selectedStates.contains(item.state) ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
        .toolbar {
            ToolbarItem {
                Button {
                    viewModel.clearFilters()
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .help("Clear all filters")
                .disabled(!viewModel.hasActiveFilters)
            }
        }
    }
}
