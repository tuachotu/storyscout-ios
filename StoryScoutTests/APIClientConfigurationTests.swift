import XCTest
@testable import StoryScout

final class APIClientConfigurationTests: XCTestCase {
    func testNormalizesLiveBaseURLAndBuildsAccessSessionEndpoint() throws {
        let baseURL = try APIClient.normalizedBaseURL(
            from: "https://story-scout.app/api/v1/",
            rejectLoopback: true
        )

        XCTAssertEqual(baseURL.absoluteString, "https://story-scout.app/api/v1")
        XCTAssertEqual(
            baseURL.appendingPathComponent("access-sessions").absoluteString,
            "https://story-scout.app/api/v1/access-sessions"
        )
    }

    func testReleaseStyleConfigurationRejectsLoopback() {
        XCTAssertThrowsError(
            try APIClient.normalizedBaseURL(
                from: "http://127.0.0.1:3001/api/v1",
                rejectLoopback: true
            )
        )
    }

    func testExplicitLocalConfigurationAllowsLoopback() throws {
        XCTAssertEqual(
            try APIClient.normalizedBaseURL(
                from: "http://127.0.0.1:3001/api/v1",
                rejectLoopback: false
            ).absoluteString,
            "http://127.0.0.1:3001/api/v1"
        )
    }
}
