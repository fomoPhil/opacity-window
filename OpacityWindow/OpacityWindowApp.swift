import SwiftUI

@main
struct OpacityWindowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Image...") {
                    NotificationCenter.default.post(name: .openImagePicker, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(after: .windowArrangement) {
                Button("Toggle Lock") {
                    NotificationCenter.default.post(name: .toggleLock, object: nil)
                }
                .keyboardShortcut("l", modifiers: .command)
            }
        }
    }
}

/// Carries a file opened from Finder ("Open With", drop on Dock icon, `open -a`)
/// through to ContentView.
///
/// This is held rather than posted as a one-shot notification because on a cold
/// launch the URL arrives before ContentView exists to observe it. ContentView
/// reads any pending value in .onAppear and observes this for later opens.
final class OpenImageRequest: ObservableObject {
    static let shared = OpenImageRequest()
    @Published var url: URL?

    /// Read and clear, so the same file is not re-loaded on a later appear.
    func take() -> URL? {
        defer { url = nil }
        return url
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        // This app shows one image at a time, so honour the first and ignore the rest.
        guard let url = urls.first else { return }
        OpenImageRequest.shared.url = url
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure main window
        if let window = NSApplication.shared.windows.first {
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

extension Notification.Name {
    static let openImagePicker = Notification.Name("openImagePicker")
    static let toggleLock = Notification.Name("toggleLock")
}

