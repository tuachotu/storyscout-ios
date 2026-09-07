import XCTest
@testable import StoryScout

final class RecordingDurationTests: XCTestCase {
    func testFormatsMinutesAndSeconds() {
        XCTAssertEqual(RecordingDuration.format(0), "00:00")
        XCTAssertEqual(RecordingDuration.format(61.9), "01:01")
        XCTAssertEqual(RecordingDuration.format(7_200), "120:00")
    }

    func testClampsNegativeDuration() {
        XCTAssertEqual(RecordingDuration.format(-1), "00:00")
    }
}
