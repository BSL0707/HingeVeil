# Publication preparation review / 공개 준비 점검

Date / 날짜: 2026-10-18 (Asia/Seoul)
Candidate / 후보: HingeVeil 0.1.11, build 12
Decision / 상태: MIT SOURCE UPLOAD PREPARATION — NOT PUBLISHED / MIT 소스 업로드 준비본, 공개 전

## Completed preparation / 준비한 내용

- Separated only HingeVeil source, tests, artwork and new sanitized documentation.
- Excluded legacy app/project folders, comparison source checkouts, Backups, Build, .build, previews, original videos, old diagnostic history and repository history from the source archive.
- One app with Korean, English and system-following selection; current status uses translatable templates so it can be re-rendered after a language change.
- Translated UI/menu/status/error templates (72 matching keys per language), macOS permission description and in-app/manual files in both languages.
- Both manuals include arming angle, four blur levels, the 15-second fixed limit, 2-second test, 0.18/0.24-second transitions, emergency dismissal, stopping capture, persistent sharing indicator, lock/sleep limits and development signing warnings.
- No changes to the motion equations, shader or EffectGate safety state machine. Sensor/capture/render callbacks now carry message templates rather than pre-translated snapshots.
- Build uses packaged resources rather than SwiftPM's absolute development resource fallback and maps source prefixes. Candidate source and app are scanned for private home paths and selected secrets.
- The owner explicitly selected MIT and the public copyright credit bsl lab on 2026-10-18. Standard LICENSE, bilingual scope/provenance/security/contribution notes and an updated manual are included.
- Added pinned, read-only GitHub CI, bug/feature/PR templates, Dependabot action-update configuration, source/manual/link checks, and a redacted index/reachable-commit audit.
- No GitHub creation, upload, visibility change, permission reset or stable-app replacement was performed. Apple Developer enrollment, paid signing and notarization are intentionally outside the requested source-upload scope.

기존 실행본과 개인 개발 이력은 그대로 보존했습니다. 분리본에만 언어/문서/검사/패키징을 추가했습니다. 기존 앱을 설치본으로 교체하거나 시스템 권한을 초기화하지 않았습니다.

## Validation status / 검증 상태

- Swift tests: 27 passing (22 existing + 5 localization tests).
- Python preparation tests: 20 passing, including redacted findings, private paths, source/GitHub allowlists, symlinks, deleted secrets in commit history, private commit emails, export integrity and refusal to overwrite.
- App resource check: English 72 / Korean 72 keys, both manuals present.
- GPU regression: 9 distinct outputs; bounded coordinate error 0.84/255 and source clipping checks pass.
- White tiger GPU check: 1586×992, white paper/black drawing lines and nine blur/angle outputs pass.
- Watchdog disposable-child check: about 3.07 seconds to termination.
- English and Korean settings windows, and both manual sheets, visually checked in no-capture review mode.
- Same-process language change verified in the native UI: selecting English from Korean updated the selected button, window title, status and control labels without restarting.
- Earlier unchanged-effect validation: generated-window neutral first frames, normal exit, re-entry, immediate emergency dismissal and no late resurrection passed. 248 completed / 236 presented frames; no missing drawables; recent p95/max presentation interval about 8.33 ms. This GUI fixture was not rerun for the GitHub/documentation changes. These are generated-picture observations, not full desktop latency guarantees.
- GPU checks rerun for this package: 9 distinct outputs, center grid contrast reduction 33.2%, edge 57.7%, coordinate error 0.84/255 and source clipping pass. GPU-only median 0.13 ms, maximum 3.56 ms; not end-to-end capture latency. White tiger output checks also pass.
- Final source/app scan covers 57 allowlisted files and 17 app files with zero selected-pattern findings and zero flagged PNG text/EXIF chunks. MIT is selected; legal clearance is not certified.
- The new MIT/GitHub source archive was extracted in a fresh temporary folder and built independently: all 20 Python and 27 Swift tests, release/Metal compilation, icon conversion, localized app resources, plist and local signature verification passed without the original project folder. The extracted snapshot adds one SHA-256 manifest (58 files in the archive).
- A temporary repository staged those 58 extracted files, and its index scan passed with no excluded files. It was not committed or pushed. Deleted-secret/private-email history tests use disposable synthetic repositories; no actual future publication commit has been created or audited yet.
- Initial icon conversion failed inside the restricted tool sandbox despite valid PNG sizes. The same conversion and both full build runs passed outside that restriction. No application logic was changed to hide the environment-specific failure.
- Motion model, EffectGate, shader, watchdog, logo and tiger PNG match the original independent 0.1.10 files byte-for-byte. Existing source/app files were not modified.
- The build continues to use local ad-hoc signing, with no paid certificate, Apple account, Developer ID or notarization request. Paid signing is not a blocker imposed by this source-upload review.
- GitHub workflow YAML syntax was locally parsed. The checkout v7.0.1 SHA and macos-15 hosted-runner label were checked against official sources. No hosted CI run has occurred; it must be checked after upload.
- Local text comparison against three older/comparison source sets found no byte-identical whole file or blocks of five or more filtered consecutive lines. See RightsReview.md for method and strict limitations.

These checks do not constitute full device compatibility, runtime privacy certification, performance/leak validation or rights clearance. This task does not re-run a physical-lid/real-screen acceptance test.

## Privacy and secret review / 개인정보·비밀정보

The source/app audit reports file/rule/line locations only, never matched credentials. Initial scans found no selected secret/private-home-path/email patterns or PNG text/EXIF metadata. Re-run after every source, asset, build or history change. A clean heuristic result is not proof of absence.

The developer bundle identifier com.bsl0707.hingeveil.preview remains intentionally unchanged to avoid silently changing identity/permission behavior. This is an application identifier, not a credential; it is disclosed here rather than silently removed. Confirm a desired production identifier before a future binary release. Numeric diagnostics may include OS error text and must be reviewed before posting. No old diagnostic reports are included.

초기 자동 검사에서는 대상 비밀키·토큰·개인 홈 경로·이메일 패턴과 PNG 텍스트/EXIF 메타데이터를 찾지 못했습니다. 개발용 앱 식별자는 비밀키가 아니지만 공개할 발행자 식별자가 맞는지 결정해야 합니다. 자동 검사가 잡지 못하는 개인정보·비밀정보가 있을 수 있으므로 공개 직전에 실제 대상과 Git 이력도 재점검해야 합니다.

## License decisions and remaining limits / 결정 사항과 남은 한계

1. Completed by owner instruction: MIT and copyright credit bsl lab. LICENSE contains the grant; LICENSE-STATUS.md explains scope. The owner's legal identity/authority has not been independently verified.
2. Completed: AI tiger and AppKit logo provenance, contribution guidance and security-reporting instructions. No exclusive AI-image copyright or trademark clearance is claimed.
3. Final legal code/visual rights review remains external: the authoring agent had viewed earlier code. Text comparison and provenance do not establish clean-room independence or non-infringement.
4. After repository creation: confirm owner/visibility, sanitized commit identity, actual hosted CI results and enable the private security reporting channel. Those remote settings cannot be completed by preparing files locally.
5. Source publication is not a completed commercial binary release. Production identity, installer/update/payment work and broader device/sleep/memory testing are separate. Paid Apple signing/notarization is excluded at the user's request.

See [rights review](RightsReview.md), [upload guide](GitHubUpload.en.md) and the [official GitHub licensing guide](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository). The MIT license allows redistribution and commercial use under its conditions; it does not prevent copying or resale. This is not legal advice or a rights guarantee.

## Local source export / 로컬 소스 내보내기

Run:

```sh
python3 scripts/audit_publication.py --app Build/HingeVeil.app --report .build/publication-audit.json
python3 scripts/export_source.py ../HingeVeil-GitHub-0.1.11-MIT.zip
```

The exporter rejects audit findings and symlinks, refuses to overwrite an existing archive, includes only an explicit source/documentation/GitHub-config allowlist and adds a relative-path SHA-256 manifest. No previous Git history is included. The ZIP is prepared for owner-controlled upload; generating it does not itself publish it. The app binary is intentionally excluded.

검사·허용 목록·상대 경로 매니페스트가 있는 소스 전용 ZIP을 만듭니다. 기존 ZIP을 덮어쓰거나 업로드하지 않습니다. ZIP 생성은 공개 승인이 아니며 앱 실행파일도 소스 ZIP에는 포함하지 않습니다.
