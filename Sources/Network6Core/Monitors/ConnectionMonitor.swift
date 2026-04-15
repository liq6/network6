import Foundation

/// Captures active network connections by parsing `lsof` output.
public actor ConnectionMonitor {
    private var knownConnections: [String: ConnectionInfo] = [:]

    public init() {}

    /// Fetches current network connections from the system.
    public func refresh() async throws -> [ConnectionInfo] {
        let raw = try await runLsof()
        let parsed = parseLsofOutput(raw)

        // Track first-seen times
        var results: [ConnectionInfo] = []
        for var conn in parsed {
            if let existing = knownConnections[conn.id] {
                conn = ConnectionInfo(
                    pid: conn.pid,
                    processName: conn.processName,
                    processPath: conn.processPath,
                    user: conn.user,
                    protocol: conn.protocol,
                    state: conn.state,
                    localAddress: conn.localAddress,
                    localPort: conn.localPort,
                    remoteAddress: conn.remoteAddress,
                    remotePort: conn.remotePort,
                    portLabel: conn.portLabel,
                    hostname: conn.hostname,
                    geoLocation: conn.geoLocation,
                    firstSeen: existing.firstSeen
                )
            }
            knownConnections[conn.id] = conn
            results.append(conn)
        }

        // Prune stale connections
        let currentIds = Set(results.map(\.id))
        for key in knownConnections.keys where !currentIds.contains(key) {
            knownConnections.removeValue(forKey: key)
        }

        return results
    }

    private func runLsof() async throws -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-i", "-n", "-P", "+c", "0"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        try process.run()

        return await withCheckedContinuation { continuation in
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                    let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    // Re-read all data
                    continuation.resume(returning: output)
                }
            }
            // Simpler approach: just wait
            pipe.fileHandleForReading.readabilityHandler = nil
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let output = String(data: data, encoding: .utf8) ?? ""
            continuation.resume(returning: output)
        }
    }

    /// Parses lsof output into ConnectionInfo objects.
    /// Format: COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
    public func parseLsofOutput(_ output: String) -> [ConnectionInfo] {
        var connections: [ConnectionInfo] = []
        let lines = output.components(separatedBy: "\n")

        for line in lines.dropFirst() { // Skip header
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Split on whitespace, merging consecutive spaces
            let allParts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

            guard allParts.count >= 9 else { continue }

            // Fields: COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME...
            // COMMAND may contain \x20 (escaped spaces) — it's always one token from lsof +c 0
            // NAME is the last field and may contain spaces, so rejoin from index 8
            let command = allParts[0].replacingOccurrences(of: "\\x20", with: " ")
            guard let pid = Int(allParts[1]) else { continue }
            let user = allParts[2]
            // allParts[3] = FD
            let type = allParts[4]
            // allParts[5] = DEVICE
            // allParts[6] = SIZE/OFF
            let node = allParts[7]
            let name = allParts[8...].joined(separator: " ")

            // Only interested in network connections (IPv4/IPv6)
            guard type == "IPv4" || type == "IPv6" else { continue }

            let proto = ConnectionProtocol(from: node + (type == "IPv6" ? "6" : ""))

            // Parse NAME: "local:port->remote:port (STATE)" or "local:port" (LISTEN) or "*:port"
            let (localAddr, localPort, remoteAddr, remotePort, state) = parseNameField(name)

            // Keep: connections with remote address, LISTEN ports, and UDP bound sockets
            let isUDP = proto == .udp || proto == .udp6
            guard !remoteAddr.isEmpty || state == .listen || isUDP else { continue }

            let portLabel = PortLabels.label(for: remotePort != 0 ? remotePort : localPort)

            let conn = ConnectionInfo(
                pid: pid,
                processName: command,
                user: user,
                protocol: proto,
                state: state,
                localAddress: localAddr,
                localPort: localPort,
                remoteAddress: remoteAddr,
                remotePort: remotePort,
                portLabel: portLabel
            )
            connections.append(conn)
        }

        return connections
    }

    /// Parses the NAME field from lsof: "local:port->remote:port (STATE)"
    private func parseNameField(_ name: String) -> (String, Int, String, Int, ConnectionState) {
        var statePart = ConnectionState.unknown
        var namePart = name

        // Extract state in parentheses at the end
        if let parenRange = name.range(of: "\\(([^)]+)\\)$", options: .regularExpression) {
            let stateStr = String(name[parenRange])
                .replacingOccurrences(of: "(", with: "")
                .replacingOccurrences(of: ")", with: "")
            statePart = ConnectionState(from: stateStr)
            namePart = String(name[name.startIndex..<parenRange.lowerBound])
                .trimmingCharacters(in: .whitespaces)
        }

        // Split on "->"
        let arrowParts = namePart.components(separatedBy: "->")

        let (localAddr, localPort) = parseAddressPort(arrowParts[0])
        var remoteAddr = ""
        var remotePort = 0

        if arrowParts.count > 1 {
            (remoteAddr, remotePort) = parseAddressPort(arrowParts[1])
        }

        if statePart == .unknown && remoteAddr.isEmpty {
            statePart = .listen
        }

        return (localAddr, localPort, remoteAddr, remotePort, statePart)
    }

    /// Parses "address:port" handling IPv6 bracket notation
    private func parseAddressPort(_ str: String) -> (String, Int) {
        let trimmed = str.trimmingCharacters(in: .whitespaces)

        // Handle IPv6 [addr]:port
        if trimmed.hasPrefix("[") {
            if let closeBracket = trimmed.lastIndex(of: "]") {
                let addr = String(trimmed[trimmed.index(after: trimmed.startIndex)..<closeBracket])
                let afterBracket = trimmed[trimmed.index(after: closeBracket)...]
                if afterBracket.hasPrefix(":"), let port = Int(afterBracket.dropFirst()) {
                    return (addr, port)
                }
                return (addr, 0)
            }
        }

        // Handle addr:port — find the last colon
        if let lastColon = trimmed.lastIndex(of: ":") {
            let addr = String(trimmed[trimmed.startIndex..<lastColon])
            let portStr = String(trimmed[trimmed.index(after: lastColon)...])
            if let port = Int(portStr) {
                return (addr == "*" ? "0.0.0.0" : addr, port)
            }
        }

        return (trimmed, 0)
    }
}
