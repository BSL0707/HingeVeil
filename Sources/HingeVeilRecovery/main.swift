import AppKit
import Foundation
import Security
import Darwin
import HingeVeilCore

// Embedded, non-privileged, one-shot helper. Never installed as a daemon.
let args = CommandLine.arguments
let fixture = args.count == 3 && args[1] == "--fixture"
guard args.count == 3, fixture || args[1] == "--recover", let parent = Int32(args[2]),
      parent > 1, getppid() == parent else { exit(2) }
let helper = URL(fileURLWithPath: args[0]).resolvingSymlinksInPath()
let app = helper.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
guard helper.lastPathComponent == "HingeVeilRecovery", helper.deletingLastPathComponent().lastPathComponent == "Helpers",
      Bundle(url: app)?.bundleIdentifier == PermissionRecovery.bundleID,
      fixture || PermissionRecovery.installedLocation(app) else { exit(2) }

// Bind the handshake to the signed main executable at this exact app path.
var guest: SecCode?
var parentCode: SecStaticCode?
var appCode: SecStaticCode?
var requirement: SecRequirement?
var parentPath: CFURL?
guard SecCodeCopyGuestWithAttributes(nil, [kSecGuestAttributePid: parent] as CFDictionary, [], &guest) == errSecSuccess,
      let guest, SecCodeCopyStaticCode(guest, [], &parentCode) == errSecSuccess, let parentCode,
      SecCodeCopyPath(parentCode, [], &parentPath) == errSecSuccess,
      (parentPath as URL?)?.resolvingSymlinksInPath() == app,
      SecStaticCodeCreateWithPath(app as CFURL, [], &appCode) == errSecSuccess, let appCode,
      SecCodeCopyDesignatedRequirement(appCode, [], &requirement) == errSecSuccess, let requirement,
      SecCodeCheckValidity(guest, [], requirement) == errSecSuccess,
      let data = PermissionRecovery.readLine(fd: STDIN_FILENO, timeout: 3),
      let request = try? JSONDecoder().decode(PermissionRecovery.Request.self, from: data),
      request.isValid(now: Date().timeIntervalSince1970) else { exit(2) }
do { try FileHandle.standardOutput.write(contentsOf: Data((PermissionRecovery.ready + "\n").utf8)) }
catch { exit(2) }
guard let commit = PermissionRecovery.readLine(fd: STDIN_FILENO, timeout: 8, limit: 128),
      String(data: commit, encoding: .utf8) == PermissionRecovery.commit else {
    if fixture { try? FileHandle.standardError.write(contentsOf: Data("Recovery fixture: no valid commit; no actions\n".utf8)) }
    exit(2)
}
if fixture { try? FileHandle.standardError.write(contentsOf: Data("Recovery fixture: commit received; waiting for parent exit\n".utf8)) }

let deadline = ProcessInfo.processInfo.systemUptime + 10
while kill(parent, 0) == 0 && ProcessInfo.processInfo.systemUptime < deadline { Thread.sleep(forTimeInterval: 0.05) }
let parentExited = kill(parent, 0) != 0 && errno == ESRCH

func run(_ executable: String, arguments: [String], timeout: TimeInterval) -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
    do { try process.run() } catch { return -1 }
    let end = ProcessInfo.processInfo.systemUptime + timeout
    while process.isRunning && ProcessInfo.processInfo.systemUptime < end { Thread.sleep(forTimeInterval: 0.05) }
    if process.isRunning {
        process.terminate(); Thread.sleep(forTimeInterval: 0.2)
        if process.isRunning { kill(process.processIdentifier, SIGKILL) } // Our own bounded command only.
        process.waitUntilExit(); return -2
    }
    return process.terminationReason == .exit ? process.terminationStatus : -3
}

if fixture {
    // Same pipe/identity/parent-exit protocol, but NO reset, receipt IO, launch
    // or preference writes. This diagnostic cannot select the live backend.
    var resetCount = 0, relaunchCount = 0
    let result = PermissionRecovery.perform(request: request, parentExited: parentExited,
        now: Date().timeIntervalSince1970,
        reset: { resetCount += 1; return 0 }, save: { _ in }, relaunch: { relaunchCount += 1; return true })
    let passed = result == .reopened(resetSucceeded: true) && resetCount == 1 && relaunchCount == 1
    let message = "Recovery process fixture: passed=\(passed), parentExited=\(parentExited), mockReset=\(resetCount), mockRelaunch=\(relaunchCount); NO OS permission changes\n"
    try? FileHandle.standardError.write(contentsOf: Data(message.utf8))
    exit(passed ? 0 : 1)
}

let result = PermissionRecovery.perform(request: request, parentExited: parentExited,
    now: Date().timeIntervalSince1970,
    reset: { run("/usr/bin/tccutil", arguments: PermissionRecovery.resetArguments, timeout: 15) },
    save: { try PermissionRecovery.save($0, directory: PermissionRecovery.supportDirectory()) },
    relaunch: { run("/usr/bin/open", arguments: ["-n", app.path, "--args", "--permission-recovery-completed"], timeout: 8) == 0 })
exit(result == .reopened(resetSucceeded: true) ? 0 : 1)
