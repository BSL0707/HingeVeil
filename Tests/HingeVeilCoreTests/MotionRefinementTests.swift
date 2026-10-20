import XCTest
@testable import HingeVeilCore

final class MotionRefinementTests: XCTestCase {
    func testContentKeepsMovingInEveryFiveDegreeStepDownToTwentyDegrees() {
        for start in [85.0, 90, 95, 100] {
            for level in 1...4 {
                let options = VeilOptions(startAngle: start, blurLevel: level)
                for (higher, lower) in [(40.0, 35.0), (35, 30), (30, 25), (25, 20)] {
                    let before = VeilProjection(angle: higher, options: options)
                    let after = VeilProjection(angle: lower, options: options)
                    // At a 2000-pixel display height this requires over four
                    // pixels of top-plane compensation per five-degree step.
                    // Aperture/blur changes alone must not satisfy the test.
                    XCTAssertGreaterThan(after.sourcePoint(x: 0.5, y: 0).y
                        - before.sourcePoint(x: 0.5, y: 0).y, 0.002)
                    XCTAssertGreaterThan(after.sourcePoint(x: 0.5, y: 0.5).y
                        - before.sourcePoint(x: 0.5, y: 0.5).y, 0.001)
                }
            }
        }
    }

    func testBottomHingeBlurStaysLightAtEveryStrengthAndClosingAngle() {
        for start in [85.0, 90, 95, 100] {
            for level in 1...4 {
                for angle in [start, start - 0.01, 67.5, 50, 32, 30, 25, 20, 15, 0] {
                    let p = VeilProjection(angle: angle, options: VeilOptions(startAngle: start, blurLevel: level))
                    for x in [0.0, 0.08, 0.25, 0.5, 0.75, 0.92, 1] {
                        XCTAssertLessThanOrEqual(p.blurMix(x: x, y: 1), 0.08 + 1e-12)
                        XCTAssertLessThan(p.blurMix(x: x, y: 0.95), 0.14)
                        XCTAssertGreaterThanOrEqual(p.blurMix(x: x, y: 1), 0)
                        XCTAssertEqual(p.blurMix(x: x, y: 1), p.blurMix(x: 1 - x, y: 1), accuracy: 1e-12)
                    }
                }
            }
        }
    }

    func testLowerFadePreservesEstablishedMiddleAndSideHaze() {
        for angle in [89.0, 67.5, 50, 32, 20, 15] {
            let p = VeilProjection(angle: angle, options: VeilOptions())
            let edge = 1 - pow(1 - p.amount, 3)
            for y in [0.1, 0.4, 0.5, 0.7, 0.72] {
                XCTAssertEqual(p.blurMix(x: 0, y: y), edge, accuracy: 1e-12)
                XCTAssertEqual(p.blurMix(x: 1, y: y), edge, accuracy: 1e-12)
            }
            XCTAssertGreaterThan(p.blurMix(x: 0.5, y: 0.5), p.blurMix(x: 0.5, y: 0.95))
        }
        XCTAssertEqual(VeilProjection(angle: 67.5, options: VeilOptions()).blurMix(x: 0.5, y: 0.5),
                       0.3453192, accuracy: 1e-7)
    }

    func testDeepEndRemainsSmoothBoundedAndStationaryBelowFifteenDegrees() {
        for start in [85.0, 90, 95, 100] {
            let options = VeilOptions(startAngle: start)
            let end = VeilProjection(angle: 15, options: options)
            XCTAssertEqual(end, VeilProjection(angle: 0, options: options))
            XCTAssertEqual(end.counterCompression, 1 - 1 / 1.12, accuracy: 1e-12)
            let justBeforeEnd = VeilProjection(angle: 15.001, options: options)
            XCTAssertLessThan(end.counterCompression - justBeforeEnd.counterCompression, 1e-8)
            for boundary in [20.0, 19, 16, 15] {
                let before = VeilProjection(angle: boundary + 0.001, options: options)
                let after = VeilProjection(angle: boundary - 0.001, options: options)
                XCTAssertLessThan(abs(after.counterCompression - before.counterCompression), 0.00001)
            }
        }
    }
}
