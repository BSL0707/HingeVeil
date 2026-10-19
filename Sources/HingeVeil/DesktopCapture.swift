import AppKit
import CoreMedia
import CoreVideo
import ScreenCaptureKit
import HingeVeilCore

// All mutable storage is protected by lock; CVPixelBuffers are retained and
// consumed read-only by the GPU after publication.
final class ScreenMailbox: @unchecked Sendable {
    struct Frame {
        let buffer: CVPixelBuffer
        let sequence: UInt64
    }
    private let lock = NSLock()
    private var frame: Frame?
    private var delivery: TimeInterval = 0
    private var sequence: UInt64 = 0

    func accept(_ buffer: CVPixelBuffer?) {
        lock.lock(); defer { lock.unlock() }
        delivery = ProcessInfo.processInfo.systemUptime
        if let buffer { sequence &+= 1; frame = Frame(buffer: buffer, sequence: sequence) }
    }
    func snapshot() -> (frame: Frame?, lastDelivery: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        return (frame, delivery)
    }
    func clear() {
        lock.lock(); defer { lock.unlock() }
        frame = nil; delivery = 0
    }
}

@MainActor
final class DesktopCapture: NSObject, SCStreamOutput, SCStreamDelegate {
    nonisolated let mailbox = ScreenMailbox()
    private let samples = DispatchQueue(label: "HingeVeil.screen", qos: .userInteractive)
    private var stream: SCStream?
    private var configuration: SCStreamConfiguration?
    private var generation = 0
    private(set) var running = false
    var onFailure: ((AppText) -> Void)?

    func start(displayID: CGDirectDisplayID) async throws {
        await stop()
        try Task.checkCancellation()
        let token = generation
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        try Task.checkCancellation()
        guard token == generation else { throw CancellationError() }
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw CaptureFailure.displayMissing
        }
        let ownApplications = content.applications.filter { $0.processID == getpid() }
        let filter = SCContentFilter(display: display, excludingApplications: ownApplications, exceptingWindows: [])
        let config = SCStreamConfiguration()
        let nativeWidth = Double(CGDisplayPixelsWide(displayID))
        let nativeHeight = Double(CGDisplayPixelsHigh(displayID))
        let scale = min(1, 2560 / max(1, nativeWidth))
        config.width = max(2, Int(nativeWidth * scale) / 2 * 2)
        config.height = max(2, Int(nativeHeight * scale) / 2 * 2)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.queueDepth = 3
        config.minimumFrameInterval = CMTime(value: 1, timescale: 15)
        config.showsCursor = true
        config.capturesAudio = false
        config.preservesAspectRatio = true
        if #available(macOS 15, *) { config.captureMicrophone = false }
        let candidate = SCStream(filter: filter, configuration: config, delegate: self)
        try candidate.addStreamOutput(self, type: .screen, sampleHandlerQueue: samples)
        stream = candidate; configuration = config
        do {
            try await candidate.startCapture()
            guard token == generation else {
                try? await candidate.stopCapture()
                throw CancellationError()
            }
            running = true
        } catch {
            if token == generation { stream = nil; configuration = nil; running = false; mailbox.clear() }
            throw error
        }
    }

    func setMoving(_ moving: Bool) async {
        guard let stream, let configuration else { return }
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: moving ? 60 : 15)
        do { try await stream.updateConfiguration(configuration) }
        catch { if self.stream === stream { onFailure?("화면 갱신 설정 실패: \(error.localizedDescription)") } }
    }

    func stop() async {
        generation += 1
        let previous = stream
        stream = nil; configuration = nil; running = false
        mailbox.clear()
        try? await previous?.stopCapture()
        // A previous callback may have been in flight when the stream stopped.
        await withCheckedContinuation { continuation in
            samples.async { [mailbox] in mailbox.clear(); continuation.resume() }
        }
    }

    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                            of outputType: SCStreamOutputType) {
        guard outputType == .screen, CMSampleBufferIsValid(sampleBuffer),
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)
                as? [[SCStreamFrameInfo: Any]],
              let rawStatus = attachments.first?[.status] as? Int,
              let status = SCFrameStatus(rawValue: rawStatus) else { return }
        if status == .complete {
            mailbox.accept(CMSampleBufferGetImageBuffer(sampleBuffer))
        } else if status == .idle {
            mailbox.accept(nil)
        }
    }

    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let self, self.stream === stream else { return }
            self.running = false
            self.mailbox.clear()
            self.onFailure?("화면 공유가 중단되었습니다: \(error.localizedDescription)")
        }
    }

    enum CaptureFailure: LocalizedError {
        case displayMissing
        var errorDescription: String? { L10n.text("내장 화면을 찾지 못했습니다.") }
    }
}
