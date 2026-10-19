import XCTest
@testable import HingeVeilCore

final class CoreTests: XCTestCase {
    func testCounterProjectionIsFiniteSymmetricAndIndependentOfBlurAndAspect() {
        for aspect in [2560.0 / 1600, 3024.0 / 1964, 2880.0 / 1864, 3456.0 / 2234] {
            for start in [85.0, 90, 95, 100] {
                for level in 1...4 {
                    for angle in stride(from: 130.0, through: 0, by: -2.5) {
                        let p = VeilProjection(angle: angle, options: VeilOptions(startAngle: start, blurLevel: level))
                        for x in [0.0, 0.1, 0.5, 0.9, 1] {
                            for y in [0.0, 0.2, 0.6, 1] {
                                let source = p.sourcePoint(x: x, y: y)
                                let mirrored = p.sourcePoint(x: 1 - x, y: y)
                                let defaultPoint = VeilProjection(angle: angle, options: VeilOptions(startAngle: start))
                                    .sourcePoint(x: x, y: y)
                                XCTAssertTrue(source.x.isFinite && source.y.isFinite)
                                XCTAssertEqual(source.x + mirrored.x, 1, accuracy: 1e-12)
                                XCTAssertEqual(source.x * aspect, defaultPoint.x * aspect, accuracy: 1e-12)
                                XCTAssertEqual(source.y, defaultPoint.y, accuracy: 1e-12)
                                XCTAssertGreaterThanOrEqual(source.y, y - 1e-12)
                                if angle >= start {
                                    XCTAssertEqual(source.x, x, accuracy: 1e-12)
                                    XCTAssertEqual(source.y, y, accuracy: 1e-12)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    func testPanelEnlargementIsBoundedInsteadOfFittingAtDeepClosure() {
        // Independent finite differences on actual panel coordinates. A full
        // inverse projection must fail this even if its virtual view is exact.
        let epsilon = 0.0001
        for start in [85.0, 90, 95, 100] {
            for angle in stride(from: 130.0, through: 0, by: -2.5) {
                let p = VeilProjection(angle: angle, options: VeilOptions(startAngle: start))
                for x in [0.1, 0.5, 0.9] {
                    for y in [0.1, 0.5, 0.9] {
                        let base = p.sourcePoint(x: x, y: y)
                        let dx = p.sourcePoint(x: x + epsilon, y: y)
                        let dy = p.sourcePoint(x: x, y: y + epsilon)
                        let horizontalGain = epsilon / (dx.x - base.x)
                        let verticalGain = epsilon / (dy.y - base.y)
                        XCTAssertGreaterThanOrEqual(horizontalGain, 0.975 - 1e-8)
                        XCTAssertLessThanOrEqual(horizontalGain, 1 + 1e-8)
                        XCTAssertGreaterThanOrEqual(verticalGain, 0.95)
                        XCTAssertLessThanOrEqual(verticalGain, 1.12 + 1e-8)
                        XCTAssertEqual(dx.y, base.y, accuracy: 1e-12)
                        XCTAssertLessThan(abs((dy.x - base.x) / epsilon), 0.014)
                    }
                }
            }
        }
    }
    func testTopIsCroppedWithoutFittingAndBottomHingeStaysFixed() {
        for start in [85.0, 90, 95, 100] {
            let p = VeilProjection(angle: 32, options: VeilOptions(startAngle: start))
            let top = p.sourcePoint(x: 0.5, y: 0)
            XCTAssertGreaterThan(top.y, 0.07)
            XCTAssertLessThan(top.y, 0.086)
            // A negative source coordinate must stay negative for clipping,
            // not be clamped and stretched into an edge strip.
            XCTAssertLessThan(p.sourcePoint(x: 0, y: 0.5).x, 0)
            XCTAssertGreaterThan(p.sourcePoint(x: 1, y: 0.5).x, 1)
            for x in [0.0, 0.2, 0.5, 0.8, 1] {
                let hinge = p.sourcePoint(x: x, y: 1)
                XCTAssertEqual(hinge.x, x, accuracy: 1e-12)
                XCTAssertEqual(hinge.y, 1)
            }
        }
    }
    func testCounterProjectionMovesAgainstLidAndImprovesVirtualReference() {
        // Independent ray/plane geometry, not just undoing sourcePoint.
        // Partial compensation should reduce drift, not claim exact locking.
        for delta in [5.0, 10, 20, 30, 45, 60] {
            let p = VeilProjection(angle: 90 - delta, options: VeilOptions())
            let radians = delta * .pi / 180
            for sourceY in [0.25, 0.5, 0.8] {
                let sourceHeight = 1 - sourceY
                let panelHeight = sourceHeight / (1 - p.counterCompression + p.counterDepth * sourceHeight)
                XCTAssertGreaterThan(panelHeight, sourceHeight)
                func observedHeight(_ height: Double) -> Double {
                    let worldHeight = height * cos(radians)
                    let depth = height * sin(radians)
                    return (worldHeight - 1.2 * depth / 3) / (1 - depth / 3)
                }
                let uncorrectedError = abs(observedHeight(sourceHeight) - sourceHeight)
                let correctedError = abs(observedHeight(panelHeight) - sourceHeight)
                XCTAssertLessThan(correctedError, uncorrectedError)
                XCTAssertGreaterThan(correctedError, 0.00001) // Not eye tracking.
            }
        }
    }
    func testCounterProjectionHasSmoothOnsetAndNoDeepAngleSingularity() {
        for start in [85.0, 90, 95, 100] {
            let open = VeilProjection(angle: start, options: VeilOptions(startAngle: start))
            XCTAssertEqual(open.counterCompression, 0)
            XCTAssertEqual(open.counterDepth, 0)
            let first = VeilProjection(angle: start - 0.01, options: VeilOptions(startAngle: start))
            XCTAssertLessThan(first.counterCompression, 1e-8)
            XCTAssertLessThan(first.counterDepth, 1e-8)
            var previousY = 0.0
            for angle in stride(from: start, through: 0, by: -0.05) {
                let p = VeilProjection(angle: angle, options: VeilOptions(startAngle: start))
                let y = p.sourcePoint(x: 0.5, y: 0).y
                XCTAssertGreaterThanOrEqual(y, previousY - 1e-12)
                XCTAssertLessThan(y - previousY, 0.001)
                XCTAssertLessThanOrEqual(p.counterDepth, 0.025)
                XCTAssertGreaterThanOrEqual(p.counterCompression, p.counterDepth - 1e-12)
                previousY = y
            }
        }
    }
    func testCounterProjectionKeepsMovingThroughMiddleAndLateClosure() {
        for start in [85.0, 90, 95, 100] {
            func projection(_ amount: Double) -> VeilProjection {
                VeilProjection(angle: start - (start - 15) * amount,
                               options: VeilOptions(startAngle: start))
            }
            let middle = projection(0.5)
            let deep = projection(0.8)
            let deeper = projection(0.9)
            let end = projection(1)
            XCTAssertEqual(middle.counterCompression / end.counterCompression, 0.75, accuracy: 1e-12)
            // The former exponential had exhausted nearly all compensation
            // here. Require measurable content motion, not just edge changes.
            for y in [0.0, 0.5] {
                XCTAssertGreaterThan(deep.sourcePoint(x: 0.5, y: y).y
                    - middle.sourcePoint(x: 0.5, y: y).y, 0.008)
                XCTAssertGreaterThan(deeper.sourcePoint(x: 0.5, y: y).y
                    - deep.sourcePoint(x: 0.5, y: y).y, 0.001)
            }
            XCTAssertEqual(end.counterCompression, 1 - 1 / 1.12, accuracy: 1e-12)
            XCTAssertEqual(end.counterDepth, 0.025, accuracy: 1e-12)
        }
    }
    func testShowCanStartAtNeutralWithoutJumpingToAnAlreadyClosedLid() {
        for hz in [60.0, 120] {
            var follower = AngleFollower()
            _ = follower.advance(toward: 90, seconds: 0)
            let first = follower.advance(toward: 32, seconds: 1 / hz)
            XCTAssertGreaterThan(first, 86)
            XCTAssertLessThan(first, 90)
            for _ in 0..<Int(hz) { _ = follower.advance(toward: 32, seconds: 1 / hz) }
            XCTAssertEqual(follower.angle!, 32, accuracy: 0.002)
            var previous = follower.angle!
            for _ in 0..<Int(hz) {
                let next = follower.advance(toward: 90, seconds: 1 / hz)
                XCTAssertGreaterThanOrEqual(next, previous)
                XCTAssertLessThanOrEqual(next, 90)
                previous = next
            }
            XCTAssertEqual(previous, 90, accuracy: 0.002)
        }
    }
    func testApertureStaysWideWithFixedBottomHinge() {
        for angle in stride(from: 130.0, through: 0, by: -0.5) {
            let p = VeilProjection(angle: angle, options: VeilOptions())
            XCTAssertGreaterThanOrEqual(1 - 2 * p.sideInset, 0.91)
            XCTAssertTrue((0...0.025).contains(p.topInset))
            XCTAssertEqual(p.sideInset * (1 - 1), 0)
            XCTAssertEqual(p.sourcePoint(x: 0.25, y: 1).y, 1)
        }
    }
    func testApertureNeverReversesAsLidCloses() {
        for start in [85.0, 90, 95, 100] {
            var previous = 0.0
            var previousInset = 0.0
            for angle in stride(from: 130.0, through: 0, by: -0.5) {
                let p = VeilProjection(angle: angle, options: VeilOptions(startAngle: start))
                XCTAssertGreaterThanOrEqual(p.amount, previous - 0.000001)
                XCTAssertGreaterThanOrEqual(p.sideInset, previousInset - 0.000001)
                previousInset = p.sideInset
                previous = p.amount
            }
        }
    }
    func testWholeScreenSoftensAndFocusFrontTravelsIndependentlyOfProjection() {
        let p = VeilProjection(angle: 67.5, options: VeilOptions())
        XCTAssertGreaterThan(p.blurMix(x: 0.5, y: 0.5), 0.34)
        XCTAssertGreaterThan(p.blurMix(x: 0.08, y: 0.5), 0.5)
        XCTAssertGreaterThan(p.blurMix(x: 0.5, y: 0.10), p.blurMix(x: 0.5, y: 0.8))
        for x in stride(from: 0.0, through: 1, by: 0.05) {
            for y in stride(from: 0.0, through: 1, by: 0.05) {
                XCTAssertEqual(p.blurMix(x: x, y: y), p.blurMix(x: 1 - x, y: y), accuracy: 1e-12)
                for angle in [110.0, 67.5, 32, 15] {
                    let q = VeilProjection(angle: angle, options: VeilOptions())
                    XCTAssertTrue((0...1).contains(q.blurMix(x: x, y: y)))
                    XCTAssertTrue((0...0.225).contains(q.shadeAt(y: y)))
                }
            }
        }
    }
    func testCentralBlurStrengthAndOuterEdgeMixArePreserved() {
        for level in 1...4 {
            let p = VeilProjection(angle: 67.5, options: VeilOptions(blurLevel: level))
            let middle = p.blurMix(x: 0.5, y: 0.5)
            XCTAssertEqual(middle, 0.3453192, accuracy: 1e-7)
            XCTAssertGreaterThan(middle, 0.13272 * 2.5) // Previous 0.1.5 baseline.
            XCTAssertEqual(p.sourcePoint(x: 0.5, y: 0.5).x, 0.5)
            XCTAssertGreaterThan(p.sourcePoint(x: 0.5, y: 0.5).y, 0.5)
            for angle in [110.0, 89, 67.5, 50, 32, 15] {
                let q = VeilProjection(angle: angle, options: VeilOptions(blurLevel: level))
                let unchangedEdge = 1 - pow(1 - q.amount, 3)
                for y in [0.0, 0.25, 0.5, 0.75, 1] {
                    XCTAssertEqual(q.blurMix(x: 0, y: y), unchangedEdge, accuracy: 1e-12)
                    XCTAssertEqual(q.blurMix(x: 1, y: y), unchangedEdge, accuracy: 1e-12)
                    XCTAssertLessThanOrEqual(q.blurMix(x: 0.5, y: y), unchangedEdge)
                }
            }
        }
    }
    func testCentralBlurHasContinuousOnsetAndIncreasesWithClosure() {
        for start in [85.0, 90, 95, 100] {
            for y in [0.0, 0.25, 0.5, 0.75, 1] {
                var previous = 0.0
                for angle in stride(from: start, through: 15, by: -0.25) {
                    let p = VeilProjection(angle: angle, options: VeilOptions(startAngle: start))
                    let mix = p.blurMix(x: 0.5, y: y)
                    XCTAssertGreaterThanOrEqual(mix, previous - 1e-12)
                    XCTAssertLessThanOrEqual(mix, 0.92)
                    previous = mix
                }
                let open = VeilProjection(angle: start, options: VeilOptions(startAngle: start))
                let first = VeilProjection(angle: start - 0.01, options: VeilOptions(startAngle: start))
                XCTAssertEqual(open.blurMix(x: 0.5, y: y), 0)
                XCTAssertLessThan(first.blurMix(x: 0.5, y: y), 0.001)
            }
        }
    }
    func testFourBlurLevelsAndSafeDefaults() {
        let radii = (1...4).map { VeilProjection(angle: 40, options: VeilOptions(blurLevel: $0)).blurPixels }
        XCTAssertEqual(radii, radii.sorted())
        XCTAssertEqual(Set(radii).count, 4)
        XCTAssertEqual(VeilOptions().blurLevel, 2)
        XCTAssertEqual(VeilOptions(startAngle: .nan).startAngle, 90)
        XCTAssertEqual(VeilProjection(angle: .nan, options: VeilOptions()).amount, 0)
        XCTAssertEqual(VeilProjection(angle: .infinity, options: VeilOptions()).topInset, 0)
    }
    func testThirtyPercentTestHasMeaningfulSilhouetteAndBlur() {
        let options = VeilOptions()
        let angle = options.startAngle - (options.startAngle - 15) * 0.30
        let p = VeilProjection(angle: angle, options: options)
        XCTAssertEqual(p.amount, 0.30, accuracy: 0.000001)
        XCTAssertGreaterThan(p.sideInset, 0.009)
        XCTAssertGreaterThanOrEqual(p.blurPixels, 7)
        XCTAssertGreaterThan(p.feather, 0.004)
        XCTAssertGreaterThan(p.topInset, 0.005)
        XCTAssertLessThan(p.sourcePoint(x: 0.2, y: 0.8).x, 0.2)
        XCTAssertGreaterThan(p.sourcePoint(x: 0.2, y: 0.8).y, 0.8)
    }
    func testSilhouetteStartsContinuouslyAndIsIndependentOfBlurChoice() {
        let open = VeilProjection(angle: 90, options: VeilOptions())
        let first = VeilProjection(angle: 89.99, options: VeilOptions())
        XCTAssertEqual(open.sideInset, 0)
        XCTAssertEqual(open.feather, 0)
        XCTAssertLessThan(first.sideInset, 0.00002)
        XCTAssertLessThan(first.feather, 0.000001)
        XCTAssertEqual(first.sourcePoint(x: 0.2, y: 0.4).x, 0.2, accuracy: 0.00001)
        XCTAssertEqual(first.sourcePoint(x: 0.2, y: 0.4).y, 0.4, accuracy: 0.00001)
        for level in 1...4 {
            let p = VeilProjection(angle: 32, options: VeilOptions(blurLevel: level))
            XCTAssertEqual(p.sideInset, VeilProjection(angle: 32, options: VeilOptions()).sideInset)
            XCTAssertEqual(p.sourcePoint(x: 0.3, y: 0.4).y,
                           VeilProjection(angle: 32, options: VeilOptions()).sourcePoint(x: 0.3, y: 0.4).y)
        }
    }
    func testSmoothingIndependentOfFrameRate() {
        func run(_ hz: Double) -> Double {
            var f = AngleFollower()
            _ = f.advance(toward: 100, seconds: 0)
            for _ in 0..<Int(hz) { _ = f.advance(toward: 40, seconds: 1 / hz) }
            return f.angle!
        }
        XCTAssertEqual(run(60), run(120), accuracy: 0.02)
    }
    func testReportValidation() {
        XCTAssertEqual(HingeReport.angle(bytes: [1, 104, 1]), 360)
        XCTAssertEqual(HingeReport.angle(bytes: [1, 90, 0]), 90)
        XCTAssertNil(HingeReport.angle(bytes: [2, 90, 0]))
        XCTAssertNil(HingeReport.angle(bytes: [1, 255, 255]))
        XCTAssertNil(HingeReport.angle(bytes: [1]))
    }
    func testOneDegreeStepDoesNotJumpAndSettlesWithoutOscillation() {
        var follower = AngleFollower()
        _ = follower.advance(toward: 90, seconds: 0)
        let first = follower.advance(toward: 89, seconds: 1 / 60.0)
        XCTAssertGreaterThan(first, 89.90)
        XCTAssertLessThan(first, 90)
        var previous = first
        for _ in 0..<60 {
            let next = follower.advance(toward: 89, seconds: 1 / 60.0)
            XCTAssertLessThanOrEqual(next, previous)
            XCTAssertGreaterThanOrEqual(next, 89)
            previous = next
        }
        XCTAssertEqual(previous, 89, accuracy: 0.002)
        follower.reset()
        XCTAssertEqual(follower.advance(toward: 70, seconds: 1 / 60.0), 70)
    }
    func testTrackingLagIsBoundedForQuantizedSensorRamp() {
        var follower = AngleFollower()
        _ = follower.advance(toward: 90, seconds: 0)
        for i in 1...120 {
            let trueAngle = 90 - Double(i) / 60 * 20
            let tracked = follower.advance(toward: trueAngle.rounded(), seconds: 1 / 60.0)
            XCTAssertGreaterThanOrEqual(tracked, trueAngle - 0.5)
            XCTAssertLessThan(tracked - trueAngle, 2.5)
        }
    }
    func testSafetyTimeoutRequiresReopening() {
        var gate = EffectGate()
        XCTAssertEqual(gate.evaluate(now: 0, angle: 32, startAngle: 90, sensorFresh: true, captureFresh: true), .visible)
        guard case .stopped = gate.evaluate(now: 15, angle: 32, startAngle: 90, sensorFresh: true, captureFresh: true) else { return XCTFail("timeout") }
        XCTAssertEqual(gate.evaluate(now: 16, angle: 32, startAngle: 90, sensorFresh: true, captureFresh: true), .hidden)
        XCTAssertEqual(gate.evaluate(now: 17, angle: 94, startAngle: 90, sensorFresh: true, captureFresh: true), .hidden)
        XCTAssertFalse(gate.needsOpen)
        XCTAssertEqual(gate.evaluate(now: 18, angle: 32, startAngle: 90, sensorFresh: true, captureFresh: true), .visible)
    }
    func testCaptureFailureHidesAndLatchesButStartupCanWait() {
        var gate = EffectGate()
        XCTAssertEqual(gate.evaluate(now: 0, angle: 60, startAngle: 90, sensorFresh: true, captureFresh: false), .hidden)
        XCTAssertFalse(gate.needsOpen)
        _ = gate.evaluate(now: 1, angle: 60, startAngle: 90, sensorFresh: true, captureFresh: true)
        guard case .stopped = gate.evaluate(now: 2, angle: 60, startAngle: 90, sensorFresh: true, captureFresh: false) else { return XCTFail("stale capture") }
        XCTAssertTrue(gate.needsOpen)
    }
    func testRestingAtStartAngleDoesNotCoverDesktop() {
        var gate = EffectGate()
        XCTAssertEqual(gate.evaluate(now: 0, angle: 90, startAngle: 90, sensorFresh: true, captureFresh: true), .hidden)
        XCTAssertEqual(gate.evaluate(now: 30, angle: 90, startAngle: 90, sensorFresh: true, captureFresh: true), .hidden)
        XCTAssertEqual(gate.evaluate(now: 31, angle: 89, startAngle: 90, sensorFresh: true, captureFresh: true), .visible)
    }
}
