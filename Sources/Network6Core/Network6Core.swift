/// Network6Core — Shared network analysis library.
///
/// This library provides the core functionality for monitoring network connections
/// on macOS. It is designed to be consumed by both the CLI tool and a future GUI.
///
/// Main components:
/// - `ConnectionMonitor`: Captures active network connections via `lsof`
/// - `DNSResolver`: Reverse DNS resolution with caching
/// - `GeoIPResolver`: IP geolocation via ip-api.com with caching and rate limiting
/// - `ProcessResolver`: Process path resolution from PID
/// - `PortLabels`: Human-readable labels for well-known ports

public enum Network6Core {
    public static let version = "0.1.0"
}
