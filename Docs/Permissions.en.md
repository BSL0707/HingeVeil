# Screen permission, restarting and older-build recovery

[한국어](Permissions.ko.md) · [Download & installation](../README.md) · [Full manual](Manual.en.md)

## What this update does

HingeVeil 0.1.12 remains an ad-hoc-signed development preview. This update improves authorization rechecks and guidance; it does not bypass macOS approval or automatically repair code-signing conflicts. **Unconfirmed means the app cannot currently confirm access**, not that you necessarily failed to allow it.

## First installation

1. Quit other HingeVeil copies and lid-effect apps. Run one copy from Applications, not the mounted DMG.
2. Click **Request Access** once. Use **Open Settings** → Privacy & Security → Screen & System Audio Recording (older macOS: Screen Recording) to allow HingeVeil yourself.
3. Choose **Quit & Reopen** if macOS offers it. Otherwise use **Permission & Restart Help → Quit App**, then reopen from Applications.
4. Click **Recheck Permission**. When Screen access confirmed appears, enable the live effect yourself.

The app reads authorization on return and at most once per second while foreground. Enabling the effect, testing and Recheck Permission do not display system requests. Request Access can call the system request at most once per app process; after a request or denial, use Settings and the restart guidance. If authorization is no longer confirmed, capture and effects stop and are not automatically re-enabled.

## Allowed in Settings but still unconfirmed / updating an older build

A new build with a changed ad-hoc signature can conflict with the previous saved approval. Downloading the identical DMG again does not itself change its signature. Check Settings and restart first. Closing the window does not quit the app.

Only if this still fails, use this **optional manual recovery**:

1. Fully quit HingeVeil and other copies.
2. Only if you choose, run exactly this command in Terminal. It resets **HingeVeil screen-recording approval only**, not other apps.

   ```sh
   tccutil reset ScreenCapture com.bsl0707.hingeveil.preview
   ```

3. Reopen the same app from Applications, click **Request Access** once and allow it yourself. Choose Quit & Reopen if offered.

The app never runs this command automatically. Do not run `tccutil reset All`, reset every app, edit the TCC database, disable Gatekeeper/SIP or remove quarantine attributes. Organizational policies or OS state may still prevent recovery. Instead of repeatedly resetting, [report a bug](https://github.com/BSL0707/HingeVeil/issues) after redacting personal information in diagnostics.

## Remaining limits

- Future updates that change the ad-hoc signature may require approval or manual recovery again. This is not a guaranteed permanent fix.
- Developer ID signing and Apple notarization are not included. A Gatekeeper launch block is separate from screen-recording permission. [Apple launch guidance](https://support.apple.com/en-us/102445)
- First installations, updates and OS permission behavior have not been verified on every model. Automated tests do not perform or replace real macOS consent.

If the screen is obscured, **click or press Control+Option+Command+Esc** to dismiss the overlay. Turn the live effect OFF or quit to stop capture as well.
