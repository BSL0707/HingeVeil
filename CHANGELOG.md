# Changelog / 변경 이력

## 0.1.14 — confirmed screen-permission recovery, 2026-10-20

- Add Recover Permission… / 권한 복구… with a localized confirmation. Cancellation changes no permissions. Confirmation removes only this app's existing screen approval; no Terminal is needed.
- A separately signed, non-privileged embedded helper verifies its actual direct parent's signed identity and exact Applications app path. A bounded private READY/COMMIT handshake and parent-exit check precede the fixed app-only reset and same-app reopen.
- Require manual macOS consent and manual effect enable after reopening. No automatic reset loop, grant, administrator prompt, TCC database edit or security bypass.
- Add matching-nonce, expiring one-shot recovery receipts, failure/cancel/scope tests and safe subprocess fixtures whose backend never changes OS permissions.
- Update Korean/English UI, manuals, recovery and installation guides. Include the previously local 0.1.13 motion, lower-blur and cursor fixes below.
- Still ad-hoc signed, not Developer ID signed or notarized. Recovery can fail or be needed again after future updates; this is not a permanent signing fix.

확인창 동의 후 HingeVeil 화면 권한만 초기화하고 같은 앱을 다시 여는 버튼을 추가했습니다. 시스템 허용은 사용자가 직접 해야 합니다. 기존 모션·하단 블러·커서 수정과 블러 4단계·기본 2단계·안전 탈출을 유지합니다.

## 0.1.13 — local motion and cursor candidate, 2026-10-20

- Redistribute bounded counter-projection travel so 30→25→20° retains measurable content motion. Ease the final 20→15° interval without increasing the 12% vertical gain cap.
- Fade lower-panel blur smoothly from 72% to 98% of the height, retaining 8% of its original mix at the hinge. Preserve upper-center/side haze, four radius levels and the Level 2 default.
- Exclude the cursor from ScreenCaptureKit frames; leave the real system cursor visible without hiding or replacing it.
- Add deep-angle/hinge-clarity unit tests, a cursor configuration contract, GPU geometry checks at 30/25/20° and bottom-detail checks across four angles and four blur levels.
- Preserve permission guidance, fixed safety timeout, emergency escape and watchdog behavior. Local candidate only; no GitHub release or automatic permission reset.

20~30도 구간 모션·하단 블러·복제 커서를 수정한 로컬 후보입니다. 기존 버전을 백업한 뒤 사용자 승인으로 교체하며, GitHub에는 아직 공개하지 않습니다.

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
