import Foundation

/// Resolves geographic location for IP addresses using ip-api.com with caching and rate limiting.
public actor GeoIPResolver {
    private var cache: [String: GeoLocation] = [:]
    private var failedIPs: Set<String> = []
    private var myLocation: GeoLocation?
    private var requestCount = 0
    private var windowStart = Date()
    private let maxRequestsPerMinute = 40 // Stay under 45/min limit

    public init() {}

    /// Resolves the user's own location by querying ip-api.com with no IP (returns caller's IP).
    public func resolveMyLocation() async -> GeoLocation? {
        if let cached = myLocation { return cached }
        guard canMakeRequest() else { return nil }
        do {
            requestCount += 1
            let url = URL(string: "http://ip-api.com/json/?fields=status,country,countryCode,regionName,city,lat,lon,isp,org,as,query")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(GeoIPResponse.self, from: data)
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

        guard canMakeRequest() else { return nil }

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

    /// Batch resolve multiple IPs. Respects rate limiting.
    public func resolveAll(_ ips: [String]) async -> [String: GeoLocation] {
        var results: [String: GeoLocation] = [:]

        // Filter to unique, non-cached, non-private IPs
        let toResolve = Set(ips).filter { ip in
            cache[ip] == nil && !failedIPs.contains(ip) && !isPrivateAddress(ip)
        }

        // Use batch API for efficiency
        if !toResolve.isEmpty {
            let batchResults = await fetchBatchGeoIP(Array(toResolve.prefix(maxAvailableRequests())))
            for (ip, geo) in batchResults {
                cache[ip] = geo
            }
        }

        // Return all cached results for requested IPs
        for ip in ips {
            if let geo = cache[ip] {
                results[ip] = geo
            }
        }
        return results
    }

    private func canMakeRequest() -> Bool {
        let now = Date()
        if now.timeIntervalSince(windowStart) > 60 {
            requestCount = 0
            windowStart = now
        }
        return requestCount < maxRequestsPerMinute
    }

    private func maxAvailableRequests() -> Int {
        let now = Date()
        if now.timeIntervalSince(windowStart) > 60 {
            return maxRequestsPerMinute
        }
        return max(0, maxRequestsPerMinute - requestCount)
    }

    private func fetchGeoIP(_ ip: String) async throws -> GeoLocation? {
        requestCount += 1
        let url = URL(string: "http://ip-api.com/json/\(ip)?fields=status,country,countryCode,regionName,city,lat,lon,isp,org,as,query")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(GeoIPResponse.self, from: data)
        return response.toGeoLocation()
    }

    private func fetchBatchGeoIP(_ ips: [String]) async -> [String: GeoLocation] {
        var results: [String: GeoLocation] = [:]

        // ip-api.com batch endpoint accepts up to 100 IPs
        let batchSize = min(ips.count, 100)
        let batch = Array(ips.prefix(batchSize))

        do {
            requestCount += 1
            let url = URL(string: "http://ip-api.com/batch?fields=status,country,countryCode,regionName,city,lat,lon,isp,org,as,query")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body = batch.map { ["query": $0] }
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, _) = try await URLSession.shared.data(for: request)
            let responses = try JSONDecoder().decode([GeoIPResponse].self, from: data)

            for response in responses {
                if let geo = response.toGeoLocation() {
                    results[geo.ip] = geo
                }
            }
        } catch {
            // Fall back to individual requests
            for ip in batch {
                if let geo = try? await fetchGeoIP(ip) {
                    results[ip] = geo
                }
            }
        }

        return results
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
