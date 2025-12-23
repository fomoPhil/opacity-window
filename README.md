# Opacity Window

A macOS reference image viewer with adjustable window opacity for artists and designers.

## Features

- **Adjustable Window Opacity**: Control the entire window's transparency from 5% to 100%
- **Image Loading**: Drag and drop images or use File → Open (⌘O)
- **Zoom & Pan**: Pinch to zoom, drag to pan, double-click to reset
- **Smart Controls**: Controls become fully visible on hover for easy access
- **Minimal UI**: Clean, unobtrusive interface that stays out of your way

## Supported Image Formats

- PNG, JPEG, TIFF, GIF, HEIC, WebP

## Usage

1. **Open the app** and drag an image onto the window, or press ⌘O to open a file picker
2. **Adjust opacity** using the slider in the control bar (5% - 100%)
3. **Zoom in/out** using pinch gestures or the +/- buttons
4. **Pan around** by clicking and dragging when zoomed in
5. **Reset view** by double-clicking or using the reset button
6. **Hover over controls** to make them fully visible

## Building

### Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later

### Steps

1. Open `OpacityWindow.xcodeproj` in Xcode
2. Select your development team in Signing & Capabilities
3. Build and run (⌘R)

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Open Image | ⌘O |
| Quit | ⌘Q |

## Architecture

- **SwiftUI** for the user interface
- **AppKit integration** for window-level opacity control via `NSWindow.alphaValue`
- Native macOS app with modern SwiftUI lifecycle

## Files

```
OpacityWindow/
├── OpacityWindowApp.swift    # App entry point & window configuration
├── ContentView.swift         # Main UI with controls overlay
├── ImageView.swift           # Image display with zoom/pan gestures
├── WindowAccessor.swift      # NSWindow bridge for opacity control
├── Assets.xcassets/          # App icons and colors
├── Info.plist                # App configuration
└── OpacityWindow.entitlements # App sandbox permissions
```

## License

MIT License

