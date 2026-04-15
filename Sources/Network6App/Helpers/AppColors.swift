import SwiftUI
import Network6Core

enum AppColors {
    static func color(for state: ConnectionState) -> Color {
        switch state {
        case .established: return .green
        case .listen: return .blue
        case .timeWait, .closeWait: return .yellow
        case .synSent, .synReceived: return .purple
        case .closed, .closing, .lastAck, .finWait1, .finWait2: return .red
        case .unknown: return .gray
        }
    }

    static func color(for proto: ConnectionProtocol) -> Color {
        switch proto {
        case .tcp, .tcp6: return .blue
        case .udp, .udp6: return .orange
        case .unknown: return .gray
        }
    }

    static let userPin = Color.blue
    static let serverPin = Color.red
    static let connectionLine = Color.cyan.opacity(0.6)
}

/// Converts a 2-letter ISO country code to its emoji flag.
func countryFlag(_ code: String) -> String {
    guard code.count == 2 else { return "🌐" }
    let base: UInt32 = 127397
    return code.uppercased().unicodeScalars.compactMap { UnicodeScalar(base + $0.value) }
        .map { String($0) }.joined()
}
