import Foundation

public struct EffectGate {
    public enum Decision: Equatable {
        case hidden
        case visible
        case stopped(String)
    }

    public private(set) var needsOpen = false
    private var began: Double?
    public init() {}

    public mutating func cancel() {
        began = nil
        needsOpen = true
    }

    public mutating func evaluate(now: Double, angle: Double, startAngle: Double,
                                  sensorFresh: Bool, captureFresh: Bool) -> Decision {
        guard now.isFinite, angle.isFinite else { cancel(); return .stopped("각도 신호 오류") }
        if angle >= startAngle + 3 {
            began = nil
            needsOpen = false
            return .hidden
        }
        if needsOpen { return .hidden }
        if began == nil && angle > startAngle - 0.5 { return .hidden }
        guard sensorFresh else { cancel(); return .stopped("센서 신호가 끊겨 효과를 해제했습니다.") }
        guard captureFresh else {
            if began != nil { cancel(); return .stopped("화면 신호가 끊겨 효과를 해제했습니다.") }
            return .hidden
        }
        if angle >= startAngle + 0.5 { began = nil; return .hidden }
        if let began, now - began >= 15 {
            cancel()
            return .stopped("15초 안전 제한으로 효과를 해제했습니다. 덮개를 충분히 열면 다시 준비됩니다.")
        }
        if began == nil { began = now }
        return .visible
    }
}
