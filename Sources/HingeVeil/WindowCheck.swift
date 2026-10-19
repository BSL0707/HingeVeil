import AppKit
import CoreVideo
import HingeVeilCore

@MainActor
enum WindowCheck {
    /// Exercise a real window and drawable, with generated pixels only. This
    /// closes a validation gap left by offscreen GPU tests.
    static func run(stagingAlpha: CGFloat, animated: Bool = false, patterned: Bool = false,
                    transitions: Bool = false) -> Never {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        guard let screen = NSScreen.main else { exit(2) }
        var buffer: CVPixelBuffer?
        let attributes = [kCVPixelBufferMetalCompatibilityKey: true,
                          kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary
        let width = animated || transitions ? 2560 : 1280
        let height = animated || transitions ? 1600 : 800
        guard CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA,
                                  attributes, &buffer) == kCVReturnSuccess, let buffer else { exit(2) }
        CVPixelBufferLockBaseAddress(buffer, [])
        if let bytes = CVPixelBufferGetBaseAddress(buffer)?.assumingMemoryBound(to: UInt8.self) {
            let row = CVPixelBufferGetBytesPerRow(buffer)
            for y in 0..<height {
                for x in 0..<width {
                    let index = y * row + x * 4
                    bytes[index] = 80; bytes[index + 1] = UInt8(60 + y * 160 / height)
                    bytes[index + 2] = UInt8(40 + x * 160 / width); bytes[index + 3] = 255
                    if patterned {
                        let grid = x % 40 < 3 || y % 40 < 3
                        bytes[index] = grid ? 220 : 70
                        bytes[index + 1] = grid ? 220 : 100
                        bytes[index + 2] = grid ? 220 : 45
                        if x > width / 3 && x < width * 2 / 3 && y > height / 4 && y < height * 3 / 4 {
                            bytes[index] = 80; bytes[index + 1] = 190; bytes[index + 2] = 245
                        }
                    }
                }
            }
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        let mailbox = ScreenMailbox()
        mailbox.accept(buffer)
        do {
            let window = try EffectWindow(screen: screen, mailbox: mailbox, stagingAlpha: stagingAlpha)
            window.show(angle: transitions ? 32 : (patterned ? 110 : 60), options: VeilOptions())
            if transitions { runTransitions(window: window, application: application) }
            let began = ProcessInfo.processInfo.systemUptime
            if animated {
                Timer.scheduledTimer(withTimeInterval: 1 / 60.0, repeats: true) { _ in
                    MainActor.assumeIsolated {
                        let elapsed = ProcessInfo.processInfo.systemUptime - began
                        let quantizedAngle = patterned
                            ? (110 - 78 * pow(sin(min(1, elapsed / 5) * .pi), 2)).rounded()
                            : (60 + 22 * sin(elapsed * 2)).rounded()
                        window.show(angle: quantizedAngle, options: VeilOptions(blurLevel: patterned ? 2 : 4))
                    }
                }
            }
            Timer.scheduledTimer(withTimeInterval: animated ? 5 : 1.2, repeats: false) { _ in
                MainActor.assumeIsolated {
                    let result = window.diagnostics()
                    window.hide()
                    if let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]),
                       let string = String(data: data, encoding: .utf8) { print(string) }
                    let passed = (result["completedFrames"] as? Int ?? 0) > (animated ? 120 : 0)
                        && (result["windowAlpha"] as? CGFloat ?? 0) == 1
                    exit(passed ? 0 : 1)
                }
            }
            withExtendedLifetime(window) { application.run() }
        } catch { fputs("창 표시 검증 실패: \(error)\n", stderr) }
        exit(2)
    }

    /// Real AppKit opacity readback and lifecycle checks, generated pixels only.
    /// Includes reentry during exit and an emergency during the next entrance.
    private static func runTransitions(window: EffectWindow, application: NSApplication) -> Never {
        let began = ProcessInfo.processInfo.systemUptime
        var stage = 0
        var intermediateIn = 0, intermediateOut = 0
        var resumedStayedVisible = false, normalExitHidden = false
        var emergencyImmediate = false, emergencyStayedHidden = false
        var firstFramesNeutral = true
        let timer = Timer(timeInterval: 1 / 120.0, repeats: true) { _ in
            MainActor.assumeIsolated {
                let elapsed = ProcessInfo.processInfo.systemUptime - began
                let d = window.diagnostics()
                let alpha = d["windowAlpha"] as? CGFloat ?? -1
                let phase = d["transitionPhase"] as? String ?? ""
                if alpha > 0.01 && alpha < 0.99 {
                    if phase == "fadingIn" { intermediateIn += 1 }
                    if phase == "fadingOut" { intermediateOut += 1 }
                }
                if (d["completedFrames"] as? Int ?? 0) > 0 {
                    firstFramesNeutral = firstFramesNeutral && (d["firstFrameAmount"] as? Double ?? -1) == 0
                }
                if stage == 0 && elapsed >= 0.70 {
                    window.finish(options: VeilOptions()); stage = 1
                } else if stage == 1 && elapsed >= 0.82 {
                    window.show(angle: 32, options: VeilOptions()); stage = 2
                } else if stage == 2 && elapsed >= 1.20 {
                    resumedStayedVisible = window.visible && alpha > 0.99
                    stage = 3
                } else if stage == 3 && elapsed >= 1.30 {
                    window.finish(options: VeilOptions()); stage = 4
                } else if stage == 4 && elapsed >= 1.65 {
                    normalExitHidden = !window.visible && alpha == 0
                    stage = 5
                } else if stage == 5 && elapsed >= 1.80 {
                    window.show(angle: 60, options: VeilOptions()); stage = 6
                } else if stage == 6 && elapsed >= 1.86 {
                    window.hide()
                    emergencyImmediate = !window.visible && (window.diagnostics()["windowAlpha"] as? CGFloat) == 0
                    stage = 7
                } else if stage == 7 && elapsed >= 2.15 {
                    emergencyStayedHidden = !window.visible && alpha == 0
                    stage = 8
                } else if stage == 8 && elapsed >= 2.25 {
                    window.show(angle: 60, options: VeilOptions()); stage = 9
                } else if stage == 9 && elapsed >= 2.95 {
                    var result = d
                    result["intermediateFadeInSamples"] = intermediateIn
                    result["intermediateFadeOutSamples"] = intermediateOut
                    result["resumedStayedVisible"] = resumedStayedVisible
                    result["normalExitHidden"] = normalExitHidden
                    result["emergencyImmediate"] = emergencyImmediate
                    result["emergencyStayedHidden"] = emergencyStayedHidden
                    result["firstFramesNeutral"] = firstFramesNeutral
                    let passed = intermediateIn >= 3 && intermediateOut >= 3
                        && resumedStayedVisible && normalExitHidden && emergencyImmediate
                        && emergencyStayedHidden && firstFramesNeutral && window.visible && alpha > 0.99
                    window.hide()
                    if let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]),
                       let string = String(data: data, encoding: .utf8) { print(string) }
                    exit(passed ? 0 : 1)
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        withExtendedLifetime(window) { application.run() }
        exit(2)
    }
}
