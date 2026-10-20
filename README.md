# HingeVeil

[![Download for macOS — 설치파일 다운로드 · v0.1.12 · Apple Silicon](Docs/Download.svg)](https://github.com/BSL0707/HingeVeil/releases/download/v0.1.12/HingeVeil-0.1.12-AppleSilicon.dmg)

[한국어 설치 안내](#한국어-설치방법) · [English installation](#english-installation) · [Release & SHA-256](https://github.com/BSL0707/HingeVeil/releases/tag/v0.1.12)

macOS 14+ · Apple Silicon (arm64) · **Public development preview / 공개 개발 미리보기**

Requires a supported built-in MacBook lid sensor and built-in display; not every model is guaranteed. 지원되는 내장 덮개 센서가 있는 맥북용이며 모든 기종의 호환을 보장하지 않습니다.

## 한국어 설치방법

1. 위 버튼으로 **DMG 설치파일**을 받습니다. `Source code (zip)`은 설치파일이 아닙니다.
2. 기존 HingeVeil·다른 덮개 효과 앱을 종료합니다. DMG를 열어 **HingeVeil.app → Applications(응용 프로그램)** 으로 끌어 넣고, 디스크를 추출한 뒤 응용 프로그램 폴더에서 실행합니다.
3. **화면 권한 요청**을 한 번 누르고 시스템 설정 → 개인정보 보호 및 보안 → **화면 및 시스템 오디오 녹음**에서 HingeVeil을 허용합니다. 앱에 돌아와 **권한 다시 확인**을 누릅니다. 안내가 나오면 종료 및 다시 열기를 선택합니다. 구형 macOS에서는 '화면 기록'으로 표시됩니다.

**Apple Developer ID 서명·공증이 없는 임시 서명 개발판입니다.** macOS가 실행을 차단할 수 있습니다. 출처와 파일을 확인해 본인이 신뢰하는 경우에만 시스템의 앱별 **확인 없이 열기**를 사용하세요. Gatekeeper·SIP를 끄거나 격리 속성을 지우지 마세요. [Apple 안내](https://support.apple.com/ko-kr/102445)

[설치·권한·탈출 상세 안내 (한글)](https://github.com/BSL0707/HingeVeil/releases/download/v0.1.12/Install.ko.txt) · [한글 사용설명서](Docs/Manual.ko.md)

**이미 허용했는데 계속 미확인인가요?** 앱의 **권한·재시작 도움말** 또는 [구버전 권한 복구 안내](Docs/Permissions.ko.md)를 보세요. 이 업데이트는 상태 갱신·중복 요청·안내를 개선하며, 임시 서명 충돌을 자동·영구 해결하지는 않습니다.

## English installation

1. Download the **DMG installer** using the button above, not `Source code (zip)`.
2. Quit older HingeVeil copies and other lid-effect apps. Open the DMG, drag **HingeVeil.app → Applications**, eject the image, then launch from Applications.
3. Click **Request Access** once. Allow HingeVeil in System Settings → Privacy & Security → **Screen & System Audio Recording** (or Screen Recording on older macOS). Return and click **Recheck Permission**. Choose Quit & Reopen if prompted.

**Ad-hoc signed; NOT Developer ID signed or Apple notarized.** macOS may block launch. Only use the system's per-app **Open Anyway** option if you have checked and trust this build. Do not disable Gatekeeper/SIP or remove quarantine attributes. [Apple guidance](https://support.apple.com/en-us/102445)

[Detailed installation, permissions & escape guide (English)](https://github.com/BSL0707/HingeVeil/releases/download/v0.1.12/Install.en.txt) · [English user manual](Docs/Manual.en.md)

**Already allowed but still unconfirmed?** Use **Permission & Restart Help** in the app or the [older-build recovery guide](Docs/Permissions.en.md). This update improves rechecks, request suppression and guidance; it does not automatically or permanently repair ad-hoc signature conflicts.

Emergency / 긴급 탈출: click the effect / 효과 화면 클릭, or **Control+Option+Command+Esc**. Start / 시작: open beyond 93° with the default 90° setting, then lower the lid / 기본 90° 설정에서는 93° 이상 연 뒤 내리세요.

## About / 앱 소개

[한국어](README.ko.md) · [English manual](Docs/Manual.en.md) · [한국어 설명서](Docs/Manual.ko.md)

A native macOS lid-motion visual-effect development app. A soft aperture, bounded counter-motion and adjustable blur accompany the lid movement. The app does not track eyes or guarantee a physically stationary picture.

Version 0.1.12 · by **bsl lab** · [MIT license](LICENSE).

This public development preview includes source and a downloadable app, not a claim of complete device compatibility or a completed commercial release. See [provenance and review limits](PROVENANCE.md) and [license scope](LICENSE-STATUS.md).

## Interface and requirements

- One app with Follow System, 한국어 and English; live UI/menu/status/manual switching.
- macOS 14+, arm64 build, supported built-in lid sensor and built-in display.
- Start angle 85/90/95/100°, default 90°; four blur levels, default Level 2.
- 0.18-second normal entry, 0.24-second normal exit; bounded vertical panel enlargement of at most 12%.
- Current effect ends at the fixed 15-second safety limit; reopen at least 3° beyond the start angle to re-arm.
- Click or Control+Option+Command+Esc dismisses the overlay immediately. A separate watchdog is designed to terminate a stalled active app after about 3 seconds.
- Tiger artwork preview needs no screen permission; the actual-screen test displays for 2 seconds plus the normal exit.
- Full compatibility, Mission Control, sleep/lock recovery, HDR and long-term energy/memory behavior still need broader validation.

## Privacy

Screen frames are processed locally in memory. No desktop recording file writer, screen upload, audio/microphone capture, analytics, account or payment service is included. While the live effect is enabled, its screen-capture connection remains ready and macOS may keep the sharing indicator visible. Turn the live effect off or quit to stop it. Developer diagnostics can explicitly write status/numeric reports or generated-artwork PNGs; inspect these before sharing. See [Security and privacy](SECURITY.md).

## Build and validation

A full Xcode installation with Swift, macOS SDK and Metal compiler is required. No external package dependencies are declared. The script selects the toolchain for its own process; it does not change the system developer directory.

```sh
bash build.sh
Build/HingeVeil.app/Contents/MacOS/HingeVeil --check-localizations
Build/HingeVeil.app/Contents/MacOS/HingeVeil --self-check --previews
Build/HingeVeil.app/Contents/MacOS/HingeVeil --self-check --preview-artwork --previews
Build/HingeVeil.app/Contents/MacOS/HingeVeil --check-transitions --zero-alpha
Build/HingeVeil.app/Contents/MacOS/HingeVeil --check-guard
python3 scripts/audit_publication.py
python3 -m unittest discover -s scripts -p 'test_*.py'
```

For the complete non-interactive source/test/build check, run `bash scripts/ci.sh`. Its GitHub workflow uses a pinned checkout action, read-only permissions and no stored checkout credentials. It does not capture your desktop, install the app or publish releases. See the current [GitHub Actions results](https://github.com/BSL0707/HingeVeil/actions/workflows/ci.yml).

The diagnostic window/transition checks briefly display generated test pictures, never the real desktop. Native UI inspection without capture, sensor, hotkey, watchdog or preference writes:

```sh
Build/HingeVeil.app/Contents/MacOS/HingeVeil --review-ui --language en
Build/HingeVeil.app/Contents/MacOS/HingeVeil --review-ui --language ko --review-manual
```

Review mode closes after 45 seconds; live-effect controls are disabled. For normal use, open the app without these flags. This candidate is ad-hoc signed, not Developer ID signed or notarized. Rebuilding can require reconnecting only this app's screen permission. Do not disable Gatekeeper or system-wide protections.

## Source preparation

Only this folder's allowlisted source, tests, documentation and artwork belong in a source package. Do not include parent projects, comparisons, backups, original videos, diagnostics, caches, build products, signing keys or credentials. An export script validates and packages that allowlist; it does not upload anything. The review is heuristic, not a guarantee that secrets, vulnerabilities or legal issues are absent. See [Publication review](Docs/PublicationReview.md) and [Provenance](PROVENANCE.md).

[Upload checklist](Docs/GitHubUpload.en.md) · [Contributing](CONTRIBUTING.md) · [Security reporting](SECURITY.md) · [Changelog](CHANGELOG.md).

Apple Developer enrollment, Developer ID signing and notarization are outside this source-upload task. The local build retains ad-hoc signing for local execution; it does not use a paid certificate or an Apple account.
