import Foundation
import Darwin

/// A fixed-scope protocol: neither the app nor its helper accepts an arbitrary
/// permission service, client identifier, executable or shell command.
public enum PermissionRecovery {
    public static let bundleID = "com.bsl0707.hingeveil.preview"
    public static let resetArguments = ["reset", "ScreenCapture", bundleID]
    public static let pendingKey = "pendingScreenPermissionRecovery"
    public static let ready = "HINGEVEIL_RECOVERY_READY"
    public static let commit = "HINGEVEIL_RECOVERY_COMMIT"

    public struct Request: Codable, Equatable, Sendable {
        public var version = 1
        public let nonce: String
        public let createdAt: TimeInterval
        public init(nonce: String = UUID().uuidString, createdAt: TimeInterval = Date().timeIntervalSince1970) {
            self.nonce = nonce; self.createdAt = createdAt
        }
        public func isValid(now: TimeInterval) -> Bool {
            version == 1 && UUID(uuidString: nonce) != nil && now.isFinite && createdAt.isFinite
                && now >= createdAt - 5 && now - createdAt <= 60
        }
    }

    public struct Receipt: Codable, Equatable, Sendable {
        public let request: Request
        public let resetExitCode: Int32
        public let completedAt: TimeInterval
        public init(request: Request, resetExitCode: Int32, completedAt: TimeInterval = Date().timeIntervalSince1970) {
            self.request = request; self.resetExitCode = resetExitCode; self.completedAt = completedAt
        }
        public func matches(nonce: String, now: TimeInterval) -> Bool {
            request.version == 1 && request.nonce == nonce && UUID(uuidString: nonce) != nil
                && completedAt.isFinite && now.isFinite && now >= completedAt - 5 && now - completedAt <= 600
        }
    }

    public enum Result: Equatable { case aborted, reopened(resetSucceeded: Bool), receiptFailed, relaunchFailed }

    /// Backends are injected for tests. A live parent or invalid request can
    /// never reach reset. Relaunch on reset failure so the app can show help.
    public static func perform(request: Request, parentExited: Bool, now: TimeInterval,
                               reset: () -> Int32, save: (Receipt) throws -> Void,
                               relaunch: () -> Bool) -> Result {
        guard parentExited, request.isValid(now: now) else { return .aborted }
        let code = reset()
        do { try save(Receipt(request: request, resetExitCode: code, completedAt: now)) }
        catch { _ = relaunch(); return .receiptFailed }
        guard relaunch() else { return .relaunchFailed }
        return .reopened(resetSucceeded: code == 0)
    }

    public static func supportDirectory() throws -> URL {
        try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                    appropriateFor: nil, create: true).appendingPathComponent("HingeVeil", isDirectory: true)
    }

    public static func prepare(directory: URL) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true,
                                    attributes: [.posixPermissions: 0o700])
        let attributes = try manager.attributesOfItem(atPath: directory.path)
        guard attributes[.type] as? FileAttributeType == .typeDirectory,
              manager.isWritableFile(atPath: directory.path) else { throw CocoaError(.fileWriteNoPermission) }
    }

    public static func save(_ receipt: Receipt, directory: URL) throws {
        try prepare(directory: directory)
        let path = directory.appendingPathComponent("PermissionRecovery.json")
        if let attrs = try? FileManager.default.attributesOfItem(atPath: path.path),
           attrs[.type] as? FileAttributeType != .typeRegular { throw CocoaError(.fileWriteNoPermission) }
        try JSONEncoder().encode(receipt).write(to: path, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path.path)
    }

    public static func consume(nonce: String, directory: URL, now: TimeInterval = Date().timeIntervalSince1970) -> Receipt? {
        let path = directory.appendingPathComponent("PermissionRecovery.json")
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path.path),
              attrs[.type] as? FileAttributeType == .typeRegular,
              let size = attrs[.size] as? NSNumber, size.intValue <= 4096,
              let data = try? Data(contentsOf: path), let receipt = try? JSONDecoder().decode(Receipt.self, from: data),
              receipt.matches(nonce: nonce, now: now) else { return nil }
        try? FileManager.default.removeItem(at: path)
        return receipt
    }

    public static func installedLocation(_ app: URL) -> Bool {
        let resolved = app.resolvingSymlinksInPath().standardizedFileURL
        let roots = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask)
            + FileManager.default.urls(for: .applicationDirectory, in: .userDomainMask)
        return resolved.pathExtension == "app" && roots.contains {
            resolved.path.hasPrefix($0.resolvingSymlinksInPath().standardizedFileURL.path + "/")
        }
    }

    /// Bounded one-line private-pipe messages, never command arguments.
    public static func readLine(fd: Int32, timeout: TimeInterval, limit: Int = 4096) -> Data? {
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        var data = Data()
        while data.count < limit {
            let remaining = deadline - ProcessInfo.processInfo.systemUptime
            guard remaining > 0 else { return nil }
            var descriptor = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            guard poll(&descriptor, 1, Int32(min(remaining * 1000, 1000))) >= 0 else { return nil }
            if descriptor.revents == 0 { continue }
            var byte: UInt8 = 0
            guard read(fd, &byte, 1) == 1 else { return nil }
            if byte == 10 { return data }
            data.append(byte)
        }
        return nil
    }
}
