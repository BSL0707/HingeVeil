# Changelog / 변경 이력

## 0.1.12 — permission UX and recovery, 2026-10-20

- Read-only authorization recheck on app activation, manual recheck, and at most once per second while foreground.
- Explicit request button with a once-per-process latch. Effect/test controls do not repeat OS permission requests.
- Visible confirmed/unconfirmed state, settings shortcut, restart guidance and app-only manual recovery help in Korean and English.
- Stop capture/effects when an existing grant becomes unconfirmed; require the user to enable the effect again.
- Add permission policy unit tests and integration contracts; retain motion, blur, sensor and safety behavior.
- Still ad-hoc signed, not Developer ID signed or notarized. Old-build signature conflicts can still require manual recovery. No automatic permission reset or security bypass is included.

권한 재확인·중복 요청 방지·재시작 및 구버전 복구 안내를 추가했습니다. 기존 효과와 블러는 유지합니다. Apple 서명 없이 모든 권한 충돌을 영구 해결하는 버전은 아닙니다.

## 0.1.11 — source preparation, 2026-10-18

- Korean, English and system-following UI/menu/status/manual selection.
- English and Korean manuals, including capture indicator and emergency exit guidance.
- Source-only separation, allowlist/secret-pattern audits and export manifest.
- MIT license selected by the owner, copyright credit bsl lab.
- GitHub CI configuration, issue/PR forms, contribution and security guidance.
- No changes to the established motion model, shader or safety state machine.
- No public repository, hosted CI run, installed-app replacement or binary release performed here.

한·영 UI/설명서와 업로드 기반을 준비했습니다. 기존 화면 효과·안전 로직은 그대로이며 공개 저장소 생성·실제 CI·앱 교체·실행파일 배포는 아직 하지 않았습니다.
