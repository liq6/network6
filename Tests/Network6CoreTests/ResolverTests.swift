import XCTest
@testable import Network6Core

final class ResolverTests: XCTestCase {

    func testPortLabels() {
        XCTAssertEqual(PortLabels.label(for: 443), "HTTPS")
        XCTAssertEqual(PortLabels.label(for: 80), "HTTP")
        XCTAssertEqual(PortLabels.label(for: 22), "SSH")
        XCTAssertEqual(PortLabels.label(for: 53), "DNS")
        XCTAssertEqual(PortLabels.label(for: 3306), "MySQL")
        XCTAssertEqual(PortLabels.label(for: 5432), "PostgreSQL")
        XCTAssertNil(PortLabels.label(for: 99999))

        XCTAssertEqual(PortLabels.display(for: 443), "443/HTTPS")
        XCTAssertEqual(PortLabels.display(for: 12345), "12345")
    }

    func testGeoLocationSummary() {
        let geo = GeoLocation(
            ip: "8.8.8.8",
            country: "United States",
            city: "Mountain View",
            org: "Google LLC"
        )
        XCTAssertEqual(geo.summary, "Mountain View, United States, (Google LLC)")

        let emptyGeo = GeoLocation(ip: "1.2.3.4")
        XCTAssertEqual(emptyGeo.summary, "1.2.3.4")
    }

    func testGeoLocationDistance() {
        // Paris → New York ≈ 5,837 km
        let paris = GeoLocation(ip: "1.1.1.1", lat: 48.8566, lon: 2.3522)
        let newYork = GeoLocation(ip: "2.2.2.2", lat: 40.7128, lon: -74.0060)
        let distance = paris.distance(to: newYork)
        XCTAssertGreaterThan(distance, 5700)
        XCTAssertLessThan(distance, 6000)

        // Same location → 0 km
        XCTAssertEqual(paris.distance(to: paris), 0, accuracy: 0.01)

        // Display string
        XCTAssertTrue(paris.distanceDisplay(to: newYork).contains("km"))
    }

    func testGeoIPResponseDecoding() throws {
        let json = """
        {
            "ip": "8.8.8.8",
            "success": true,
            "country": "United States",
            "country_code": "US",
            "region": "California",
            "city": "Mountain View",
            "latitude": 37.4056,
            "longitude": -122.0775,
            "connection": {
                "asn": 15169,
                "org": "Google Public DNS",
                "isp": "Google LLC"
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(IpwhoisResponse.self, from: json)
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.country, "United States")

        let geo = response.toGeoLocation()
        XCTAssertNotNil(geo)
        XCTAssertEqual(geo?.ip, "8.8.8.8")
        XCTAssertEqual(geo?.city, "Mountain View")
        XCTAssertEqual(geo?.org, "Google Public DNS")
    }

    func testGeoIPResponseFailure() throws {
        let json = """
        {"ip": "10.0.0.1", "success": false}
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(IpwhoisResponse.self, from: json)
        XCTAssertNil(response.toGeoLocation())
    }

    func testDNSResolverCaching() async {
        let resolver = DNSResolver()
        // Private IPs should return nil immediately (cached as empty)
        let result1 = await resolver.resolve("192.168.1.1")
        XCTAssertNil(result1, "Private IP should not resolve")

        let result2 = await resolver.resolve("127.0.0.1")
        XCTAssertNil(result2, "Loopback should not resolve")

        let result3 = await resolver.resolve("10.0.0.1")
        XCTAssertNil(result3, "Private IP should not resolve")
    }

    func testConnectionInfoId() {
        let conn = ConnectionInfo(
            pid: 123,
            processName: "test",
            protocol: .tcp,
            state: .established,
            localAddress: "192.168.1.1",
            localPort: 5000,
            remoteAddress: "8.8.8.8",
            remotePort: 443
        )
        XCTAssertEqual(conn.id, "123:192.168.1.1:5000-8.8.8.8:443")
    }
}
