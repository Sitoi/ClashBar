import XCTest
@testable import ClashBar

final class ConnectionCompatibilityTests: XCTestCase {
    func testStashConnectionUsesNumericIDAndTrafficTotals() throws {
        let data = Data(#"""
        {
          "id": 4921,
          "metadata": {"network": "TLS", "host": "example.com", "destinationIP": ""},
          "upload": {"current": 12, "max": 30, "total": 1959, "last": "2026-10-22T10:52:33Z"},
          "download": {"current": 34, "max": 50, "total": 5081},
          "start": "2026-10-22T10:52:33.661723Z",
          "chains": ["Proxy", "DIRECT"],
          "rule": "RULE-SET",
          "rulePayload": "example-rules",
          "state": 0
        }
        """#.utf8)

        let connection = try JSONDecoder().decode(ConnectionSummary.self, from: data)

        XCTAssertEqual(connection.id, "4921")
        XCTAssertEqual(connection.upload, 1959)
        XCTAssertEqual(connection.download, 5081)
        XCTAssertNotNil(connection.startTimestamp)
        XCTAssertEqual(connection.metadata?.network, "TLS")
        XCTAssertEqual(connection.metadata?.host, "example.com")
        XCTAssertEqual(connection.chains, ["Proxy", "DIRECT"])
        XCTAssertEqual(connection.rule, "RULE-SET")
        XCTAssertEqual(connection.rulePayload, "example-rules")
    }

    func testMihomoConnectionKeepsStringIDAndIntegerTraffic() throws {
        let data = Data(#"{"id":"uuid-connection","upload":1959,"download":5081}"#.utf8)
        let connection = try JSONDecoder().decode(ConnectionSummary.self, from: data)

        XCTAssertEqual(connection.id, "uuid-connection")
        XCTAssertEqual(connection.upload, 1959)
        XCTAssertEqual(connection.download, 5081)
        XCTAssertEqual(try JSONDecoder().decode(
            ConnectionSummary.self,
            from: JSONEncoder().encode(connection)), connection)
    }

    func testMissingAndNullTrafficRemainOptional() throws {
        for json in [#"{"id":1}"#, #"{"id":1,"upload":null,"download":null}"#] {
            let connection = try JSONDecoder().decode(ConnectionSummary.self, from: Data(json.utf8))
            XCTAssertNil(connection.upload)
            XCTAssertNil(connection.download)
        }
    }

    func testLargeNumericIDAndTrafficKeepIntegerPrecision() throws {
        let data = Data(#"{"id":9007199254740993,"upload":{"total":9223372036854775807},"download":0}"#.utf8)
        let connection = try JSONDecoder().decode(ConnectionSummary.self, from: data)

        XCTAssertEqual(connection.id, "9007199254740993")
        XCTAssertEqual(connection.upload, Int64.max)
        XCTAssertEqual(connection.download, 0)
    }

    func testMalformedIDsAndTrafficAreRejected() {
        for json in [
            #"{"upload":0}"#,
            #"{"id":true}"#,
            #"{"id":1.5}"#,
            #"{"id":"valid","upload":"invalid"}"#,
            #"{"id":"valid","upload":{"total":"invalid"}}"#,
        ] {
            XCTAssertThrowsError(try JSONDecoder().decode(ConnectionSummary.self, from: Data(json.utf8)))
        }
    }

    func testMixedSnapshotCountsAllConnectionsAndLimitsRetainedRows() throws {
        let rows = (0..<125).map { index in
            index.isMultiple(of: 2)
                ? #"{"id":\#(index),"upload":{"total":10},"download":{"total":20}}"#
                : #"{"id":"\#(index)","upload":10,"download":20}"#
        }
        let data = Data("{\"connections\":[\(rows.joined(separator: ","))]}".utf8)
        let snapshot = try JSONDecoder().decode(ConnectionsSnapshot.self, from: data)

        XCTAssertEqual(snapshot.totalCount, 125)
        XCTAssertEqual(snapshot.connections.count, ConnectionsSnapshot.retainedConnectionLimit)
        XCTAssertEqual(snapshot.connections.first?.id, "0")
        XCTAssertEqual(snapshot.connections.last?.id, "119")
        XCTAssertTrue(snapshot.connections.allSatisfy { $0.upload == 10 && $0.download == 20 })
    }
}
