import Foundation
import Darwin
import Security
import HingeVeilCore

enum PermissionRecoveryLauncher {
    final class Session: @unchecked Sendable {
        let request: PermissionRecovery.Request
        private let child: Process
        private let input: FileHandle
        private var committed = false
        init(request: PermissionRecovery.Request, child: Process, input: FileHandle) {
            self.request = request; self.child = child; self.input = input
        }
        func commit() throws {
            guard !committed else { throw Failure.helper }
            try input.write(contentsOf: Data((PermissionRecovery.commit + "\n").utf8))
            committed = true
            try? input.close()
        }
        @discardableResult func cancel() -> Bool {
            guard !committed else { return false }
            try? input.close()
            if child.isRunning { child.terminate() }
            let end = ProcessInfo.processInfo.systemUptime + 2
            while child.isRunning && ProcessInfo.processInfo.systemUptime < end { Thread.sleep(forTimeInterval: 0.02) }
            return !child.isRunning
        }
        deinit { if !committed { _ = cancel() } }
    }
    /// Called only after the app's explicit confirmation. Does not reset here:
    /// the ready helper must first observe this parent exit normally.
    static func prepare(fixture: Bool = false) throws -> Session {
        let app = Bundle.main.bundleURL.resolvingSymlinksInPath()
        guard Bundle.main.bundleIdentifier == PermissionRecovery.bundleID,
              fixture || PermissionRecovery.installedLocation(app) else { throw Failure.location }
        let helper = app.appendingPathComponent("Contents/Helpers/HingeVeilRecovery")
        guard FileManager.default.isExecutableFile(atPath: helper.path) else { throw Failure.helper }
        for path in [app, helper] {
            var code: SecStaticCode?
            guard SecStaticCodeCreateWithPath(path as CFURL, [], &code) == errSecSuccess, let code,
                  SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures | kSecCSCheckNestedCode), nil) == errSecSuccess
            else { throw Failure.helper }
        }
        if !fixture { try PermissionRecovery.prepare(directory: PermissionRecovery.supportDirectory()) }
        let request = PermissionRecovery.Request()
        let child = Process(), input = Pipe(), output = Pipe()
        child.executableURL = helper
        child.arguments = [fixture ? "--fixture" : "--recover", String(getpid())]
        child.standardInput = input; child.standardOutput = output
        // Duplicate before spawn: using fd 1 directly would alias the child's
        // private READY pipe after stdout redirection, losing fixture results.
        var fixtureLog: FileHandle?
        if fixture {
            let descriptor = dup(STDOUT_FILENO)
            guard descriptor >= 0 else { throw Failure.helper }
            fixtureLog = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        }
        defer { try? fixtureLog?.close() }
        child.standardError = fixtureLog ?? FileHandle.nullDevice
        try child.run()
        input.fileHandleForReading.closeFile(); output.fileHandleForWriting.closeFile()
        defer { output.fileHandleForReading.closeFile() }
        var data = try JSONEncoder().encode(request); data.append(10)
        do { try input.fileHandleForWriting.write(contentsOf: data) }
        catch { input.fileHandleForWriting.closeFile(); child.terminate(); throw Failure.helper }
        guard let ready = PermissionRecovery.readLine(fd: output.fileHandleForReading.fileDescriptor, timeout: 4, limit: 128),
              String(data: ready, encoding: .utf8) == PermissionRecovery.ready else {
            if child.isRunning { child.terminate() }
            input.fileHandleForWriting.closeFile()
            throw Failure.helper
        }
        return Session(request: request, child: child, input: input.fileHandleForWriting)
    }

    enum Failure: Error { case location, helper }
}
