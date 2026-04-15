import SwiftUI
import Network6Core

struct StatusBadge: View {
    let state: ConnectionState

    var body: some View {
        Text(state.rawValue)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(foregroundColor)
            .background(AppColors.color(for: state).opacity(0.15), in: Capsule())
    }

    private var foregroundColor: Color {
        AppColors.color(for: state)
    }
}

struct ProtocolBadge: View {
    let proto: ConnectionProtocol

    var body: some View {
        Text(proto.shortName)
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .foregroundStyle(AppColors.color(for: proto))
            .background(AppColors.color(for: proto).opacity(0.12), in: Capsule())
    }
}

struct CountryLabel: View {
    let geo: GeoLocation?

    var body: some View {
        if let geo = geo, !geo.countryCode.isEmpty {
            HStack(spacing: 4) {
                Text(countryFlag(geo.countryCode))
                    .font(.caption)
                Text(locationText)
                    .lineLimit(1)
            }
        } else {
            Text("—")
                .foregroundStyle(.secondary)
        }
    }

    private var locationText: String {
        guard let geo = geo else { return "" }
        var parts: [String] = []
        if !geo.city.isEmpty { parts.append(geo.city) }
        if !geo.country.isEmpty { parts.append(geo.country) }
        return parts.joined(separator: ", ")
    }
}
