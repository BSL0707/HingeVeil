import Foundation
import IOKit.hid
import HingeVeilCore

struct SensorReading {
    var angle: Double?
    var updated: TimeInterval = 0
    var message: AppText = "센서 확인 중"
}

final class HingeSensor {
    private let queue = DispatchQueue(label: "HingeVeil.hinge", qos: .userInteractive)
    private let lock = NSLock()
    private var reading = SensorReading()
    private var timer: DispatchSourceTimer?
    private var manager: IOHIDManager?
    private var device: IOHIDDevice?
    private var element: IOHIDElement?
    private var retryAt: TimeInterval = 0

    func snapshot() -> SensorReading {
        lock.lock(); defer { lock.unlock() }
        return reading
    }

    func start() {
        queue.async { [weak self] in
            guard let self, self.timer == nil else { return }
            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now(), repeating: .milliseconds(200), leeway: .milliseconds(10))
            timer.setEventHandler { [weak self] in self?.poll() }
            self.timer = timer
            timer.resume()
        }
    }

    func reconnect() {
        queue.async { [weak self] in self?.disconnect(); self?.retryAt = 0 }
    }

    func setFast(_ fast: Bool) {
        queue.async { [weak self] in
            self?.timer?.schedule(deadline: .now(), repeating: .milliseconds(fast ? 20 : 200),
                                  leeway: .milliseconds(fast ? 2 : 10))
        }
    }

    func stop() {
        queue.sync {
            timer?.cancel(); timer = nil
            disconnect()
        }
    }

    private func publish(_ angle: Double?, _ message: AppText) {
        lock.lock(); defer { lock.unlock() }
        reading.message = message
        if let angle {
            reading.angle = angle
            reading.updated = ProcessInfo.processInfo.systemUptime
        }
    }

    private func disconnect() {
        if let manager { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }
        element = nil; device = nil; manager = nil
        lock.lock(); reading.angle = nil; reading.updated = 0; lock.unlock()
    }

    private func discover() {
        let candidate = IOHIDManagerCreate(kCFAllocatorDefault, 0)
        // Discover only orientation sensors, never keyboard/mouse devices.
        IOHIDManagerSetDeviceMatching(candidate, [
            kIOHIDDeviceUsagePageKey: 0x20,
            kIOHIDDeviceUsageKey: 0x8a
        ] as CFDictionary)
        let result = IOHIDManagerOpen(candidate, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess,
              let devices = IOHIDManagerCopyDevices(candidate) as? Set<IOHIDDevice> else {
            IOHIDManagerClose(candidate, 0)
            publish(nil, "덮개 센서를 열 수 없습니다 (\(result)).")
            return
        }
        for found in devices {
            guard let elements = IOHIDDeviceCopyMatchingElements(found, nil, 0) as? [IOHIDElement],
                  let tilt = elements.first(where: {
                      IOHIDElementGetUsagePage($0) == 0x20 &&
                      IOHIDElementGetUsage($0) == 0x047f &&
                      IOHIDElementGetReportID($0) == 1 &&
                      IOHIDElementGetLogicalMin($0) == 0 &&
                      IOHIDElementGetLogicalMax($0) == 360 &&
                      IOHIDElementGetReportSize($0) == 9
                  }) else { continue }
            manager = candidate; device = found; element = tilt
            publish(nil, "덮개 각도 센서 연결됨")
            return
        }
        IOHIDManagerClose(candidate, 0)
        publish(nil, "지원되는 덮개 센서를 찾지 못했습니다. 미리보기는 사용할 수 있습니다.")
    }

    private func poll() {
        let now = ProcessInfo.processInfo.systemUptime
        if device == nil {
            guard now >= retryAt else { return }
            retryAt = now + 3
            discover()
        }
        guard let device, let element else { return }
        let value = UnsafeMutablePointer<Unmanaged<IOHIDValue>>.allocate(capacity: 1)
        defer { value.deallocate() }
        // kIOHIDDeviceGetValueWithUpdate = 0x00020000 in IOHIDDevice.h.
        let result = IOHIDDeviceGetValueWithOptions(device, element, value, 0x00020000)
        if result == kIOReturnSuccess {
            let angle = IOHIDValueGetIntegerValue(value.pointee.takeUnretainedValue())
            if (0...360).contains(angle) {
                publish(Double(angle), "덮개 각도 센서 연결됨")
                return
            }
        }
        // Some sensor drivers expose the input report but not individual
        // synchronous values. This layout was checked against this machine's
        // descriptor above; unsupported descriptors are never guessed.
        var bytes = [UInt8](repeating: 0, count: 8)
        var count = bytes.count
        bytes[0] = 1
        let reportResult = IOHIDDeviceGetReport(device, kIOHIDReportTypeInput, 1, &bytes, &count)
        if reportResult == kIOReturnSuccess,
           let angle = HingeReport.angle(bytes: Array(bytes.prefix(count))) {
            publish(angle, "덮개 각도 센서 연결됨")
        } else if now - snapshot().updated > 1 {
            publish(nil, "센서 응답을 기다리고 있습니다.")
            disconnect()
        }
    }
}
