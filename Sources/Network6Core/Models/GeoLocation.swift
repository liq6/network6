import Foundation

/// Geographic location information for an IP address.
public struct GeoLocation: Sendable {
    public let ip: String
    public let country: String
    public let countryCode: String
    public let region: String
    public let city: String
    public let lat: Double
    public let lon: Double
    public let isp: String
    public let org: String
    public let asNumber: String

    public init(
        ip: String,
        country: String = "",
        countryCode: String = "",
        region: String = "",
        city: String = "",
        lat: Double = 0,
        lon: Double = 0,
        isp: String = "",
        org: String = "",
        asNumber: String = ""
    ) {
        self.ip = ip
        self.country = country
        self.countryCode = countryCode
        self.region = region
        self.city = city
        self.lat = lat
        self.lon = lon
        self.isp = isp
        self.org = org
        self.asNumber = asNumber
    }

    public var summary: String {
        var parts: [String] = []
        if !city.isEmpty { parts.append(city) }
        if !country.isEmpty { parts.append(country) }
        if !org.isEmpty { parts.append("(\(org))") }
        return parts.isEmpty ? ip : parts.joined(separator: ", ")
    }

    /// Calculates the distance in kilometers to another GeoLocation using the Haversine formula.
    public func distance(to other: GeoLocation) -> Double {
        let R = 6371.0 // Earth radius in km
        let dLat = (other.lat - lat) * .pi / 180
        let dLon = (other.lon - lon) * .pi / 180
        let lat1 = lat * .pi / 180
        let lat2 = other.lat * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }

    /// Human-readable distance string.
    public func distanceDisplay(to other: GeoLocation) -> String {
        let km = distance(to: other)
        if km < 1 { return "<1 km" }
        if km < 1000 { return "\(Int(km)) km" }
        return String(format: "%.1fk km", km / 1000)
    }
}

/// Decodable model matching ip-api.com JSON response
struct GeoIPResponse: Decodable {
    let status: String
    let country: String?
    let countryCode: String?
    let regionName: String?
    let city: String?
    let lat: Double?
    let lon: Double?
    let isp: String?
    let org: String?
    let `as`: String?
    let query: String?

    func toGeoLocation() -> GeoLocation? {
        guard status == "success", let ip = query else { return nil }
        return GeoLocation(
            ip: ip,
            country: country ?? "",
            countryCode: countryCode ?? "",
            region: regionName ?? "",
            city: city ?? "",
            lat: lat ?? 0,
            lon: lon ?? 0,
            isp: isp ?? "",
            org: org ?? "",
            asNumber: `as` ?? ""
        )
    }
}
