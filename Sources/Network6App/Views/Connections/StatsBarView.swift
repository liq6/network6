import SwiftUI
import Network6Core

struct StatsBarView: View {
    @EnvironmentObject var viewModel: NetworkViewModel

    var body: some View {
        HStack(spacing: 20) {
            // Live indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(.green)
                    .frame(width: 6, height: 6)
                Text("Live")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider().frame(height: 16)

            statItem(icon: "link", value: "\(viewModel.stats.total)", label: "Connections")
            statItem(icon: "app.badge", value: "\(viewModel.stats.apps)", label: "Apps")
            statItem(icon: "globe", value: "\(viewModel.stats.countries)", label: "Countries")
            statItem(icon: "checkmark.circle", value: "\(viewModel.stats.established)", label: "Established")

            if viewModel.stats.avgDistanceKm > 0 {
                statItem(
                    icon: "location",
                    value: viewModel.stats.avgDistanceKm < 1000
                        ? "\(Int(viewModel.stats.avgDistanceKm)) km"
                        : String(format: "%.1fk km", viewModel.stats.avgDistanceKm / 1000),
                    label: "Avg Distance"
                )
            }

            Spacer()

            // User location
            if let myLoc = viewModel.myLocation {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                    Text("\(countryFlag(myLoc.countryCode)) \(myLoc.city), \(myLoc.country)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func statItem(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.semibold)
                .font(.callout)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
