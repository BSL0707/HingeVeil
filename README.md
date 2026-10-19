# HingeVeil

[한국어](README.ko.md) · [English manual](Docs/Manual.en.md) · [한국어 설명서](Docs/Manual.ko.md)

A native macOS lid-motion visual-effect development app. A soft aperture, bounded counter-motion and adjustable blur accompany the lid movement. The app does not track eyes or guarantee a physically stationary picture.

Version 0.1.11 · by **bsl lab** · [MIT license](LICENSE).

This is a development preview prepared for source publication, not a claim of complete device compatibility or a completed commercial release. See [provenance and review limits](PROVENANCE.md) and [license scope](LICENSE-STATUS.md).

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

For the complete non-interactive source/test/build check, run `bash scripts/ci.sh`. Its GitHub workflow uses a pinned checkout action, read-only permissions and no stored checkout credentials. It does not capture your desktop, install the app or publish releases. GitHub-hosted execution must be verified after the repository is created.

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
