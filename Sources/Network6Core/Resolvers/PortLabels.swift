import Foundation

/// Maps well-known port numbers to human-readable service names.
public enum PortLabels {
    private static let labels: [Int: String] = [
        20: "FTP-Data",
        21: "FTP",
        22: "SSH",
        23: "Telnet",
        25: "SMTP",
        53: "DNS",
        67: "DHCP",
        68: "DHCP",
        80: "HTTP",
        110: "POP3",
        119: "NNTP",
        123: "NTP",
        143: "IMAP",
        161: "SNMP",
        194: "IRC",
        389: "LDAP",
        443: "HTTPS",
        445: "SMB",
        465: "SMTPS",
        514: "Syslog",
        587: "SMTP",
        636: "LDAPS",
        853: "DNS-TLS",
        993: "IMAPS",
        995: "POP3S",
        1080: "SOCKS",
        1194: "OpenVPN",
        1433: "MSSQL",
        1521: "Oracle",
        3306: "MySQL",
        3389: "RDP",
        5060: "SIP",
        5222: "XMPP",
        5228: "Google",
        5353: "mDNS",
        5432: "PostgreSQL",
        5900: "VNC",
        5938: "TeamViewer",
        6379: "Redis",
        6443: "K8s-API",
        8080: "HTTP-Alt",
        8443: "HTTPS-Alt",
        8883: "MQTT-TLS",
        9090: "Prometheus",
        9200: "Elastic",
        9418: "Git",
        27017: "MongoDB",
    ]

    /// Returns a human-readable label for a port number, or nil if unknown.
    public static func label(for port: Int) -> String? {
        labels[port]
    }

    /// Returns "PORT/LABEL" or just "PORT" if no label is known.
    public static func display(for port: Int) -> String {
        if let label = labels[port] {
            return "\(port)/\(label)"
        }
        return "\(port)"
    }
}
