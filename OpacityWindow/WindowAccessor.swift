import SwiftUI
import AppKit

/// A view modifier that provides access to the NSWindow for level and lock control
struct WindowAccessor: NSViewRepresentable {
    var isAlwaysOnTop: Bool
    var isLocked: Bool
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.isOpaque = false
                window.backgroundColor = .clear
                window.level = isAlwaysOnTop ? .floating : .normal
                window.ignoresMouseEvents = isLocked
                
                // Show/hide unlock button window based on lock state
                if isLocked {
                    UnlockButtonWindowController.shared.show(relativeTo: window) {
                        NotificationCenter.default.post(name: .toggleLock, object: nil)
                    }
                } else {
                    UnlockButtonWindowController.shared.hide()
                }
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                window.level = isAlwaysOnTop ? .floating : .normal
                window.ignoresMouseEvents = isLocked
                
                // Show/hide unlock button window based on lock state
                if isLocked {
                    UnlockButtonWindowController.shared.show(relativeTo: window) {
                        NotificationCenter.default.post(name: .toggleLock, object: nil)
                    }
                } else {
                    UnlockButtonWindowController.shared.hide()
                }
            }
        }
    }
}

extension View {
    func windowSettings(isAlwaysOnTop: Bool = false, isLocked: Bool = false) -> some View {
        self.background(WindowAccessor(isAlwaysOnTop: isAlwaysOnTop, isLocked: isLocked))
    }
}
