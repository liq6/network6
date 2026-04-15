import Foundation
import Network6Core

/// Renders connection data to the terminal using ANSI escape codes.
struct ConsoleRenderer {
    // ANSI colors
    private enum Color: String {
        case reset = "\u{1B}[0m"
        case bold = "\u{1B}[1m"
        case dim = "\u{1B}[2m"
        case green = "\u{1B}[32m"
        case yellow = "\u{1B}[33m"
        case blue = "\u{1B}[34m"
        case magenta = "\u{1B}[35m"
        case cyan = "\u{1B}[36m"
        case red = "\u{1B}[31m"
        case white = "\u{1B}[37m"
        case bgBlue = "\u{1B}[44m"
        case bgDefault = "\u{1B}[49m"
    }

    private let terminalWidth: Int

    init() {
        var ws = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0 && ws.ws_col > 0 {
            terminalWidth = Int(ws.ws_col)
        } else {
            terminalWidth = 120
        }
    }

    /// Clears the screen and renders the connection table.
    func render(connections: [ConnectionInfo], isRoot: Bool) {
        // Move cursor to top-left
        print("\u{1B}[H\u{1B}[2J", terminator: "")

        renderHeader(connectionCount: connections.count, isRoot: isRoot)
        renderTable(connections)
    }

    private func renderHeader(connectionCount: Int, isRoot: Bool) {
        let title = "\(Color.bold.rawValue)\(Color.cyan.rawValue)⚡ Network6\(Color.reset.rawValue)"
        let count = "\(Color.white.rawValue)\(connectionCount) connections\(Color.reset.rawValue)"
        let mode = isRoot
            ? "\(Color.green.rawValue)● root\(Color.reset.rawValue)"
            : "\(Color.yellow.rawValue)● user mode (sudo for full visibility)\(Color.reset.rawValue)"
        let quit = "\(Color.dim.rawValue)Press Ctrl+C to quit\(Color.reset.rawValue)"

        print("\(title)  │  \(count)  │  \(mode)  │  \(quit)")
        print(String(repeating: "─", count: min(terminalWidth, 160)))
    }

    private func renderTable(_ connections: [ConnectionInfo]) {
        // Column definitions with fixed widths
        let cols: [(String, Int)] = [
            ("APPLICATION", 22),
            ("PID", 7),
            ("PROTO", 5),
            ("STATE", 12),
            ("LOCAL", 22),
            ("REMOTE", 30),
            ("PORT", 10),
            ("LOCATION", 24),
            ("ORG", 18),
            ("TIME", 7),
        ]

        // Header row
        var header = ""
        for (name, width) in cols {
            header += pad(name, width)
        }
        print("\(Color.bold.rawValue)\(Color.blue.rawValue)\(header)\(Color.reset.rawValue)")
        print(String(repeating: "─", count: min(terminalWidth, 160)))

        // Data rows
        let maxRows = getTerminalHeight() - 5 // Reserve lines for header/footer
        for (index, conn) in connections.prefix(maxRows).enumerated() {
            let stateColor = colorForState(conn.state)
            let rowColor = index % 2 == 0 ? "" : Color.dim.rawValue

            var row = ""
            row += "\(rowColor)"
            row += pad(conn.processName, cols[0].1)
            row += pad("\(conn.pid)", cols[1].1)
            row += pad(conn.protocol.shortName, cols[2].1)
            row += "\(stateColor)\(pad(conn.state.rawValue, cols[3].1))\(Color.reset.rawValue)\(rowColor)"
            row += pad("\(conn.localAddress):\(conn.localPort)", cols[4].1)
            row += pad(conn.remoteDisplay, cols[5].1)
            row += pad(conn.portLabel.map { "\(conn.remotePort)/\($0)" } ?? "\(conn.remotePort)", cols[6].1)
            row += pad(conn.locationDisplay, cols[7].1)
            row += pad(conn.geoLocation?.org ?? "—", cols[8].1)
            row += pad(conn.duration, cols[9].1)
            row += Color.reset.rawValue

            print(row)
        }

        if connections.count > maxRows {
            print("\(Color.dim.rawValue)... and \(connections.count - maxRows) more connections\(Color.reset.rawValue)")
        }
    }

    private func pad(_ str: String, _ width: Int) -> String {
        if str.count >= width {
            return String(str.prefix(width - 1)) + " "
        }
        return str + String(repeating: " ", count: width - str.count)
    }

    private func colorForState(_ state: ConnectionState) -> String {
        switch state {
        case .established: return Color.green.rawValue
        case .listen: return Color.cyan.rawValue
        case .timeWait, .closeWait: return Color.yellow.rawValue
        case .synSent, .synReceived: return Color.magenta.rawValue
        case .closed, .closing, .lastAck, .finWait1, .finWait2: return Color.red.rawValue
        case .unknown: return Color.dim.rawValue
        }
    }

    private func getTerminalHeight() -> Int {
        var ws = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0 && ws.ws_row > 0 {
            return Int(ws.ws_row)
        }
        return 40
    }
}
