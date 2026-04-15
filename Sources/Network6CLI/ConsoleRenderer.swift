import Foundation
import Network6Core

/// Renders connection data to the terminal using ANSI escape codes.
/// Uses alternate screen buffer and single-write flicker-free refresh like `top`.
struct ConsoleRenderer {

    private enum ANSICode {
        static let reset       = "\u{1B}[0m"
        static let bold        = "\u{1B}[1m"
        static let dim         = "\u{1B}[2m"
        static let green       = "\u{1B}[32m"
        static let yellow      = "\u{1B}[33m"
        static let blue        = "\u{1B}[34m"
        static let magenta     = "\u{1B}[35m"
        static let cyan        = "\u{1B}[36m"
        static let red         = "\u{1B}[31m"
        static let white       = "\u{1B}[37m"
        // Cursor & screen
        static let home        = "\u{1B}[H"          // Move cursor to 1,1
        static let clearToEnd  = "\u{1B}[J"           // Clear from cursor to end of screen
        static let clearLine   = "\u{1B}[2K"          // Clear entire current line
        static let hideCursor  = "\u{1B}[?25l"
        static let showCursor  = "\u{1B}[?25h"
        static let altScreen   = "\u{1B}[?1049h"      // Enter alternate screen buffer
        static let mainScreen  = "\u{1B}[?1049l"      // Leave alternate screen buffer
    }

    private var previousLineCount = 0

    init() {}

    /// Enter alternate screen buffer and hide cursor (call once at startup).
    func setup() {
        write(ANSICode.altScreen + ANSICode.hideCursor)
    }

    /// Leave alternate screen buffer and restore cursor (call on exit).
    static func teardown() {
        let buf = ANSICode.showCursor + ANSICode.mainScreen + ANSICode.reset
        buf.withCString { ptr in
            _ = Foundation.write(STDOUT_FILENO, ptr, strlen(ptr))
        }
    }

    /// Renders the full frame flicker-free: builds the entire output in memory,
    /// then writes it in a single syscall — just like `top`.
    mutating func render(connections: [ConnectionInfo], isRoot: Bool) {
        let (termWidth, termHeight) = getTerminalSize()
        var buf = ""

        // Move cursor home (no clear — we overwrite in place)
        buf += ANSICode.home

        // ── Header ──
        let title = "\(ANSICode.bold)\(ANSICode.cyan)⚡ Network6\(ANSICode.reset)"
        let count = "\(ANSICode.white)\(connections.count) connections\(ANSICode.reset)"
        let mode = isRoot
            ? "\(ANSICode.green)● root\(ANSICode.reset)"
            : "\(ANSICode.yellow)● user (sudo for full visibility)\(ANSICode.reset)"
        let quit = "\(ANSICode.dim)Ctrl+C to quit\(ANSICode.reset)"
        buf += "\(ANSICode.clearLine)\(title)  │  \(count)  │  \(mode)  │  \(quit)\n"

        let separator = String(repeating: "─", count: min(termWidth, 160))
        buf += "\(ANSICode.clearLine)\(separator)\n"

        // ── Column definitions ──
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

        // Column header
        var header = ""
        for (name, width) in cols {
            header += pad(name, width)
        }
        buf += "\(ANSICode.clearLine)\(ANSICode.bold)\(ANSICode.blue)\(header)\(ANSICode.reset)\n"
        buf += "\(ANSICode.clearLine)\(separator)\n"

        // ── Data rows ──
        let reservedLines = 6 // header(1) + sep(1) + colheader(1) + sep(1) + footer(1) + margin(1)
        let maxRows = max(1, termHeight - reservedLines)
        var lineCount = 4 // lines written so far (header + 2 seps + col header)

        for (index, conn) in connections.prefix(maxRows).enumerated() {
            let stateColor = colorForState(conn.state)
            let rowColor = index % 2 == 0 ? "" : ANSICode.dim

            var row = ANSICode.clearLine + rowColor
            row += pad(conn.processName, cols[0].1)
            row += pad("\(conn.pid)", cols[1].1)
            row += pad(conn.protocol.shortName, cols[2].1)
            row += "\(stateColor)\(pad(conn.state.rawValue, cols[3].1))\(ANSICode.reset)\(rowColor)"
            row += pad("\(conn.localAddress):\(conn.localPort)", cols[4].1)
            row += pad(conn.remoteDisplay, cols[5].1)
            row += pad(conn.portLabel.map { "\(conn.remotePort)/\($0)" } ?? "\(conn.remotePort)", cols[6].1)
            row += pad(conn.locationDisplay, cols[7].1)
            row += pad(conn.geoLocation?.org ?? "—", cols[8].1)
            row += pad(conn.duration, cols[9].1)
            row += ANSICode.reset

            buf += row + "\n"
            lineCount += 1
        }

        // Footer
        if connections.count > maxRows {
            buf += "\(ANSICode.clearLine)\(ANSICode.dim)… \(connections.count - maxRows) more connections (resize terminal to see more)\(ANSICode.reset)\n"
            lineCount += 1
        }

        // Clear any leftover lines from the previous frame
        if lineCount < previousLineCount {
            for _ in lineCount..<previousLineCount {
                buf += ANSICode.clearLine + "\n"
            }
        }

        // Wipe everything below our content (handles terminal shrink)
        buf += ANSICode.clearToEnd

        previousLineCount = lineCount

        // Single atomic write — no flicker
        write(buf)
    }

    /// Writes a string to stdout in a single write() syscall.
    private func write(_ str: String) {
        let data = Array(str.utf8)
        data.withUnsafeBufferPointer { ptr in
            if let base = ptr.baseAddress {
                _ = Foundation.write(STDOUT_FILENO, base, ptr.count)
            }
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
        case .established: return ANSICode.green
        case .listen: return ANSICode.cyan
        case .timeWait, .closeWait: return ANSICode.yellow
        case .synSent, .synReceived: return ANSICode.magenta
        case .closed, .closing, .lastAck, .finWait1, .finWait2: return ANSICode.red
        case .unknown: return ANSICode.dim
        }
    }

    private func getTerminalSize() -> (width: Int, height: Int) {
        var ws = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0 && ws.ws_col > 0 {
            return (Int(ws.ws_col), Int(ws.ws_row))
        }
        return (120, 40)
    }
}
