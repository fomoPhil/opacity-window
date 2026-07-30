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

**Keep `LSHandlerRank = Alternate`** in Info.plist. This app must never become the
system default image handler ahead of Preview.

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
- **The app opens several windows**, so `window 1` in AppleScript is a coin flip. Worse,
  once the window is locked the **unlock panel becomes AX `window 1`**, so a naive
  `set position of window 1` silently moves the little panel instead of the window and
  the test proves nothing. Pick the window by size, not index. Reduce to a single
  window first (⌘W the extras) whenever the check depends on which window responded.
- Drag-and-drop cannot be driven by synthetic events. Exercise `handleDrop`'s two
  branches directly against a real `NSItemProvider` in a small standalone binary
  instead.
