import Foundation

/// Resolves IP addresses to hostnames via reverse DNS lookup with caching.
public actor DNSResolver {
    private var cache: [String: String] = [:]
    private var pending: Set<String> = []

    public init() {}

    /// Resolves a hostname for the given IP address.
    /// Returns cached result if available, otherwise performs async lookup.
    public func resolve(_ ip: String) async -> String? {
        if let cached = cache[ip] {
            return cached.isEmpty ? nil : cached
        }

        // Skip private/local addresses
        guard !isPrivateAddress(ip) else {
            cache[ip] = ""
            return nil
        }

        // Avoid duplicate lookups
        guard !pending.contains(ip) else { return nil }
        pending.insert(ip)

        let hostname = await performReverseDNS(ip)
        cache[ip] = hostname ?? ""
        pending.remove(ip)

        return hostname
    }

    /// Bulk resolve multiple IPs, returning a dictionary of IP → hostname.
    public func resolveAll(_ ips: [String]) async -> [String: String] {
        var results: [String: String] = [:]
        await withTaskGroup(of: (String, String?).self) { group in
            let uniqueIPs = Set(ips)
            for ip in uniqueIPs {
                group.addTask {
                    let hostname = await self.resolve(ip)
                    return (ip, hostname)
                }
            }
            for await (ip, hostname) in group {
                if let hostname = hostname {
                    results[ip] = hostname
                }
            }
        }
        return results
    }

    private func performReverseDNS(_ ip: String) async -> String? {
        return await withCheckedContinuation { continuation in
            var hints = addrinfo()
            hints.ai_flags = AI_NUMERICHOST

            var infoPointer: UnsafeMutablePointer<addrinfo>?
            let getResult = getaddrinfo(ip, nil, &hints, &infoPointer)
            guard getResult == 0, let info = infoPointer else {
                continuation.resume(returning: nil)
                return
            }
            defer { freeaddrinfo(infoPointer) }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let nameResult = getnameinfo(
                info.pointee.ai_addr,
                info.pointee.ai_addrlen,
                &hostname,
                socklen_t(NI_MAXHOST),
                nil, 0, 0
            )

            if nameResult == 0 {
                let name = String(cString: hostname)
                // If getnameinfo returns the IP itself, treat as no hostname
                if name != ip {
                    continuation.resume(returning: name)
                    return
                }
            }
            continuation.resume(returning: nil)
        }
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
