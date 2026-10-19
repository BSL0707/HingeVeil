import AppKit
import SwiftUI
import Darwin
import HingeVeilCore

@MainActor
final class VeilAppDelegate: NSObject, NSApplicationDelegate {
    private var controller: AppController?
    private var window: NSWindow?
    private var statusItem: NSStatusItem?
    private let reviewLanguage: AppLanguage?
    private let reviewManual: Bool

    init(reviewLanguage: AppLanguage? = nil, reviewManual: Bool = false) {
        self.reviewLanguage = reviewLanguage; self.reviewManual = reviewManual
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let controller = AppController(reviewLanguage: reviewLanguage)
        self.controller = controller
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 790),
            styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = L10n.text("HingeVeil · 힌지베일", language: controller.language)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsView(controller: controller, showManual: reviewManual))
        window.center()
        self.window = window
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menuLogo = IconArtwork.image(size: 18)
        menuLogo.isTemplate = false // Preserve the app logo's mint/blue colors.
        menuLogo.accessibilityDescription = L10n.text("HingeVeil · 힌지베일", language: controller.language)
        item.button?.image = menuLogo
        item.button?.imageScaling = .scaleProportionallyDown
        statusItem = item
        controller.onLanguageChange = { [weak self] in self?.refreshLanguage() }
        refreshLanguage()
        controller.start()
        showSettings()
    }

    private func refreshLanguage() {
        guard let controller else { return }
        window?.title = L10n.text("HingeVeil · 힌지베일", language: controller.language)
        statusItem?.button?.image?.accessibilityDescription = window?.title
        let menu = NSMenu()
        for (title, selector, key) in [
            ("HingeVeil 설정…", #selector(showSettings), ","),
            ("효과 즉시 해제", #selector(escapeEffect), ""),
            ("30% 접힘 테스트 · 2초", #selector(testEffect), ""),
            ("HingeVeil 종료", #selector(quit), "q")
        ] {
            let entry = NSMenuItem(title: L10n.text(title, language: controller.language), action: selector, keyEquivalent: key)
            entry.target = self; menu.addItem(entry)
        }
        statusItem?.menu = menu
    }
    @objc func showSettings() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
    @objc func escapeEffect() { controller?.emergency() }
    @objc func testEffect() { controller?.runTest() }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings(); return true
    }
    func applicationWillTerminate(_ notification: Notification) { controller?.shutdown() }
}

let arguments = CommandLine.arguments
if arguments.count >= 3 && arguments[1] == "--watch-parent", let pid = Int32(arguments[2]) {
    SafetyGuard.watch(parent: pid)
} else if arguments.contains("--check-localizations") {
    let en = L10n.catalog(for: .english), ko = L10n.catalog(for: .korean)
    let passed = en.count >= 72 && Set(en.keys) == Set(ko.keys)
        && !L10n.manual(language: .english).isEmpty && !L10n.manual(language: .korean).isEmpty
    print("Localization resources: en=\(en.count), ko=\(ko.count), passed=\(passed)")
    exit(passed ? 0 : 1)
} else if arguments.contains("--review-ui") {
    MainActor.assumeIsolated {
        let language: AppLanguage
        if let index = arguments.firstIndex(of: "--language"), index + 1 < arguments.count {
            language = AppLanguage(rawValue: arguments[index + 1]) ?? .english
        } else { language = .english }
        let application = NSApplication.shared
        let delegate = VeilAppDelegate(reviewLanguage: language, reviewManual: arguments.contains("--review-manual"))
        application.delegate = delegate
        // Inspection only: no capture, sensor, watchdog, hotkey or preference writes.
        // Independent of a modal sheet/menu run-loop mode. This fixture starts
        // no capture or settings writes, so process exit is safe and bounded.
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 45) { exit(0) }
        withExtendedLifetime(delegate) { application.run() }
    }
} else if arguments.contains("--check-window") || arguments.contains("--check-transitions") {
    MainActor.assumeIsolated {
        WindowCheck.run(stagingAlpha: arguments.contains("--zero-alpha") ? 0 : 0.01,
                        animated: arguments.contains("--animate"), patterned: arguments.contains("--pattern"),
                        transitions: arguments.contains("--check-transitions"))
    }
} else if arguments.contains("--guard-fixture") {
    // A disposable child fixture only; it does not create windows or capture.
    do {
        let watcher = SafetyGuard()
        try watcher.start()
        watcher.beat(active: true)
        Thread.sleep(forTimeInterval: 6)
        watcher.stop()
        exit(1)
    } catch { exit(2) }
} else if arguments.contains("--check-guard") {
    let child = Process()
    child.executableURL = Bundle.main.executableURL
    child.arguments = ["--guard-fixture"]
    do {
        let began = ProcessInfo.processInfo.systemUptime
        try child.run(); child.waitUntilExit()
        guard child.terminationReason == .uncaughtSignal,
              [SIGTERM, SIGKILL].contains(child.terminationStatus) else {
            fputs("안전 감시 검증 실패\n", stderr); exit(1)
        }
        print("안전 감시 검증 통과: 시험용 자식 앱을 \(String(format: "%.2f", ProcessInfo.processInfo.systemUptime - began))초 뒤 종료했습니다.")
    } catch { fputs("안전 감시 검증 실패: \(error)\n", stderr); exit(1) }
} else if arguments.contains("--probe-sensor") {
    let sensor = HingeSensor()
    sensor.start()
    RunLoop.current.run(until: Date().addingTimeInterval(1))
    let reading = sensor.snapshot()
    print(reading.message.localized())
    if let angle = reading.angle { print("각도: \(angle)°") }
    sensor.stop()
    exit(reading.angle == nil ? 1 : 0)
} else if arguments.contains("--self-check") {
    do {
        let previewArtwork = arguments.contains("--preview-artwork")
        let renderer = try VeilRenderer(previewArtwork: previewArtwork)
        let directory = arguments.contains("--previews") ? URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Previews") : nil
        print(try previewArtwork ? renderer.previewCheck(directory: directory) : renderer.selfCheck(directory: directory))
    } catch { fputs("GPU 검증 실패: \(error.localizedDescription)\n", stderr); exit(1) }
} else if arguments.count == 3 && arguments[1] == "--make-icon" {
    do { try IconArtwork.exportIconset(to: URL(fileURLWithPath: arguments[2])) }
    catch { fputs("아이콘 생성 실패: \(error)\n", stderr); exit(1) }
} else {
    MainActor.assumeIsolated {
        // Copies with the same bundle identity must not compete for capture,
        // the sensor, or the emergency shortcut. Diagnostic fixtures above do
        // not start the normal controller and remain intentionally separate.
        if let identity = Bundle.main.bundleIdentifier,
           let existing = NSWorkspace.shared.runningApplications
            .filter({ $0.bundleIdentifier == identity && $0.processIdentifier != getpid() })
            .sorted(by: { ($0.launchDate ?? .distantFuture) < ($1.launchDate ?? .distantFuture) }).first {
            existing.activate(options: [.activateAllWindows])
            fputs("HingeVeil이 이미 실행 중입니다. 중복 실행본은 시작하지 않습니다.\n", stderr)
            exit(0)
        }
        let application = NSApplication.shared
        let delegate = VeilAppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}
