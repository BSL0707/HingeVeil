import AppKit
import Combine
import HingeVeilCore

@MainActor
final class AppController: ObservableObject {
    @Published private(set) var enabled = false
    @Published private(set) var sensorText: AppText = "센서 확인 중"
    @Published private(set) var status: AppText = "화면 권한을 허용한 뒤 효과를 켜세요."
    @Published var language = L10n.selectedLanguage {
        didSet {
            if !isReviewMode { UserDefaults.standard.set(language.rawValue, forKey: L10n.preferenceKey) }
            onLanguageChange?()
        }
    }
    let isReviewMode: Bool
    var onLanguageChange: (() -> Void)?
    @Published private(set) var angle: Double?
    @Published private(set) var permissionState = ScreenPermissionState()
    var permission: Bool { permissionState.isGranted }
    @Published var startAngle: Double {
        didSet {
            if !isReviewMode { UserDefaults.standard.set(startAngle, forKey: "startAngle") }
            emergency("시작 각도를 변경했습니다.")
        }
    }
    @Published var blurLevel: Int {
        didSet { if !isReviewMode { UserDefaults.standard.set(blurLevel, forKey: "blurLevel") } }
    }
    @Published var previewAngle = 90.0
    let sensor = HingeSensor()
    private let capture = DesktopCapture()
    private let guardProcess = SafetyGuard()
    private let hotkey = EscapeHotKey()
    private var effect: EffectWindow?
    private var gate = EffectGate()
    private var timer: Timer?
    private var captureTask: Task<Void, Never>?
    private var observers = [NSObjectProtocol]()
    private var testBegan: TimeInterval?
    private var wasVisible = false
    private var heartbeatTime: TimeInterval = 0
    private var lastStatusTime: TimeInterval = 0
    private var suspended = false
    private var safetyReady = false
    private var diagnosticTime: TimeInterval = 0
    private var lastPermissionCheck: TimeInterval = 0

    var options: VeilOptions { VeilOptions(startAngle: startAngle, blurLevel: blurLevel) }

    init(reviewLanguage: AppLanguage? = nil) {
        isReviewMode = reviewLanguage != nil
        language = reviewLanguage ?? L10n.selectedLanguage
        let savedStart = UserDefaults.standard.double(forKey: "startAngle")
        let savedBlur = UserDefaults.standard.integer(forKey: "blurLevel")
        startAngle = VeilOptions(startAngle: savedStart == 0 ? 90 : savedStart).startAngle
        blurLevel = savedBlur == 0 ? 2 : VeilOptions(blurLevel: savedBlur).blurLevel
        if isReviewMode { status = "화면 캡처 없는 UI 검토 모드 · 실제 효과는 시작하지 않습니다." }
        capture.onFailure = { [weak self] message in
            self?.emergency(message)
            self?.enabled = false
        }
    }

    func start() {
        guard !isReviewMode else { return }
        refreshPermission()
        do {
            try guardProcess.start()
            safetyReady = hotkey.install() && guardProcess.healthy
            if !safetyReady { status = "안전 종료 기능을 준비하지 못했습니다. 앱을 다시 열어주세요." }
        } catch { status = "안전 감시 실행 실패: \(error.localizedDescription)" }
        hotkey.action = { [weak self] in
            MainActor.assumeIsolated { self?.emergency("긴급 단축키로 효과를 해제했습니다.") }
        }
        sensor.start()
        timer = Timer(timeInterval: 1 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification,
                     NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.sleep() }
            })
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.sessionDidBecomeActiveNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.wake() }
            })
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.rebuildDisplay() }
            })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification,
            object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { _ = self?.refreshPermission() }
            })
        if UserDefaults.standard.bool(forKey: "effectEnabled") {
            if permission { setEnabled(true) }
            else { status = permissionState.guidance }
        } else if permission {
            status = "화면 권한이 확인됐습니다. ‘실제 덮개 효과’를 켜세요."
        }
    }

    @discardableResult
    func refreshPermission(announce: Bool = false) -> Bool {
        guard !isReviewMode, !permissionState.requestInFlight else { return permission }
        lastPermissionCheck = ProcessInfo.processInfo.systemUptime
        let previouslyGranted = permission
        var next = permissionState
        next.observe(granted: CGPreflightScreenCaptureAccess())
        if next != permissionState { permissionState = next }
        if previouslyGranted && !permission {
            enabled = false
            UserDefaults.standard.set(false, forKey: "effectEnabled")
            sensor.setFast(false)
            captureTask?.cancel()
            captureTask = Task { await capture.stop() }
            emergency("화면 권한이 확인되지 않아 캡처와 효과를 중지했습니다. 설정에서 권한을 확인하세요.")
        } else if permission && !enabled && (!previouslyGranted || announce) {
            status = "권한이 확인됐습니다. 효과를 켤 수 있습니다."
        } else if !permission && announce { status = permissionState.guidance }
        return permission
    }

    func requestPermission() {
        guard !isReviewMode else { return }
        if refreshPermission(announce: true) { return }
        guard permissionState.beginRequest() else { status = permissionState.guidance; return }
        let granted = CGRequestScreenCaptureAccess()
        permissionState.completeRequest(granted: granted || CGPreflightScreenCaptureAccess())
        status = permissionState.guidance
    }

    func openPermissionSettings() {
        guard !isReviewMode, let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        if !NSWorkspace.shared.open(url) { status = "설정 화면을 열지 못했습니다. 시스템 설정에서 화면 녹화 권한을 직접 확인하세요." }
    }

    func quitForPermissionRestart() {
        guard !isReviewMode else { return }
        let alert = NSAlert()
        alert.messageText = L10n.text("권한 적용을 위해 앱 종료", language: language)
        alert.informativeText = L10n.text("HingeVeil을 종료한 뒤 응용 프로그램 폴더에서 다시 여세요. 창만 닫는 것은 종료가 아닙니다. 시스템 권한은 변경하지 않습니다.", language: language)
        alert.addButton(withTitle: L10n.text("종료", language: language))
        alert.addButton(withTitle: L10n.text("취소", language: language))
        if alert.runModal() == .alertFirstButtonReturn { NSApp.terminate(nil) }
    }

    func setEnabled(_ value: Bool) {
        guard !isReviewMode else { return }
        if !value {
            UserDefaults.standard.set(false, forKey: "effectEnabled")
            enabled = false
            sensor.setFast(false)
            emergency("효과가 꺼져 있습니다.")
            captureTask?.cancel()
            captureTask = Task { await capture.stop() }
            return
        }
        guard safetyReady else { status = "안전 종료 기능이 준비되지 않아 효과를 켤 수 없습니다."; return }
        if NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == "com.lqsky7.mactilt" }) {
            status = "기존 macTilt가 실행 중입니다. 기존 앱을 종료한 뒤 HingeVeil을 켜주세요."
            return
        }
        guard refreshPermission(announce: true) else { return }
        enabled = true
        UserDefaults.standard.set(true, forKey: "effectEnabled")
        sensor.setFast(true)
        gate.cancel()
        status = "화면 연결 중입니다. 덮개를 시작 각도보다 3도 이상 열어 준비하세요."
        prepareCapture()
    }

    func runTest() {
        guard !isReviewMode else { return }
        guard safetyReady else { status = "안전 종료 기능을 먼저 확인해주세요."; return }
        guard refreshPermission(announce: true) else { return }
        sensor.setFast(true)
        captureTask?.cancel()
        captureTask = Task { [weak self] in
            guard let self else { return }
            do {
                if !capture.running { try await connectDisplay() }
                let deadline = ProcessInfo.processInfo.systemUptime + 3
                while capture.mailbox.snapshot().frame == nil {
                    try Task.checkCancellation()
                    guard ProcessInfo.processInfo.systemUptime < deadline else { throw TestFailure.noFrame }
                    try await Task.sleep(for: .milliseconds(50))
                }
                try Task.checkCancellation()
                testBegan = ProcessInfo.processInfo.systemUptime
                status = "30% 접힘 테스트: 2초 후 자동 복귀합니다."
            } catch is CancellationError {} catch { emergency(AppText(error.localizedDescription)) }
        }
    }

    func emergency(_ message: AppText = "효과를 해제했습니다. 덮개를 충분히 열면 다시 준비됩니다.") {
        testBegan = nil
        gate.cancel()
        effect?.hide()
        guardProcess.beat(active: false)
        if !enabled { sensor.setFast(false) }
        status = message
    }

    func shutdown() {
        enabled = false; emergency()
        timer?.invalidate(); timer = nil
        captureTask?.cancel()
        sensor.stop()
        guardProcess.stop()
        for observer in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func prepareCapture() {
        captureTask?.cancel()
        captureTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await connectDisplay()
                status = "화면 연결 완료 · 덮개를 \(Int(startAngle + 3))° 이상 열어 준비한 뒤 내리세요."
            }
            catch is CancellationError {} catch {
                enabled = false
                emergency("화면 연결 실패: \(error.localizedDescription)")
            }
        }
    }

    private func connectDisplay() async throws {
        guard let screen = NSScreen.screens.first(where: {
            guard let id = $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 else { return false }
            return CGDisplayIsBuiltin(id) != 0
        }), let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 else {
            throw DesktopCapture.CaptureFailure.displayMissing
        }
        effect?.hide()
        let candidate = try EffectWindow(screen: screen, mailbox: capture.mailbox)
        candidate.onEscape = { [weak self] in self?.emergency("화면 클릭으로 효과를 해제했습니다.") }
        candidate.onFailure = { [weak self] message in self?.emergency(message) }
        effect = candidate
        try await capture.start(displayID: id)
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        // Read-only, at most once per second while the app is foreground.
        // Never poll the permission-request API from the rendering loop.
        if NSApp.isActive && now - lastPermissionCheck >= 1 { refreshPermission() }
        let reading = sensor.snapshot()
        if now - lastStatusTime >= 0.15 {
            angle = reading.angle; sensorText = reading.message
            lastStatusTime = now
        }
        let screen = capture.mailbox.snapshot()
        let freshCapture = screen.frame != nil && now - screen.lastDelivery < 1
        if !guardProcess.healthy && effect?.visible == true {
            emergency("안전 감시가 중단되어 효과를 해제했습니다.")
            enabled = false
        }
        if let began = testBegan {
            if !freshCapture || suspended {
                emergency("테스트가 끝났습니다.")
                if !enabled { Task { await capture.stop() } }
            } else if now - began >= 2 {
                testBegan = nil
                gate.cancel()
                effect?.finish(options: options)
                if !enabled { sensor.setFast(false) }
                status = "테스트가 끝났습니다."
            } else {
                guardProcess.beat(active: true)
                effect?.show(angle: startAngle - (startAngle - 15) * 0.30, options: options)
            }
        } else if enabled && !suspended, let angle = reading.angle {
            switch gate.evaluate(now: now, angle: angle, startAngle: startAngle,
                sensorFresh: now - reading.updated < 0.6, captureFresh: freshCapture) {
            case .visible:
                guardProcess.beat(active: true)
                effect?.show(angle: angle, options: options)
                if !wasVisible { status = "효과 작동 중 · 클릭 또는 ⌃⌥⌘Esc로 해제" }
            case .hidden:
                effect?.finish(options: options)
                if wasVisible && status != "효과 준비 완료 · 덮개를 내리면 작동합니다." {
                    status = "효과 준비 완료 · 덮개를 내리면 작동합니다."
                }
            case .stopped(let reason): emergency(AppText(reason))
            }
        } else if enabled && !suspended && effect?.visible == true {
            emergency("센서 값을 확인하지 못해 효과를 해제했습니다.")
        } else { effect?.finish(options: options) }
        let visible = effect?.visible == true
        if visible != wasVisible {
            Task {
                await capture.setMoving(visible)
                if !visible && !enabled && testBegan == nil { await capture.stop() }
            }
            wasVisible = visible
        }
        if now - heartbeatTime >= 0.25 {
            guardProcess.beat(active: visible)
            heartbeatTime = now
        }
        if now - diagnosticTime >= 0.25,
           let index = CommandLine.arguments.firstIndex(of: "--diagnostics"),
           index + 1 < CommandLine.arguments.count {
            var data: [String: Any] = ["enabled": enabled, "suspended": suspended,
                "captureRunning": capture.running, "captureFresh": freshCapture,
                "frameSequence": screen.frame?.sequence ?? 0, "status": status.localized(in: language),
                "sensorAngle": reading.angle ?? -1, "sensorFresh": now - reading.updated < 0.6,
                "testActive": testBegan != nil, "needsOpen": gate.needsOpen]
            data["overlay"] = effect?.diagnostics() ?? [:]
            data["screenPermissionGranted"] = permission
            data["permissionRequestAttempted"] = permissionState.requestAttempted
            if let json = try? JSONSerialization.data(withJSONObject: data, options: [.sortedKeys]) {
                try? json.write(to: URL(fileURLWithPath: CommandLine.arguments[index + 1]), options: .atomic)
            }
            diagnosticTime = now
        }
    }

    private func sleep() {
        suspended = true
        sensor.setFast(false)
        emergency("잠자기 중에는 효과를 멈춥니다. 잠금 해제 후 다시 준비됩니다.")
        captureTask?.cancel()
        captureTask = Task { await capture.stop() }
    }
    private func wake() {
        guard suspended else { return }
        suspended = false
        sensor.setFast(enabled)
        sensor.reconnect()
        gate.cancel()
        if enabled { prepareCapture() }
    }
    private func rebuildDisplay() {
        emergency("화면 구성이 바뀌어 다시 연결합니다.")
        if enabled && !suspended { prepareCapture() }
    }

    enum TestFailure: LocalizedError {
        case noFrame
        var errorDescription: String? { L10n.text("화면의 첫 프레임을 받지 못했습니다. 화면 권한과 잠금 해제 상태를 확인해주세요.") }
    }
}
