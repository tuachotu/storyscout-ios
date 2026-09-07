import XCTest
@testable import StoryScout

final class SessionCountdownTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    func testHidesBeforeFinalThirtyMinutes() {
        XCTAssertEqual(
            SessionCountdown.state(expiresAt: now.addingTimeInterval(1_801), now: now),
            .hidden
        )
    }

    func testShowsAtThirtyMinutes() {
        XCTAssertEqual(
            SessionCountdown.state(expiresAt: now.addingTimeInterval(1_800), now: now),
            .warning("Session expires in 30:00")
        )
    }

    func testBecomesCriticalAtFiveMinutes() {
        XCTAssertEqual(
            SessionCountdown.state(expiresAt: now.addingTimeInterval(300), now: now),
            .critical("Session expires in 05:00")
        )
    }

    func testExpiresAtServerExpirationDate() {
        XCTAssertEqual(SessionCountdown.state(expiresAt: now, now: now), .expired)
    }

    func testRecalculatesFromAbsoluteTimeAfterBackgroundGap() {
        let expiration = now.addingTimeInterval(1_800)
        XCTAssertEqual(
            SessionCountdown.state(expiresAt: expiration, now: now.addingTimeInterval(601)),
            .warning("Session expires in 19:59")
        )
    }
}
