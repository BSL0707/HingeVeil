import XCTest
@testable import HingeVeilCore

final class PermissionRecoveryTests: XCTestCase {
    private let now: TimeInterval = 1000
    private func request() -> PermissionRecovery.Request { .init(createdAt: now) }

    func testResetScopeCannotSelectOtherAppsOrServices() {
        XCTAssertEqual(PermissionRecovery.resetArguments, ["reset", "ScreenCapture", "com.bsl0707.hingeveil.preview"])
        XCTAssertFalse(PermissionRecovery.resetArguments.contains("All"))
    }
    func testRequestRejectsMalformedExpiredFutureAndUnsupportedMessages() {
        XCTAssertTrue(request().isValid(now: now))
        XCTAssertFalse(PermissionRecovery.Request(nonce: "invalid", createdAt: now).isValid(now: now))
        XCTAssertFalse(request().isValid(now: now + 61))
        XCTAssertFalse(request().isValid(now: now - 6))
        XCTAssertFalse(request().isValid(now: .nan))
        var other = request(); other.version = 2
        XCTAssertFalse(other.isValid(now: now))
    }
    func testLiveParentNeverResetsOrRelaunches() {
        var calls = 0
        let result = PermissionRecovery.perform(request: request(), parentExited: false, now: now,
            reset: { calls += 1; return 0 }, save: { _ in calls += 1 }, relaunch: { calls += 1; return true })
        XCTAssertEqual(result, .aborted); XCTAssertEqual(calls, 0)
    }
    func testInvalidRequestNeverResetsEvenWithAnExitedParent() {
        var calls = 0
        let result = PermissionRecovery.perform(request: .init(nonce: "invalid", createdAt: now), parentExited: true, now: now,
            reset: { calls += 1; return 0 }, save: { _ in calls += 1 }, relaunch: { calls += 1; return true })
        XCTAssertEqual(result, .aborted); XCTAssertEqual(calls, 0)
    }
    func testSuccessfulFlowResetsSavesAndRelaunchesExactlyOnceInOrder() {
        var events = [String]()
        let req = request()
        let result = PermissionRecovery.perform(request: req, parentExited: true, now: now,
            reset: { events.append("reset"); return 0 },
            save: { XCTAssertEqual($0.request, req); XCTAssertEqual($0.resetExitCode, 0); events.append("save") },
            relaunch: { events.append("relaunch"); return true })
        XCTAssertEqual(result, .reopened(resetSucceeded: true))
        XCTAssertEqual(events, ["reset", "save", "relaunch"])
        // Reset success is never an OS authorization result.
        XCTAssertFalse(ScreenPermissionState().isGranted)
    }
    func testResetFailureStillReopensWithFailureReceiptWithoutRetrying() {
        var codes = [Int32](), resets = 0
        let result = PermissionRecovery.perform(request: request(), parentExited: true, now: now,
            reset: { resets += 1; return 1 }, save: { codes.append($0.resetExitCode) }, relaunch: { true })
        XCTAssertEqual(result, .reopened(resetSucceeded: false)); XCTAssertEqual(resets, 1); XCTAssertEqual(codes, [1])
    }
    func testReceiptFailureAndRelaunchFailureDoNotLoopOrReportSuccess() {
        var launches = 0
        let result = PermissionRecovery.perform(request: request(), parentExited: true, now: now,
            reset: { 0 }, save: { _ in throw CocoaError(.fileWriteNoPermission) },
            relaunch: { launches += 1; return true })
        XCTAssertEqual(result, .receiptFailed); XCTAssertEqual(launches, 1)
        XCTAssertEqual(PermissionRecovery.perform(request: request(), parentExited: true, now: now,
            reset: { 0 }, save: { _ in }, relaunch: { false }), .relaunchFailed)
    }
    func testReceiptRequiresMatchingNonceAndRecentCompletion() {
        let req = request(), receipt = PermissionRecovery.Receipt(request: request(), resetExitCode: 0, completedAt: now)
        XCTAssertFalse(receipt.matches(nonce: req.nonce, now: now))
        XCTAssertFalse(receipt.matches(nonce: receipt.request.nonce, now: now + 601))
        XCTAssertFalse(receipt.matches(nonce: receipt.request.nonce, now: now - 6))
        XCTAssertTrue(receipt.matches(nonce: receipt.request.nonce, now: now + 1))
    }
    func testReceiptRoundTripIsPrivateAndConsumedOnlyOnce() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let req = request(), receipt = PermissionRecovery.Receipt(request: request(), resetExitCode: 0, completedAt: now)
        try PermissionRecovery.save(receipt, directory: directory)
        XCTAssertNil(PermissionRecovery.consume(nonce: req.nonce, directory: directory, now: now))
        let path = directory.appendingPathComponent("PermissionRecovery.json")
        let attributes = try FileManager.default.attributesOfItem(atPath: path.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        XCTAssertEqual(PermissionRecovery.consume(nonce: receipt.request.nonce, directory: directory, now: now), receipt)
        XCTAssertNil(PermissionRecovery.consume(nonce: receipt.request.nonce, directory: directory, now: now))
    }
    func testRecoveryRefusesReceiptSymlinks() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try PermissionRecovery.prepare(directory: directory)
        let target = directory.appendingPathComponent("target")
        try Data("unchanged".utf8).write(to: target)
        let link = directory.appendingPathComponent("PermissionRecovery.json")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        XCTAssertThrowsError(try PermissionRecovery.save(.init(request: request(), resetExitCode: 0), directory: directory))
        XCTAssertNil(PermissionRecovery.consume(nonce: request().nonce, directory: directory))
        XCTAssertEqual(try Data(contentsOf: target), Data("unchanged".utf8))
    }
    func testInstalledLocationIsNotAPathPrefixLookalike() {
        XCTAssertTrue(PermissionRecovery.installedLocation(URL(fileURLWithPath: "/Applications/HingeVeil.app")))
        XCTAssertFalse(PermissionRecovery.installedLocation(URL(fileURLWithPath: "/Applications-other/HingeVeil.app")))
        XCTAssertFalse(PermissionRecovery.installedLocation(URL(fileURLWithPath: "/tmp/HingeVeil.app")))
        XCTAssertFalse(PermissionRecovery.installedLocation(URL(fileURLWithPath: "/Applications/file.txt")))
    }
    func testPrivatePipeIsBoundedAndNewlineTerminated() throws {
        let pipe = Pipe()
        defer { pipe.fileHandleForReading.closeFile(); pipe.fileHandleForWriting.closeFile() }
        try pipe.fileHandleForWriting.write(contentsOf: Data("ready\n".utf8))
        XCTAssertEqual(PermissionRecovery.readLine(fd: pipe.fileHandleForReading.fileDescriptor, timeout: 0.1), Data("ready".utf8))
        try pipe.fileHandleForWriting.write(contentsOf: Data("too-long\n".utf8))
        XCTAssertNil(PermissionRecovery.readLine(fd: pipe.fileHandleForReading.fileDescriptor, timeout: 0.1, limit: 3))
    }
}
