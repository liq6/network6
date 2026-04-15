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

    func testGeoIPResponseDecoding() throws {
        let json = """
        {
            "status": "success",
            "country": "United States",
            "countryCode": "US",
            "regionName": "California",
            "city": "Mountain View",
            "lat": 37.4056,
            "lon": -122.0775,
            "isp": "Google LLC",
            "org": "Google Public DNS",
            "as": "AS15169 Google LLC",
            "query": "8.8.8.8"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(GeoIPResponse.self, from: json)
        XCTAssertEqual(response.status, "success")
        XCTAssertEqual(response.country, "United States")

        let geo = response.toGeoLocation()
        XCTAssertNotNil(geo)
        XCTAssertEqual(geo?.ip, "8.8.8.8")
        XCTAssertEqual(geo?.city, "Mountain View")
        XCTAssertEqual(geo?.org, "Google Public DNS")
    }

    func testGeoIPResponseFailure() throws {
        let json = """
        {"status": "fail", "country": null, "countryCode": null, "regionName": null, "city": null, "lat": 0, "lon": 0, "isp": null, "org": null, "as": null, "query": "10.0.0.1"}
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(GeoIPResponse.self, from: json)
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
