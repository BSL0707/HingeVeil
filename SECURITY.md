# Security and privacy / 보안·개인정보

## Current source behavior

- ScreenCaptureKit frames are passed through an in-memory mailbox to Metal.
- Only the screen stream output is registered. Audio capture is false; microphone capture is false on supported macOS versions.
- The source includes no URLSession/NWConnection/URLRequest client, recording writer, telemetry service, account, payment or license activation service.
- While the live feature is enabled, a local capture connection is intentionally kept ready. macOS may retain its sharing indicator. Dismissing one overlay does not disable the feature or stop its capture session.
- Switching Live lid effect OFF or quitting stops the session. Frames are not written to desktop video/image files by the live path.
- Explicit developer CLI diagnostics can write numeric/status JSON or generated-artwork PNGs. Status may contain operating-system error descriptions, so review reports before sharing.
- Settings are stored locally with UserDefaults. The UI review fixture does not start capture, sensor polling, a watchdog or a global hotkey and does not save preferences.
- The watchdog verifies its actual direct parent before sending termination signals. It is not a guarantee against a system-wide freeze.

## 현재 동작

화면 프레임을 메모리에서 Metal로 전달합니다. 실제 경로는 바탕화면 영상·이미지를 파일로 저장하지 않습니다. 소리와 마이크는 캡처하지 않으며 네트워크 클라이언트·분석·계정·결제·인증 서버가 포함되어 있지 않습니다. 단, 명시적인 개발 진단은 숫자·상태 또는 자체 그림 파일을 만들 수 있으므로 공유 전 내용을 확인해야 합니다.

현재 오버레이를 해제해도 기능 자체가 켜져 있으면 캡처 연결과 공유 표시가 유지될 수 있습니다. 완전히 멈추려면 실제 덮개 효과를 끄거나 앱을 종료하세요. 설정은 로컬에 저장됩니다. UI 검토 모드는 실제 캡처·센서·감시·긴급키·설정 저장을 시작하지 않습니다.

## Confirmed, app-only permission recovery

Recover Permission… first presents a confirmation explaining that existing approval is removed. Cancellation does not change permissions. Only after confirmation does the app disable capture, validate a separately signed embedded helper through a private, bounded two-phase pipe handshake, save a pending nonce and quit normally. The helper checks its actual direct parent's signed identity and exact app path, waits for parent exit, then runs only the fixed system command: `/usr/bin/tccutil reset ScreenCapture com.bsl0707.hingeveil.preview`. It cannot accept another service, app ID, executable or shell command. No administrator privilege, launch daemon, TCC database edit, security bypass or automatic startup recovery is used.

The helper attempts to reopen the same installed Applications app. It writes a private local result receipt (0600 file in the app's support folder, new folder 0700), with only a nonce, protocol version, timestamps and reset exit code. A matching recent receipt is consumed once. Receipts are guidance, never authorization. The user must approve access in macOS and enable the effect themselves. Failure does not loop; mock fixtures use a separate fake backend with no OS changes. Future ad-hoc builds may still need recovery again.

‘권한 복구…’는 기존 허용 해제를 명시한 확인창에 동의해야만 진행합니다. 취소 시 권한을 바꾸지 않습니다. 같은 설치 앱의 검증된 직접 부모 종료를 확인한 도우미만 HingeVeil의 화면 권한 한 가지를 초기화합니다. 다른 앱·마이크·접근성·전체 권한은 대상으로 할 수 없고 관리자 권한·시스템 보안 해제도 사용하지 않습니다. 재실행 후 시스템 허용은 사용자가 직접 해야 하며, 오류 시 자동 반복하지 않습니다. 일회용 결과 파일은 화면·인증정보 없이 로컬 상태만 담으며 허용의 근거로 쓰지 않습니다. 임시 서명 충돌의 영구 해결은 아닙니다.

## Review limits

The included audit is a small heuristic scanner, not a comprehensive secret scanner, penetration test, dependency audit, privacy certification or legal opinion. It detects selected token/key/private-path/email patterns and unexpected source files, rejects symlinks and flags PNG text/EXIF chunks. A clean result does not prove the absence of unknown credentials, personal data, vulnerabilities, ownership issues or unexpected runtime behavior.

자동 검사는 일부 패턴과 파일 구성만 확인합니다. 검색에 걸리지 않는 비밀정보·개인정보·취약점·권리 문제의 부재를 보장하지 않습니다. 실제 배포 바이너리와 Git 이력이 생긴 뒤에는 그 대상도 다시 검토해야 합니다.

## Reporting

After the public repository exists and the owner enables private vulnerability reporting, use its Security → Advisories → Report a vulnerability entry. If that entry is missing, do not put vulnerability details in a public issue; ask the maintainer for a private route without disclosing the vulnerability. No private reporting endpoint, public email or response-time promise has been invented for this local preparation.

공개 저장소 생성 후 관리자가 비공개 취약점 제보를 켜면 Security → Advisories → Report a vulnerability로 제보하세요. 버튼이 없으면 취약점 내용을 공개 이슈에 올리지 말고, 상세 내용 없이 관리자에게 비공개 경로를 요청하세요. 이번 로컬 준비 단계에서는 실제 제보 주소·이메일·응답 기한을 임의로 만들지 않았습니다.

Do not post credentials, serial numbers, captured screens or full private diagnostic files. Start with the affected version, minimal reproduction, impact and sanitized error information. No bounty is offered. See the repository setup steps in Docs/GitHubUpload.en.md or Docs/GitHubUpload.ko.md.

인증정보·일련번호·실제 화면·개인 진단 전체 파일을 올리지 마세요. 영향 버전·최소 재현 방법·영향·개인정보를 제거한 오류 정보부터 보내주세요. 버그 포상금은 약속하지 않습니다. 저장소 설정 순서는 한·영 업로드 가이드에 있습니다.
