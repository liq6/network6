import Foundation

/// Represents a single network connection captured from the system.
public struct ConnectionInfo: Identifiable, Sendable {
    public let id: String
    public let pid: Int
    public let processName: String
    public let processPath: String
    public let user: String
    public let `protocol`: ConnectionProtocol
    public let state: ConnectionState
    public let localAddress: String
    public let localPort: Int
    public let remoteAddress: String
    public let remotePort: Int
    public let portLabel: String?
    public var hostname: String?
    public var geoLocation: GeoLocation?
    public let firstSeen: Date

    public init(
        pid: Int,
        processName: String,
        processPath: String = "",
        user: String = "",
        protocol: ConnectionProtocol,
        state: ConnectionState,
        localAddress: String,
        localPort: Int,
        remoteAddress: String,
        remotePort: Int,
        portLabel: String? = nil,
        hostname: String? = nil,
        geoLocation: GeoLocation? = nil,
        firstSeen: Date = Date()
    ) {
        self.id = "\(pid):\(localAddress):\(localPort)-\(remoteAddress):\(remotePort)"
        self.pid = pid
        self.processName = processName
        self.processPath = processPath
        self.user = user
        self.protocol = `protocol`
        self.state = state
        self.localAddress = localAddress
        self.localPort = localPort
        self.remoteAddress = remoteAddress
        self.remotePort = remotePort
        self.portLabel = portLabel
        self.hostname = hostname
        self.geoLocation = geoLocation
        self.firstSeen = firstSeen
    }

    /// Human-readable duration since first seen
    public var duration: String {
        let interval = Date().timeIntervalSince(firstSeen)
        if interval < 60 {
            return "\(Int(interval))s"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m\(Int(interval.truncatingRemainder(dividingBy: 60)))s"
        } else {
            let h = Int(interval / 3600)
            let m = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(h)h\(m)m"
        }
    }

    /// Display string for remote endpoint
    public var remoteDisplay: String {
        if let hostname = hostname, !hostname.isEmpty {
            return hostname
        }
        return remoteAddress
    }

    /// Display string for location
    public var locationDisplay: String {
        guard let geo = geoLocation else { return "—" }
        var parts: [String] = []
        if !geo.city.isEmpty { parts.append(geo.city) }
        if !geo.country.isEmpty { parts.append(geo.country) }
        return parts.isEmpty ? "—" : parts.joined(separator: ", ")
    }
}

public enum ConnectionProtocol: String, Sendable {
    case tcp = "TCP"
    case udp = "UDP"
    case tcp6 = "TCP6"
    case udp6 = "UDP6"
    case unknown = "?"

    public init(from string: String) {
        switch string.lowercased() {
        case "tcp", "ipv4tcp": self = .tcp
        case "udp", "ipv4udp": self = .udp
        case "tcp6", "ipv6tcp": self = .tcp6
        case "udp6", "ipv6udp": self = .udp6
        default: self = .unknown
        }
    }

    public var shortName: String {
        switch self {
        case .tcp, .tcp6: return "TCP"
        case .udp, .udp6: return "UDP"
        case .unknown: return "?"
        }
    }

    public var isIPv6: Bool {
        self == .tcp6 || self == .udp6
    }
}

public enum ConnectionState: String, Sendable {
    case established = "ESTABLISHED"
    case listen = "LISTEN"
    case timeWait = "TIME_WAIT"
    case closeWait = "CLOSE_WAIT"
    case synSent = "SYN_SENT"
    case synReceived = "SYN_RECV"
    case finWait1 = "FIN_WAIT_1"
    case finWait2 = "FIN_WAIT_2"
    case closing = "CLOSING"
    case lastAck = "LAST_ACK"
    case closed = "CLOSED"
    case unknown = "UNKNOWN"

    public init(from string: String) {
        let cleaned = string.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        switch cleaned.uppercased() {
        case "ESTABLISHED": self = .established
        case "LISTEN": self = .listen
        case "TIME_WAIT": self = .timeWait
        case "CLOSE_WAIT": self = .closeWait
        case "SYN_SENT": self = .synSent
        case "SYN_RECV", "SYN_RECEIVED": self = .synReceived
        case "FIN_WAIT_1": self = .finWait1
        case "FIN_WAIT_2": self = .finWait2
        case "CLOSING": self = .closing
        case "LAST_ACK": self = .lastAck
        case "CLOSED": self = .closed
        default: self = .unknown
        }
    }
}
