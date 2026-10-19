import AppKit
import MetalKit
import QuartzCore
import HingeVeilCore

private final class ClickToEscapeView: MTKView {
    var escape: (() -> Void)?
    override func mouseDown(with event: NSEvent) { escape?() }
    override func rightMouseDown(with event: NSEvent) { escape?() }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { escape?() }
    }
}

@MainActor
final class EffectWindow {
    private let panel: NSPanel
    private let view: ClickToEscapeView
    private let renderer: VeilRenderer
    private let stagingAlpha: CGFloat
    private var transitionVersion: UInt64 = 0
    private var transitionPhase = "hidden"
    private(set) var visible = false
    var onEscape: (() -> Void)?
    var onFailure: ((AppText) -> Void)? {
        didSet { renderer.onFailure = onFailure }
    }

    init(screen: NSScreen, mailbox: ScreenMailbox, stagingAlpha: CGFloat = 0) throws {
        self.stagingAlpha = stagingAlpha
        renderer = try VeilRenderer(mailbox: mailbox)
        panel = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false, screen: screen)
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isOpaque = true
        panel.backgroundColor = .black
        panel.hasShadow = false
        panel.sharingType = .none
        panel.alphaValue = 0
        view = ClickToEscapeView(frame: NSRect(origin: .zero, size: screen.frame.size), device: renderer.device)
        view.autoresizingMask = [.width, .height]
        renderer.configure(view)
        // Animate the veil at the panel's native refresh, independently of the
        // 50Hz integer sensor and 60Hz captured desktop frames.
        view.preferredFramesPerSecond = min(120, max(60, screen.maximumFramesPerSecond))
        view.isPaused = true
        panel.contentView = view
        view.escape = { [weak self] in self?.onEscape?() }
        renderer.onFirstPresentation = { [weak self] in
            guard let self, self.visible, self.transitionPhase == "waitingForFrame" else { return }
            self.fadeIn()
        }
    }

    func show(angle: Double, options: VeilOptions) {
        renderer.update(angle: angle, options: options, reset: !visible)
        if !visible {
            // Keep startup pixels hidden until a completed GPU frame is ready.
            panel.alphaValue = stagingAlpha
            visible = true
            transitionPhase = "waitingForFrame"
            panel.orderFrontRegardless()
            view.isPaused = false
            // Expose only after the first completed GPU frame, never an old
            // drawable or a black startup surface.
            view.draw()
        } else if transitionPhase == "fadingOut" {
            // Reverse from the current opacity and filtered angle. Invalidate
            // the old exit completion so it cannot hide the resumed effect.
            fadeIn()
        }
    }

    private func fadeIn() {
        transitionVersion &+= 1
        let version = transitionVersion
        transitionPhase = "fadingIn"
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = 1
        } completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self, self.transitionVersion == version, self.visible else { return }
                self.transitionPhase = "visible"
            }
        }
    }

    /// Only normal opening/test completion uses this path. Safety failures,
    /// clicking, disabling and sleep still call hide() for immediate removal.
    func finish(options: VeilOptions) {
        guard visible, transitionPhase != "fadingOut" else { return }
        renderer.update(angle: options.startAngle, options: options)
        transitionVersion &+= 1
        let version = transitionVersion
        transitionPhase = "fadingOut"
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.24
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self, self.transitionVersion == version, self.visible else { return }
                self.hide()
            }
        }
    }

    func hide() {
        transitionVersion &+= 1
        transitionPhase = "hidden"
        // Supersede any in-flight opacity animation, including its target.
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            panel.animator().alphaValue = 0
        }
        panel.orderOut(nil)
        panel.alphaValue = 0
        view.isPaused = true
        visible = false
    }

    func diagnostics() -> [String: Any] {
        var result = renderer.diagnostics()
        result["visible"] = visible
        result["transitionPhase"] = transitionPhase
        result["windowAlpha"] = panel.alphaValue
        result["windowNumber"] = panel.windowNumber
        result["windowOrdered"] = panel.isVisible
        result["requestedRefreshHz"] = view.preferredFramesPerSecond
        return result
    }
}
