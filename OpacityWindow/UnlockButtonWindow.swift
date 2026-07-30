import SwiftUI
import AppKit

/// A small floating panel that contains the unlock button
/// This window remains clickable even when the main window ignores mouse events
final class UnlockButtonWindow: NSPanel {
    private var hostingView: NSHostingView<UnlockButtonView>?
    private var onUnlock: @MainActor () -> Void = {}
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 90, height: 36),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.level = .floating + 1 // Above the main floating window
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovable = false
        self.hidesOnDeactivate = false
        
        setupContent()
    }
    
    private func setupContent() {
        let view = UnlockButtonView { [weak self] in
            self?.onUnlock()
        }
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 90, height: 36)
        self.contentView = hostingView
        self.hostingView = hostingView
    }
    
    func setUnlockAction(_ action: @escaping @MainActor () -> Void) {
        self.onUnlock = action
        setupContent() // Refresh with new action
    }
    
    func positionRelativeTo(window: NSWindow) {
        // Position at top-right corner of the main window
        let mainFrame = window.frame
        let x = mainFrame.maxX - 98
        let y = mainFrame.maxY - 44
        self.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

struct UnlockButtonView: View {
    let onUnlock: () -> Void
    @State private var isHovered: Bool = false
    
    var body: some View {
        Button(action: onUnlock) {
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text("Unlock")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.orange.opacity(isHovered ? 0.9 : 0.7))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .frame(width: 90, height: 36)
        .help("Click to unlock the window and restore normal interaction (⌘L)")
    }
}

/// Manages the unlock button window lifecycle
@MainActor
final class UnlockButtonWindowController {
    static let shared = UnlockButtonWindowController()

    private var unlockWindow: UnlockButtonWindow?
    private var windowObservers: [any NSObjectProtocol] = []
    private var mainWindow: NSWindow?

    private init() {}

    func show(relativeTo window: NSWindow, onUnlock: @escaping @MainActor () -> Void) {
        if unlockWindow == nil {
            unlockWindow = UnlockButtonWindow()
        }

        unlockWindow?.setUnlockAction(onUnlock)
        unlockWindow?.positionRelativeTo(window: window)
        unlockWindow?.orderFront(nil)

        mainWindow = window

        // Track the window so the button rides along with it. Both tokens are kept:
        // an earlier version dropped the resize token on the floor, so it was never
        // removed and stacked up a duplicate observer on every show().
        windowObservers = [NSWindow.didMoveNotification, NSWindow.didResizeNotification].map { name in
            NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                // Safe: `queue: .main` guarantees this block is delivered on the main
                // thread, which is where MainActor work belongs.
                MainActor.assumeIsolated {
                    self?.updatePosition()
                }
            }
        }
    }

    func hide() {
        unlockWindow?.orderOut(nil)

        for observer in windowObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        windowObservers.removeAll()
        mainWindow = nil
    }

    private func updatePosition() {
        guard let mainWindow else { return }
        unlockWindow?.positionRelativeTo(window: mainWindow)
    }
}

