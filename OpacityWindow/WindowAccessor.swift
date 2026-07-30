import SwiftUI
import AppKit

/// A view modifier that provides access to the NSWindow for level and lock control
struct WindowAccessor: NSViewRepresentable {
    var isAlwaysOnTop: Bool
    var isLocked: Bool
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        // The view has no window yet at this point, so reading it is deferred a turn.
        // This Task inherits MainActor isolation from NSViewRepresentable.
        Task {
            view.window?.isOpaque = false
            view.window?.backgroundColor = .clear
            apply(to: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        Task {
            apply(to: nsView.window)
        }
    }

    @MainActor
    private func apply(to window: NSWindow?) {
        guard let window else { return }

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

extension View {
    func windowSettings(isAlwaysOnTop: Bool = false, isLocked: Bool = false) -> some View {
        self.background(WindowAccessor(isAlwaysOnTop: isAlwaysOnTop, isLocked: isLocked))
    }
}
