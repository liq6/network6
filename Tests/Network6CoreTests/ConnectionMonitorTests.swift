import XCTest
@testable import Network6Core

final class ConnectionMonitorTests: XCTestCase {

    func testParseLsofOutput() async {
        let monitor = ConnectionMonitor()
        let sampleOutput = """
COMMAND          PID   USER   FD   TYPE    DEVICE SIZE/OFF NODE NAME
Google           1234  user   45u  IPv4    0x1234 0t0      TCP  192.168.1.10:54321->142.250.185.14:443 (ESTABLISHED)
Safari           5678  user   23u  IPv4    0x5678 0t0      TCP  192.168.1.10:54322->17.253.144.10:443 (ESTABLISHED)
spotify          9012  user   67u  IPv4    0x9012 0t0      TCP  192.168.1.10:54323->35.186.224.25:4070 (ESTABLISHED)
launchd          1     root   12u  IPv4    0xabcd 0t0      TCP  *:22 (LISTEN)
mDNSResponder   345   _mdns  8u   IPv4    0xef01 0t0      UDP  *:5353
"""

        let connections = await monitor.parseLsofOutput(sampleOutput)

        // Should parse the TCP connections
        XCTAssertGreaterThanOrEqual(connections.count, 3, "Should parse at least 3 ESTABLISHED connections")

        // Verify first connection
        if let google = connections.first(where: { $0.processName == "Google" }) {
            XCTAssertEqual(google.pid, 1234)
            XCTAssertEqual(google.user, "user")
            XCTAssertEqual(google.remoteAddress, "142.250.185.14")
            XCTAssertEqual(google.remotePort, 443)
            XCTAssertEqual(google.localPort, 54321)
            XCTAssertEqual(google.state, .established)
            XCTAssertEqual(google.portLabel, "HTTPS")
        } else {
            XCTFail("Should find Google connection")
        }

        // Verify LISTEN connection
        if let listen = connections.first(where: { $0.state == .listen }) {
            XCTAssertEqual(listen.processName, "launchd")
            XCTAssertEqual(listen.localPort, 22)
            XCTAssertEqual(listen.portLabel, "SSH")
        }
    }

    func testConnectionProtocol() {
        XCTAssertEqual(ConnectionProtocol(from: "TCP"), .tcp)
        XCTAssertEqual(ConnectionProtocol(from: "UDP"), .udp)
        XCTAssertEqual(ConnectionProtocol(from: "TCP6"), .tcp6)
        XCTAssertEqual(ConnectionProtocol(from: "unknown"), .unknown)
        XCTAssertEqual(ConnectionProtocol.tcp.shortName, "TCP")
        XCTAssertTrue(ConnectionProtocol.tcp6.isIPv6)
        XCTAssertFalse(ConnectionProtocol.tcp.isIPv6)
    }

    func testConnectionState() {
        XCTAssertEqual(ConnectionState(from: "ESTABLISHED"), .established)
        XCTAssertEqual(ConnectionState(from: "(ESTABLISHED)"), .established)
        XCTAssertEqual(ConnectionState(from: "LISTEN"), .listen)
        XCTAssertEqual(ConnectionState(from: "TIME_WAIT"), .timeWait)
        XCTAssertEqual(ConnectionState(from: "CLOSE_WAIT"), .closeWait)
        XCTAssertEqual(ConnectionState(from: "garbage"), .unknown)
    }

    func testConnectionDuration() {
        let conn = ConnectionInfo(
            pid: 1,
            processName: "test",
            protocol: .tcp,
            state: .established,
            localAddress: "127.0.0.1",
            localPort: 1234,
            remoteAddress: "1.2.3.4",
            remotePort: 443,
            firstSeen: Date().addingTimeInterval(-90)
        )
        XCTAssertTrue(conn.duration.contains("m"), "Duration should show minutes")
    }

    func testRemoteDisplay() {
        var conn = ConnectionInfo(
            pid: 1,
            processName: "test",
            protocol: .tcp,
            state: .established,
            localAddress: "127.0.0.1",
            localPort: 1234,
            remoteAddress: "1.2.3.4",
            remotePort: 443
        )
        XCTAssertEqual(conn.remoteDisplay, "1.2.3.4")

        conn.hostname = "example.com"
        XCTAssertEqual(conn.remoteDisplay, "example.com")
    }
}
