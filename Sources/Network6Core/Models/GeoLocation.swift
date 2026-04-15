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

/// Decodable model matching ipwho.is JSON response
struct IpwhoisResponse: Decodable {
    let ip: String?
    let success: Bool
    let country: String?
    let country_code: String?
    let region: String?
    let city: String?
    let latitude: Double?
    let longitude: Double?
    let connection: IpwhoisConnection?

    struct IpwhoisConnection: Decodable {
        let asn: Int?
        let org: String?
        let isp: String?
    }

    func toGeoLocation() -> GeoLocation? {
        guard success, let ip = ip else { return nil }
        return GeoLocation(
            ip: ip,
            country: country ?? "",
            countryCode: country_code ?? "",
            region: region ?? "",
            city: city ?? "",
            lat: latitude ?? 0,
            lon: longitude ?? 0,
            isp: connection?.isp ?? "",
            org: connection?.org ?? "",
            asNumber: connection?.asn.map { "AS\($0)" } ?? ""
        )
    }
}
