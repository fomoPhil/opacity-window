# OpacityWindow

macOS reference-image viewer with adjustable window transparency. SwiftUI, one target,
no dependencies. **Read `handoff.md` first**. It holds current state, architecture,
known quirks, and the deliberately-deferred work.

## Orientation

- Repo: `github.com/fomoPhil/opacity-window` (public). Local is the same directory.
- One scheme: `OpacityWindow`. **No test target.**
- Build: `xcodebuild -project OpacityWindow.xcodeproj -scheme OpacityWindow -configuration Debug -destination 'platform=macOS' build`
- Target macOS 14.0; `SWIFT_VERSION = 6.0` (**Swift 6 language mode**, full strict
  concurrency). New code must be concurrency-clean, not just warning-free.

## Project-specific rules

**Keep the build at zero warnings.** It is currently clean on Xcode 26.3 / Swift 6.2.4.
Treat a new warning as something to fix, not to accept.

**Add menu commands via NotificationCenter**, matching `.openImagePicker` and
`.toggleLock` in `OpacityWindowApp.swift`.

**Do not turn `OpenImageRequest` into a one-shot notification.** It is a held value
specifically because Finder hands over the file before `ContentView` exists on a cold
launch. See handoff.md.

**Never hand-edit the app icon PNGs.** `tools/MakeIcon.swift` is the source of
truth. It draws the icon in CoreGraphics and writes all ten sizes plus
`Contents.json`. Regenerate with:

```bash
swiftc -O tools/MakeIcon.swift -o /tmp/makeicon && \
  /tmp/makeicon OpacityWindow/Assets.xcassets/AppIcon.appiconset
```

Each size is a *different drawing*, deliberately. Below 28 px the checkerboard and
the white rim are dropped entirely, because a 1 px rim around an 11 px tile bleaches
the amber out and three pixels of checker is noise rather than pattern. That
per-size hinting is the whole reason this is generated rather than downsampled, so
do not "simplify" it into one drawing scaled down.

**Keep the scene a single-instance `Window`, not a `WindowGroup`.** This is a
deliberate product decision, not an oversight. A WindowGroup spawns a second window
when a file is opened while an as-yet-unused window is on screen, and it makes the
global ⌘L notification and the singleton unlock panel genuinely wrong rather than
merely redundant.

**Keep `LSHandlerRank = Alternate`** in Info.plist. This app must never become the
system default image handler ahead of Preview.

## Distribution (Developer ID, outside the App Store)

Signed and notarised under the **Personal Team**, not Meora Studios. Confirm this
before any signing, certificate or notarisation work.

| | |
|---|---|
| Team | `AXW4GKUTKZ` ("PHILIP JAMES WOOLLEY") |
| Certificate | Developer ID Application, expires **1 Feb 2027** |
| Bundle id | `com.opacitywindow.app` |
| `asc` profile | `Samplomatic`. Run `asc auth status` and confirm it is the default *before* submitting, or the notarisation key will not match the signing certificate. |
| Export config | `ExportOptions.plist` in the repo root |

Meora Studios has **no** Developer ID Application certificate, and the App Store
Connect API cannot create one. Switching teams means creating that certificate by hand
at developer.apple.com first.

Release recipe:

```bash
xcodebuild archive -project OpacityWindow.xcodeproj -scheme OpacityWindow \
  -configuration Release -archivePath /tmp/OpacityWindow.xcarchive \
  -destination 'generic/platform=macOS'
xcodebuild -exportArchive -archivePath /tmp/OpacityWindow.xcarchive \
  -exportPath /tmp/ow-export -exportOptionsPlist ExportOptions.plist
# app: notarise, then staple
ditto -c -k --keepParent /tmp/ow-export/OpacityWindow.app /tmp/ow-export/OpacityWindow.zip
asc notarization submit --file /tmp/ow-export/OpacityWindow.zip --wait
xcrun stapler staple /tmp/ow-export/OpacityWindow.app
# dmg: build from the stapled app, then sign BEFORE notarising
hdiutil create -volname OpacityWindow -srcfolder <stage> -ov -format UDZO /tmp/OpacityWindow-1.0.dmg
codesign --force --sign "Developer ID Application: PHILIP JAMES WOOLLEY (AXW4GKUTKZ)" \
  --timestamp /tmp/OpacityWindow-1.0.dmg
asc notarization submit --file /tmp/OpacityWindow-1.0.dmg --wait
xcrun stapler staple /tmp/OpacityWindow-1.0.dmg
```

Two things that will bite:

- **Sign the DMG before notarising it, never after stapling.** Signing invalidates an
  existing ticket. An unsigned DMG notarises fine but `spctl` reports
  "no usable signature", which looks like a notarisation failure and is not one.
- **`ENABLE_HARDENED_RUNTIME = YES` is required.** Without it notarisation is rejected.
  It is set in both configurations; do not remove it.

Verify a build the way a recipient would experience it, not just with `codesign`: set a
quarantine attribute (`xattr -w com.apple.quarantine "0083;...;Safari;$(uuidgen)"`),
then `spctl -a -vvv -t open` the DMG and `-t execute` the app. Expect
`source=Notarized Developer ID`. Note that a quarantined app launched from anywhere
other than `/Applications` runs under **App Translocation** from a randomised read-only
path, which starts noticeably slower. Give it ~10s before concluding it failed to open.

## Verifying a change actually works

Building is not evidence. Launch it and confirm behaviour:

- The window reopens on the **second display** (~x=2485), so `screencapture` of the
  main display looks empty. Get the window id from `CGWindowListCopyWindowInfo` and
  use `screencapture -l <id>`.
- The opacity slider **ignores accessibility `set value`** (SwiftUI). Drive it with a
  synthetic Quartz mouse drag. Its accessibility value is 0–1, not 0–100, and it sits
  at `slider 1 of scroll area 1 of group 1 of window 1`.
- Image loading has three paths worth checking independently: drag-and-drop, ⌘O panel,
  and `open -a OpacityWindow <image>` (cold launch and already-running differ).
- **Purge saved state before counting windows.** Quit the app, wait for the process to
  exit, then `rm -rf ~/Library/"Saved Application State"/com.opacitywindow.app.savedState`.
  Otherwise macOS restores the previous run's windows and they look like a bug in this
  one. `CGWindowListCopyWindowInfo` also lists two rows per window, so count distinct
  bounds.
- **Once locked, the unlock panel is AX `window 1`.** A naive `set position of window 1`
  moves that little panel instead of the window you meant, and the test then proves
  nothing. Select the window by size, not index.
- Drag-and-drop cannot be driven by synthetic events. Exercise `handleDrop`'s two
  branches directly against a real `NSItemProvider` in a small standalone binary
  instead.
