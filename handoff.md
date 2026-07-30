# OpacityWindow handoff

**Last updated: 2026-07-29**

A macOS reference-image viewer whose whole window can be made semi-transparent, so
you can trace or eyeball a reference over whatever app is behind it. SwiftUI, single
target, no dependencies.

## Current state: working, clean, merged to main

| | |
|---|---|
| Repo | `github.com/fomoPhil/opacity-window` (**public**) |
| Local | `~/Projects/opacity-window` |
| HEAD | `main`, Swift 6 migration merged. **Not pushed to origin yet.** |
| Working tree | clean |
| Build | **BUILD SUCCEEDED**, 0 errors, **0 warnings**, 0 deprecations (Debug and Release) |
| Verified on | Xcode 26.3, Swift 6.2.4, macOS 26.3, Apple Silicon |
| Language mode | **Swift 6** (`SWIFT_VERSION = 6.0`), full strict concurrency |
| Bundle id | `com.opacitywindow.app` |
| Deployment target | macOS 14.0 |
| Size | 733 lines of Swift across 5 files |

Verified by hand on 2026-07-29 after the Swift 6 migration, all on a running build:
cold launch with a file, warm `open -a` while running, opacity slider driven by
synthetic drag (95% → 25% → 100%, fade confirmed in a screenshot), ⌘O panel opens and
dismisses, always-on-top toggling the window level between 0 and 3, ⌘L lock showing
the unlock panel and clicking it unlocking again, moving **and** resizing the window
while locked with the panel tracking to the right spot each time, clean quit, no crash
reports, no actor or data-race complaints in the system log.

Drag-and-drop is the one path that resists synthetic events. Both of its branches were
instead exercised directly against real `NSItemProvider`s, compiled under Swift 6, and
both round-tripped correctly.

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
                         opacity/zoom/offset bindings, hover behaviour. 376 lines,
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
notification**, because that reintroduces the cold-launch race.

## What changed most recently (Swift 6 migration)

The project now builds in **Swift 6 language mode** with full strict concurrency, and
all four Grand Central Dispatch hops are gone. What that took:

- `OpenImageRequest` and `UnlockButtonWindowController` are `@MainActor`. Their
  `static let shared` singletons were the only two *hard errors* under Swift 6.
- `WindowAccessor` swapped both `DispatchQueue.main.async` calls for `Task { }`, which
  inherits MainActor isolation from `NSViewRepresentable`. Its two near-identical
  bodies collapsed into one `apply(to:)` helper.
- `ContentView.handleDrop` is now async. `NSItemProvider.loadDataRepresentation`
  returns a `Progress` handle, so **Swift generates no async bridge for it**; there is
  a small `withCheckedThrowingContinuation` wrapper at the bottom of ContentView.swift.
  The fileURL branch now loads `Data` instead of `loadItem`'s `NSSecureCoding`, which
  keeps the whole path on Sendable types.
- The unlock panel's resize observer **was leaking**. Only the didMove token was kept,
  so the didResize observer was never removed and stacked up another copy on every
  `show()`. Both tokens are now stored and torn down.

The two window observers deliberately keep `addObserver(forName:queue:.main)` plus
`MainActor.assumeIsolated` rather than an async sequence.
`NotificationCenter.notifications(named:object:)` wants a `Sendable` object and
`NSWindow` is not one. `assumeIsolated` is sound here because `queue: .main`
guarantees main-thread delivery, and it stays synchronous, so the button does not lag
a frame behind the window during a drag.

## Previously (c6bd5ae)

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
  `slider 1 of scroll area <n> of group 1 of window <n>` (the toolbar is a scroll
  area). Resolve `<n>` at runtime rather than hardcoding 1; see the window-count quirk
  below for why the indices move around.
- **The app opens more than one window, and this is not yet understood.** A plain
  launch produces two windows; `open -a OpacityWindow <image>` while already running
  adds another and loads the image into the *new* one, leaving the old window on
  screen showing the previous image. Confirmed **pre-existing** (reproduced on
  `aa4ea32` before the Swift 6 work, so the migration did not cause it). Two knock-on
  effects worth knowing:
  - ⌘L toggles lock on **every** window, because the lock is a global
    `NotificationCenter` post that every `ContentView` receives, and they all then
    compete over the single `UnlockButtonWindowController.shared` panel.
  - `CGWindowListCopyWindowInfo` lists **two entries per NSWindow**, so count
    distinct bounds, not raw rows, when checking how many windows exist.
- **No tests at all.** "Working" currently means someone verified it by hand.
- **Not distributable.** No `DEVELOPMENT_TEAM`; it signs "to Run Locally". Sharing it
  with anyone else needs signing and notarising.

## Deliberately not done

These were considered and skipped as higher-risk than the value they'd deliver. Pick
them up only with intent:

1. **A test target.** Even a couple of unit tests around image loading and opacity
   clamping would convert "verified by hand" into something that stays verified.
2. **Signing and notarisation**, if this is ever shared.
3. **The multi-window behaviour above.** Never scoped, and it is the most likely thing
   to confuse a user: open a second image and the first window is still sitting there.
   Deciding whether this app is single-window or genuinely multi-window is a *product*
   question, not a bug fix, so it needs a decision before any code.

## Ideas never scoped

Multiple images / tabs, remembering window position and last image between launches,
flip and rotate, a colour picker/eyedropper for referencing colours, global hotkey to
summon the window. None of these have been discussed with the owner, so treat as
unvalidated.
