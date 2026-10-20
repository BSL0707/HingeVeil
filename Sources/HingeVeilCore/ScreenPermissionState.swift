/// Pure permission UX policy. Only the application may supply an OS result;
/// user intent or a successful button press can never grant permission.
public struct ScreenPermissionState: Equatable, Sendable {
    public private(set) var isGranted = false
    public private(set) var requestAttempted = false
    public private(set) var requestInFlight = false

    public init() {}

    public var canRequest: Bool { !isGranted && !requestAttempted && !requestInFlight }

    public var guidance: AppText {
        if isGranted { return "권한이 확인됐습니다. 효과를 켤 수 있습니다." }
        if requestAttempted {
            return "시스템 설정에서 허용한 뒤 ‘권한 다시 확인’을 누르세요. 계속 미확인이면 앱을 종료하고 응용 프로그램에서 다시 여세요."
        }
        return "‘화면 권한 요청’을 한 번 누르고 시스템 설정에서 HingeVeil을 허용하세요. 이미 허용했다면 ‘권한 다시 확인’ 또는 ‘권한·재시작 도움말’을 사용하세요."
    }

    public mutating func observe(granted: Bool) {
        guard !requestInFlight else { return }
        isGranted = granted
    }

    /// A system prompt is allowed only once per app process and only after an
    /// explicit request-button action. Rechecks do not reset this latch.
    public mutating func beginRequest() -> Bool {
        guard canRequest else { return false }
        requestAttempted = true
        requestInFlight = true
        return true
    }

    public mutating func completeRequest(granted: Bool) {
        guard requestInFlight else { return }
        requestInFlight = false
        isGranted = granted
    }
}
