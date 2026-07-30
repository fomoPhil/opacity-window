# OpacityWindow — handoff

**Last updated: 2026-07-29**

A macOS reference-image viewer whose whole window can be made semi-transparent, so
you can trace or eyeball a reference over whatever app is behind it. SwiftUI, single
target, no dependencies.

## Current state: working, clean, pushed

| | |
|---|---|
| Repo | `github.com/fomoPhil/opacity-window` (**public**) |
| Local | `~/Projects/opacity-window`, in sync with `origin/main` |
| HEAD | `c6bd5ae` "Open images from Finder, and refresh bundle metadata" |
| Working tree | clean |
| Build | **BUILD SUCCEEDED**, 0 errors, **0 warnings**, 0 deprecations |
| Verified on | Xcode 26.3, Swift 6.2.4, macOS 26.3, Apple Silicon |
| Bundle id | `com.opacitywindow.app` |
| Deployment target | macOS 14.0 |
| Size | 726 lines of Swift across 5 files |

Everything was tested by hand on 2026-07-29 and works: launch, image load, opacity
slider (95% → 35%, visually confirmed the background reads through), zoom/pan
controls, clean quit, no crash logs.

## Build and run

```bash
cd ~/Projects/opacity-window
xcodebuild -project OpacityWindow.xcodeproj -scheme OpacityWindow \
           -configuration Debug -destination 'platform=macOS' build
open ~/Library/Developer/Xcode/DerivedData/OpacityWindow-*/Build/Products/Debug/OpacityWindow.app
```

There is one scheme, `OpacityWindow`, and no test target.

## Architecture

```
OpacityWindowApp.swift   @main. Menu commands (⌘O, ⌘L) posted via NotificationCenter.
                         AppDelegate makes the window transparent on launch and
                         receives files from Finder. Holds OpenImageRequest.
ContentView.swift        Everything else: drop target, image state, ControlsBar,
                         opacity/zoom/offset bindings, hover behaviour. 361 lines —
                         the natural place to split if it grows further.
ImageView.swift          Image display with zoom and pan gestures.
WindowAccessor.swift     NSViewRepresentable bridge to NSWindow for alphaValue,
                         always-on-top level, and click-through when locked.
UnlockButtonWindow.swift Separate floating window giving you a way back out of
                         locked (click-through) mode.
```

**Communication is by NotificationCenter**, not shared observable state: menu
commands post `.openImagePicker` / `.toggleLock` and `ContentView` receives them.
Match that pattern when adding menu items.

**The one exception is file opening**, and it is deliberate. `OpenImageRequest` is a
singleton `ObservableObject` holding the pending URL, because on a cold launch the
file arrives from Finder *before* `ContentView` exists, so a one-shot notification
would fire into the void. `ContentView` drains it in `.onAppear` and also observes
the publisher for opens while already running. **Do not "simplify" this into a
notification** — that reintroduces the cold-launch race.

## What changed most recently (c6bd5ae)

Images can now be opened from Finder: right-click → Open With, dropping a file on the
Dock icon, and `open -a OpacityWindow image.png`. This needed both halves:

- `CFBundleDocumentTypes` for `public.image` in Info.plist, with
  **`LSHandlerRank = Alternate`** so it never displaces Preview as the system default
- the receiving side described above

Declaring the type without wiring the handler would have listed the app in Open With
and then done nothing, which is worse than not appearing at all.

Also in that commit: copyright year to 2026, and five stray trailing newlines that had
been sitting uncommitted in Info.plist, README.md and three asset catalog files.

## Known issues and quirks

- **Window restores onto a second display.** It reopens around x=2485, i.e. the
  right-hand monitor. Not a bug introduced by any recent change, but it makes
  screenshot-based verification confusing: `screencapture` grabs the main display
  only. To capture the window regardless of which display it is on, find its window
  id via `CGWindowListCopyWindowInfo` and use `screencapture -l <id>`.
- **SwiftUI sliders ignore accessibility `set value`.** Automating the opacity slider
  needs a synthetic mouse drag (Quartz `CGEventCreateMouseEvent`), not
  `set value of slider 1`. Also note the accessibility value is normalised 0–1, not
  0–100, and the slider lives at
  `slider 1 of scroll area 1 of group 1 of window 1` (the toolbar is a scroll area).
- **No tests at all.** "Working" currently means someone verified it by hand.
- **Not distributable.** No `DEVELOPMENT_TEAM`; it signs "to Run Locally". Sharing it
  with anyone else needs signing and notarising.

## Deliberately not done

These were considered and skipped as higher-risk than the value they'd deliver. Pick
them up only with intent:

1. **Swift 6 language mode.** `SWIFT_VERSION = 5.0` today. Moving to 6 turns on strict
   concurrency and will likely surface warnings across `WindowAccessor`,
   `UnlockButtonWindow` and the `DispatchQueue.main.async` sites. Do it as its own
   pass with its own commit, not bundled with a feature.
2. **Replace 3× `DispatchQueue.main.async`** (ContentView ×2, WindowAccessor ×2) with
   `@MainActor` / `Task`. Naturally falls out of item 1.
3. **A test target.** Even a couple of unit tests around image loading and opacity
   clamping would convert "verified by hand" into something that stays verified.
4. **Signing and notarisation**, if this is ever shared.

## Ideas never scoped

Multiple images / tabs, remembering window position and last image between launches,
flip and rotate, a colour picker/eyedropper for referencing colours, global hotkey to
summon the window. None of these have been discussed with the owner — treat as
unvalidated.
