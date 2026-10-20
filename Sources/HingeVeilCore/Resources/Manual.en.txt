HingeVeil User Manual
English · Development preview 0.1.12

1. Requirements and limitations

HingeVeil is a native macOS 14-or-later Apple silicon development app. The live effect requires a recognized built-in lid-angle sensor and the built-in display. A chip name or screen size alone does not guarantee support. The white tiger artwork preview works without screen capture permission. All models, Mission Control, HDR, external-display arrangements and long-term power use have not been comprehensively tested.

2. Language

Use Language in the settings window to choose Follow System, 한국어 or English. The system option uses Korean when the first preferred language is Korean; otherwise it uses English. The app's interface, current status and manual update without restarting. macOS-owned permission prompts may follow the system's app-language settings rather than this picker.

3. Permission and first launch

Quit other lid-effect apps and HingeVeil copies. Run one version from Applications, not from the mounted DMG. Click Request Access once. In System Settings → Privacy & Security → Screen & System Audio Recording, allow HingeVeil yourself. Older macOS releases may call this Screen Recording. Accessibility, Input Monitoring, microphone and audio-capture permission are not required.

The app reads authorization again when you return, and at most once per second while it is foreground. Recheck Permission never displays a system request. Enabling the effect and running a test also only read the state; they do not repeatedly request access. The explicit Request Access button can make at most one system request per app process. After Screen access confirmed appears, enable the live effect yourself.

If Settings allows access but the app remains unconfirmed, open Permission & Restart Help. Use the system's Quit & Reopen if offered, or Quit App and reopen HingeVeil from Applications. Closing the window is not quitting. Restarting is not a guarantee of recovery; do not keep pressing Allow.

Updating an older build can change its ad-hoc signature and conflict with the saved approval. Downloading the same DMG again does not itself change its signature. If restarting does not help, quit the app. Only if you choose, run this command in Terminal to reset this app's screen permission alone:
  tccutil reset ScreenCapture com.bsl0707.hingeveil.preview
Reopen the same app, click Request Access once and approve it yourself. The app never runs this command or grants access automatically. Do not reset other apps, services or all permissions. If organizational policy or OS state still prevents access, redact diagnostics before reporting the problem.

This release is ad-hoc signed, not Developer ID signed or Apple notarized. Gatekeeper may warn or block launch, and permission continuity across updates is not guaranteed. Do not disable Gatekeeper, SIP or system-wide protections, or remove quarantine attributes. Apple Developer enrollment, paid signing and notarization are outside this task.

4. Preview and live use

Move Preview angle to see the bundled white tiger without capturing your desktop. This slider does not control the physical lid.

Choose an effect start angle of 85°, 90°, 95° or 100°. The default is 90°. Blur has four levels, with Level 2 as the default. Existing saved selections are preserved.

Enable Live lid effect. Open the lid at least 3° beyond the selected start angle to arm; for a 90° start, open to at least 93°. Then lower the lid. The app remembers whether you enabled the effect and restores it only when permission and safety controls are ready.

Click 30% Fold Test · 2 s to test your actual desktop. It displays for 2 seconds, then returns over approximately 0.24 seconds. The test and the normal live effect require permission. Use the HingeVeil menu-bar icon to reopen settings.

5. What the effect does

The app applies bounded counter-motion, a soft aperture and center/edge blur. The bottom hinge remains fixed; some upper content is intentionally cropped rather than fitted back into the display. The maximum vertical panel enlargement is 12%; there is no unbounded zoom. Blur strength does not change the motion geometry.

Normal entry blends in over approximately 0.18 seconds after a neutral first frame. Normal exit returns toward neutral and fades over approximately 0.24 seconds. Closing again during exit resumes the effect. The app does not track your eyes or guarantee a physically stationary image.

6. Holding an angle and the safety limit

If you hold the lid at an intermediate angle such as 32°, the current effect is dismissed after at most 15 seconds from its start. This is a fixed safety limit, not a configurable duration. The same angle will not immediately restart it. Open at least 3° beyond the start angle to re-arm. The test uses its own 2-second display plus approximately 0.24-second exit.

7. Escape if the screen is obscured

Click the effect screen, or press Control + Option + Command + Esc, to dismiss the current overlay immediately. Menu → Dismiss Effect Now does the same. To stop background screen capture as well, turn Live lid effect OFF or quit HingeVeil.

If the app's main event loop stalls while an effect is active, a separate safety monitor is designed to terminate HingeVeil after approximately 3 seconds. This is not a guarantee against an operating-system or WindowServer freeze. If needed, press Command + Option + Esc, select HingeVeil, and choose Force Quit.

8. Why the menu bar says screen sharing

While Live lid effect is enabled, the app keeps a local ScreenCaptureKit connection ready to reduce startup delay. It requests up to 15 frames per second while idle and 60 during the effect; the renderer requests up to the display's supported refresh rate, capped at 120 Hz. The macOS screen-capture/sharing indicator can remain visible even while the lid is open or after dismissing just the overlay. It does not mean the screen is sent to another person.

Turn Live lid effect OFF or quit the app to stop its capture session. Permission can remain granted. Memory and energy use depend on the Mac, screen, captured content and usage; no fixed memory budget is guaranteed.

9. Sleep, locking, video and displays

Closing completely into sleep stops the effect. An opening effect over the lock screen is not supported. Unlock, open beyond the arming angle, then lower the lid again. The effect targets only the built-in display. Protected video can appear black in capture; HDR and exact color matching are not guaranteed.

10. Privacy

Screen frames are used in memory for local rendering. The app includes no screen-recording file writer, screen upload, audio or microphone capture, analytics server, account, payment or licensing server. Settings such as language, angle, blur and enabled state are stored locally. Developer diagnostic command-line modes can write numeric/status reports or generated-artwork PNGs when explicitly invoked; they do not save captured desktop frames. Do not post diagnostic files without checking their contents.

11. Release status and licensing

HingeVeil 0.1.12 is a public development preview under the owner-selected MIT license, copyright (c) 2026 bsl lab. Include the LICENSE notice when redistributing. Source, installers and current publication status are available at https://github.com/BSL0707/HingeVeil . AI artwork provenance and rights-review limits are documented in PROVENANCE.md and LICENSE-STATUS.md. This is not a guarantee of compatibility, legal clearance, security or complete resolution of signing-related permission issues.
