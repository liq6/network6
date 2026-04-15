import Foundation

/// Resolves geographic location for IP addresses using ipwho.is (HTTPS, fast, free).
public actor GeoIPResolver {
    private var cache: [String: GeoLocation] = [:]
    private var failedIPs: Set<String> = []
    private var myLocation: GeoLocation?

    public init() {}

    /// Resolves the user's own location by querying ipwho.is with no IP.
    public func resolveMyLocation() async -> GeoLocation? {
        if let cached = myLocation { return cached }
        do {
            let url = URL(string: "https://ipwho.is/")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(IpwhoisResponse.self, from: data)
            myLocation = response.toGeoLocation()
            return myLocation
        } catch {
            return nil
        }
    }

    /// Returns the previously resolved user location (non-async, for display).
    public func getMyLocation() -> GeoLocation? {
        return myLocation
    }

    /// Resolves geo location for a single IP address.
    public func resolve(_ ip: String) async -> GeoLocation? {
        if let cached = cache[ip] { return cached }
        if failedIPs.contains(ip) { return nil }
        if isPrivateAddress(ip) { return nil }

        do {
            let geo = try await fetchGeoIP(ip)
            if let geo = geo {
                cache[ip] = geo
            } else {
                failedIPs.insert(ip)
            }
            return geo
        } catch {
            return nil
        }
    }

    /// Batch resolve multiple IPs using concurrent requests.
    public func resolveAll(_ ips: [String]) async -> [String: GeoLocation] {
        var results: [String: GeoLocation] = [:]

        let toResolve = Set(ips).filter { ip in
            cache[ip] == nil && !failedIPs.contains(ip) && !isPrivateAddress(ip)
        }

        // Concurrent requests (ipwho.is has no strict rate limit)
        if !toResolve.isEmpty {
            await withTaskGroup(of: (String, GeoLocation?).self) { group in
                for ip in toResolve.prefix(50) {
                    group.addTask { [self] in
                        let geo = try? await self.fetchGeoIP(ip)
                        return (ip, geo)
                    }
                }
                for await (ip, geo) in group {
                    if let geo = geo {
                        cache[ip] = geo
                    } else {
                        failedIPs.insert(ip)
                    }
                }
            }
        }

        for ip in ips {
            if let geo = cache[ip] {
                results[ip] = geo
            }
        }
        return results
    }

    private func fetchGeoIP(_ ip: String) async throws -> GeoLocation? {
        let url = URL(string: "https://ipwho.is/\(ip)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(IpwhoisResponse.self, from: data)
        return response.toGeoLocation()
    }

    private func isPrivateAddress(_ ip: String) -> Bool {
        if ip.hasPrefix("127.") || ip.hasPrefix("10.") || ip == "0.0.0.0" || ip == "*" || ip == "::" || ip == "::1" {
            return true
        }
        if ip.hasPrefix("192.168.") { return true }
        if ip.hasPrefix("172.") {
            let parts = ip.split(separator: ".")
            if parts.count >= 2, let second = Int(parts[1]), second >= 16 && second <= 31 {
                return true
            }
        }
        if ip.hasPrefix("fe80:") || ip.hasPrefix("fd") { return true }
        return false
    }
}
