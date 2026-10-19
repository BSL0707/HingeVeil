import AppKit
import Carbon
import Darwin

final class SafetyGuard {
    private var child: Process?
    private var heartbeat: FileHandle?

    func start() throws {
        guard child == nil, let executable = Bundle.main.executableURL else { return }
        signal(SIGPIPE, SIG_IGN)
        let process = Process()
        let pipe = Pipe()
        process.executableURL = executable
        process.arguments = ["--watch-parent", String(getpid())]
        process.standardInput = pipe
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        pipe.fileHandleForReading.closeFile()
        child = process; heartbeat = pipe.fileHandleForWriting
        beat(active: false)
    }
    var healthy: Bool { child?.isRunning == true }
    func beat(active: Bool) { try? heartbeat?.write(contentsOf: Data([active ? 1 : 0])) }
    func stop() {
        try? heartbeat?.close(); heartbeat = nil; child = nil
    }

    /// Separate process: a stalled main run loop cannot stall this watchdog.
    /// It accepts only its actual direct parent and never arbitrary processes.
    static func watch(parent: pid_t) -> Never {
        guard parent > 1, getppid() == parent else { exit(2) }
        let queue = DispatchQueue(label: "HingeVeil.guard")
        var active = false
        var last = ProcessInfo.processInfo.systemUptime
        let input = DispatchSource.makeReadSource(fileDescriptor: STDIN_FILENO, queue: queue)
        input.setEventHandler {
            var bytes = [UInt8](repeating: 0, count: 64)
            let count = read(STDIN_FILENO, &bytes, bytes.count)
            guard count > 0 else { exit(0) }
            active = bytes[count - 1] == 1
            last = ProcessInfo.processInfo.systemUptime
        }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 1, repeating: .milliseconds(250))
        timer.setEventHandler {
            guard getppid() == parent else { exit(0) }
            if active && ProcessInfo.processInfo.systemUptime - last > 3 {
                kill(parent, SIGTERM)
                queue.asyncAfter(deadline: .now() + 0.5) {
                    if getppid() == parent { kill(parent, SIGKILL) }
                    exit(0)
                }
                timer.cancel()
            }
        }
        input.resume(); timer.resume()
        dispatchMain()
    }
}

final class EscapeHotKey {
    private var hotkey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var action: (() -> Void)?

    func install() -> Bool {
        var specification = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let handlerResult = InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let object = Unmanaged<EscapeHotKey>.fromOpaque(context).takeUnretainedValue()
            object.action?()
            return noErr
        }, 1, &specification, context, &handler)
        guard handlerResult == noErr else { return false }
        let identifier = EventHotKeyID(signature: 0x48564549, id: 1)
        return RegisterEventHotKey(UInt32(kVK_Escape), UInt32(controlKey | optionKey | cmdKey),
            identifier, GetApplicationEventTarget(), 0, &hotkey) == noErr
    }
    deinit {
        if let hotkey { UnregisterEventHotKey(hotkey) }
        if let handler { RemoveEventHandler(handler) }
    }
}
