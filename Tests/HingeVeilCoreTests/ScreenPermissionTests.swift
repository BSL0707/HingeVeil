import XCTest
@testable import HingeVeilCore

final class ScreenPermissionTests: XCTestCase {
    func testFreshStateRequiresExplicitRequestAndNeverAssumesGrant() {
        let state = ScreenPermissionState()
        XCTAssertFalse(state.isGranted)
        XCTAssertFalse(state.requestAttempted)
        XCTAssertTrue(state.canRequest)
    }
    func testDeniedRequestCannotBeRepeatedInSameSession() {
        var state = ScreenPermissionState()
        XCTAssertTrue(state.beginRequest())
        XCTAssertFalse(state.beginRequest())
        state.completeRequest(granted: false)
        for _ in 0..<10 { state.observe(granted: false) }
        XCTAssertFalse(state.beginRequest())
        XCTAssertFalse(state.requestInFlight)
        XCTAssertFalse(state.isGranted)
    }
    func testRecheckRecognizesGrantWithoutRequestingAgain() {
        var state = ScreenPermissionState()
        XCTAssertTrue(state.beginRequest())
        state.completeRequest(granted: false)
        state.observe(granted: true)
        XCTAssertTrue(state.isGranted)
        XCTAssertFalse(state.canRequest)
        XCTAssertEqual(state.guidance.key, "권한이 확인됐습니다. 효과를 켤 수 있습니다.")
    }
    func testAlreadyGrantedStateDoesNotPrompt() {
        var state = ScreenPermissionState()
        state.observe(granted: true)
        XCTAssertFalse(state.beginRequest())
        XCTAssertFalse(state.requestAttempted)
    }
    func testReentrantRecheckCannotRaceSystemRequest() {
        var state = ScreenPermissionState()
        XCTAssertTrue(state.beginRequest())
        state.observe(granted: true)
        XCTAssertFalse(state.isGranted)
        XCTAssertTrue(state.requestInFlight)
        state.completeRequest(granted: true)
        XCTAssertTrue(state.isGranted)
        XCTAssertFalse(state.requestInFlight)
    }
    func testRevocationClearsGrantButDoesNotResetPromptLatch() {
        var state = ScreenPermissionState()
        XCTAssertTrue(state.beginRequest())
        state.completeRequest(granted: true)
        state.observe(granted: false)
        XCTAssertFalse(state.isGranted)
        XCTAssertFalse(state.canRequest)
        XCTAssertTrue(state.requestAttempted)
    }
    func testStrayCompletionCannotGrantPermission() {
        var state = ScreenPermissionState()
        state.completeRequest(granted: true)
        XCTAssertFalse(state.isGranted)
    }
    func testUnchangedObservationsDoNotChangePolicy() {
        var state = ScreenPermissionState()
        let initial = state
        state.observe(granted: false)
        XCTAssertEqual(state, initial)
    }
}
