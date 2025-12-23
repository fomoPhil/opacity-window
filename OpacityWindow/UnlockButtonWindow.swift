import SwiftUI
import AppKit

/// A small floating panel that contains the unlock button
/// This window remains clickable even when the main window ignores mouse events
class UnlockButtonWindow: NSPanel {
    private var hostingView: NSHostingView<UnlockButtonView>?
    private var onUnlock: () -> Void = {}
    
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
    
    func setUnlockAction(_ action: @escaping () -> Void) {
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
class UnlockButtonWindowController {
    static let shared = UnlockButtonWindowController()
    
    private var unlockWindow: UnlockButtonWindow?
    private var windowObserver: Any?
    private var mainWindow: NSWindow?
    
    private init() {}
    
    func show(relativeTo window: NSWindow, onUnlock: @escaping () -> Void) {
        if unlockWindow == nil {
            unlockWindow = UnlockButtonWindow()
        }
        
        unlockWindow?.setUnlockAction(onUnlock)
        unlockWindow?.positionRelativeTo(window: window)
        unlockWindow?.orderFront(nil)
        
        mainWindow = window
        
        // Observe main window position changes
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.updatePosition()
        }
        
        // Also observe resize
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.updatePosition()
        }
    }
    
    func hide() {
        unlockWindow?.orderOut(nil)
        
        if let observer = windowObserver {
            NotificationCenter.default.removeObserver(observer)
            windowObserver = nil
        }
        mainWindow = nil
    }
    
    private func updatePosition() {
        guard let mainWindow = mainWindow else { return }
        unlockWindow?.positionRelativeTo(window: mainWindow)
    }
}

