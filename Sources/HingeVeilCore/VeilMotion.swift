import Foundation

public struct VeilOptions: Equatable {
    public let startAngle: Double
    public let blurLevel: Int

    public init(startAngle: Double = 90, blurLevel: Int = 2) {
        self.startAngle = [85.0, 90, 95, 100].contains(startAngle) ? startAngle : 90
        self.blurLevel = min(4, max(1, blurLevel))
    }
}

/// A bounded counter-projection, separate from the moving soft aperture.
/// It approximates a stationary picture behind the closing lid, without
/// fitting the entire desktop back into the panel or unbounded inverse zoom.
/// This is a bounded visual preset, not eye-position tracking or physical lock.
public struct VeilProjection: Equatable {
    public let amount: Double
    public let motion: Double
    public let topInset: Double
    public let sideInset: Double
    public let blurPixels: Double
    public let feather: Double
    public let shade: Double
    public let counterCompression: Double
    public let counterDepth: Double

    public init(angle: Double, options: VeilOptions) {
        let range = options.startAngle - 15
        let p = angle.isFinite ? min(1, max(0, (options.startAngle - angle) / range)) : 0
        amount = p
        motion = p * p * (3 - 2 * p)
        // At most 9% of the top width and 2.5% of the height are masked,
        // not squeezed. The bottom hinge stays put; content is compensated
        // independently and is never fitted into this outline.
        topInset = 0.025 * motion
        sideInset = 0.045 * motion
        blurPixels = [12.0, 24, 36, 52][options.blurLevel - 1] * p
        feather = motion * (0.008 + Double(options.blurLevel) * 0.006)
        shade = 0.16 * p * p
        // Keep meaningful content motion through 30 -> 25 -> 20 degrees.
        // The former 2p-p² had spent 96% of its range by 30 degrees at the
        // default start. Reserve more travel for deep angles without adding
        // zoom. Preserve the first four-degree onset and ease to a zero slope
        // only in the last five degrees before the existing 15-degree limit.
        let closedDegrees = p * range
        var easedAmount = p * Self.smoothstep(0, 4, closedDegrees)
        let endEaseStart = 1 - 5 / range
        if p > endEaseStart {
            let t = (p - endEaseStart) / (1 - endEaseStart)
            easedAmount = endEaseStart + (1 - endEaseStart) * (t + t * t - t * t * t)
        }
        let compensation = easedAmount * (1.5 - 0.5 * easedAmount)
        // Preserve the 1.12 vertical gain cap and no horizontal enlargement.
        // No fit-to-box scale; out-of-source pixels must still be masked.
        let compressionLimit = 1 - 1 / 1.12
        counterCompression = compressionLimit * compensation
        counterDepth = 0.025 * compensation
    }

    /// Normalized top-left panel -> source coordinates. Do not clamp this
    /// result: that would repeat boundary pixels into stretched edge streaks.
    /// Both sharp and blurred layers use the same mapping; the hinge is fixed.
    public func sourcePoint(x: Double, y: Double) -> (x: Double, y: Double) {
        let height = 1 - y
        let denominator = 1 - counterDepth * height
        return (0.5 + (x - 0.5) / denominator,
                1 - (1 - counterCompression) * height / denominator)
    }

    /// CPU reference for GPU readback tests. A broad focus front travels
    /// downward through the middle, in addition to the stronger soft sides.
    public func blurMix(x: Double, y: Double) -> Double {
        let inset = sideInset * (1 - y) / (1 - topInset)
        let edgeDistance = max(0, min(x - inset, 1 - inset - x))
        let sideWeight = 1 - Self.smoothstep(0.025, 0.32, edgeDistance)
        let edgeMix = 1 - pow(1 - amount, 3)
        let focusFront = 0.9 * motion
        let frontWeight = 1 - Self.smoothstep(focusFront - 0.12, focusFront + 0.12, y)
        // Use the same smooth onset as the sides, but retain an edge-to-center
        // gradient. At 30% closure the center is ~35%, rather than ~13%.
        let middleMix = edgeMix * (0.45 + 0.35 * motion + 0.12 * frontWeight)
        // Preserve established middle/side haze above 72% of the panel.
        // Fade the lowest band smoothly; only 8% of that mix remains at the
        // hinge, including the corners. This is not a change to the four radii.
        let hingeClarity = 1 - 0.92 * Self.smoothstep(0.72, 0.98, y)
        return (middleMix + (edgeMix - middleMix) * sideWeight) * hingeClarity
    }

    public func shadeAt(y: Double) -> Double {
        shade * (0.5 + 0.9 * (1 - y))
    }

    private static func smoothstep(_ lower: Double, _ upper: Double, _ value: Double) -> Double {
        let t = min(1, max(0, (value - lower) / (upper - lower)))
        return t * t * (3 - 2 * t)
    }
}

public struct AngleFollower {
    public private(set) var angle: Double?
    private var velocity = 0.0
    public init() {}
    public mutating func reset() { angle = nil; velocity = 0 }

    /// Exact critically damped response for each elapsed interval. Carrying
    /// velocity smooths the one-degree sensor steps as well as position. This
    /// is non-oscillating and has approximately 90ms of tracking lag on a ramp.
    public mutating func advance(toward target: Double, seconds: Double) -> Double {
        guard target.isFinite else { return angle ?? 110 }
        guard let previous = angle else { angle = target; return target }
        let dt = min(0.1, max(0, seconds))
        let omega = 2 / 0.09
        let displacement = previous - target
        let decay = exp(-omega * dt)
        let impulse = (velocity + omega * displacement) * dt
        let next = target + (displacement + impulse) * decay
        velocity = (velocity - omega * impulse) * decay
        if abs(next - target) < 0.002 && abs(velocity) < 0.04 {
            angle = target; velocity = 0
        } else { angle = next }
        return angle!
    }
}

public enum HingeReport {
    /// This machine's own HID descriptor declares report 1 with a 9-bit,
    /// 0...360-degree Tilt X input. Reject other reports and malformed values.
    public static func angle(bytes: [UInt8]) -> Double? {
        guard bytes.count >= 3, bytes[0] == 1 else { return nil }
        let degrees = Int(bytes[1]) | (Int(bytes[2]) << 8)
        guard degrees <= 360 else { return nil }
        return Double(degrees)
    }
}
