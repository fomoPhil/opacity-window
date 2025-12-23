import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var windowOpacity: Double = 0.95
    @State private var loadedImage: NSImage?
    @State private var zoomScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var isControlsHovered: Bool = false
    @State private var isDraggingOver: Bool = false
    @State private var isAlwaysOnTop: Bool = false
    @State private var isLocked: Bool = false
    @State private var isWindowHovered: Bool = false
    
    /// Golden yellow color for the window border
    private let goldenYellow = Color(red: 1.0, green: 0.84, blue: 0.0)
    
    /// Menu bar opacity based on hover and lock state
    private var menuBarOpacity: Double {
        if isLocked {
            return 0.0
        }
        return isControlsHovered ? 1.0 : 0.4
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.001) // Invisible but catches events
            
            // Image display area
            ImageView(
                image: loadedImage,
                zoomScale: $zoomScale,
                offset: $offset,
                opacity: windowOpacity,
                isUIHovered: isControlsHovered
            )
            
            // Controls overlay
            VStack(spacing: 12) {
                Spacer()
                
                ControlsBar(
                    opacity: $windowOpacity,
                    zoomScale: $zoomScale,
                    offset: $offset,
                    isAlwaysOnTop: $isAlwaysOnTop,
                    isLocked: $isLocked,
                    hasImage: loadedImage != nil,
                    isHovered: $isControlsHovered,
                    onOpenImage: openImagePicker,
                    onRemoveImage: removeImage
                )
                .contentShape(Rectangle())
                .allowsHitTesting(!isLocked)
                .opacity(menuBarOpacity)
                .animation(.easeInOut(duration: 0.2), value: isControlsHovered)
                .animation(.easeInOut(duration: 0.2), value: isLocked)
            }
            .padding(16)
            .allowsHitTesting(true)
            
            // Drag overlay indicator
            if isDraggingOver {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .background(Color.accentColor.opacity(0.1))
                    .padding(8)
            }
            
            // Subtle border when locked
            if isLocked {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.orange.opacity(0.4), lineWidth: 2)
                    .padding(4)
                    .allowsHitTesting(false)
            }
            
            // Hover-responsive golden yellow border
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    goldenYellow.opacity(isWindowHovered ? 0.7 : 0.15),
                    lineWidth: 2
                )
                .padding(2)
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 0.2), value: isWindowHovered)
        }
        .frame(minWidth: 300, minHeight: 200)
        .onHover { hovering in
            isWindowHovered = hovering
        }
        .windowSettings(isAlwaysOnTop: isAlwaysOnTop, isLocked: isLocked)
        .onDrop(of: [.image, .fileURL], isTargeted: $isDraggingOver) { providers in
            handleDrop(providers: providers)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openImagePicker)) { _ in
            openImagePicker()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleLock)) { _ in
            isLocked.toggle()
        }
    }
    
    private func openImagePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .png, .jpeg, .tiff, .gif, .heic, .webP]
        
        if panel.runModal() == .OK, let url = panel.url {
            loadImage(from: url)
        }
    }
    
    private func loadImage(from url: URL) {
        if let image = NSImage(contentsOf: url) {
            withAnimation(.easeInOut(duration: 0.3)) {
                loadedImage = image
                zoomScale = 1.0
                offset = .zero
            }
        }
    }
    
    private func removeImage() {
        withAnimation(.easeInOut(duration: 0.3)) {
            loadedImage = nil
            zoomScale = 1.0
            offset = .zero
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                if let data = data, let image = NSImage(data: data) {
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            loadedImage = image
                            zoomScale = 1.0
                            offset = .zero
                        }
                    }
                }
            }
            return true
        }
        
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        loadImage(from: url)
                    }
                }
            }
            return true
        }
        
        return false
    }
}

// MARK: - Controls Bar

struct ControlsBar: View {
    @Binding var opacity: Double
    @Binding var zoomScale: CGFloat
    @Binding var offset: CGSize
    @Binding var isAlwaysOnTop: Bool
    @Binding var isLocked: Bool
    var hasImage: Bool
    @Binding var isHovered: Bool
    var onOpenImage: () -> Void
    var onRemoveImage: () -> Void
    
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                // Open image button
                Button(action: onOpenImage) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 16, weight: .medium))
                }
                .buttonStyle(ControlButtonStyle())
                .help("Open Image (⌘O)")
                
                // Remove image button (only show when there's an image)
                if hasImage {
                    Button(action: onRemoveImage) {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .buttonStyle(ControlButtonStyle())
                    .help("Remove Image")
                }
                
                Divider()
                    .frame(height: 24)
                
                // Opacity controls
                HStack(spacing: 8) {
                    Image(systemName: "circle.lefthalf.filled")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Slider(value: $opacity, in: 0.05...1.0, step: 0.05)
                        .frame(width: 120)
                    
                    Text("\(Int(opacity * 100))%")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
                
                Divider()
                    .frame(height: 24)
                
                // Zoom controls
                HStack(spacing: 4) {
                    Button(action: { zoomOut() }) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .buttonStyle(ControlButtonStyle())
                    .help("Zoom Out")
                    
                    Text("\(Int(zoomScale * 100))%")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 45, alignment: .center)
                    
                    Button(action: { zoomIn() }) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .buttonStyle(ControlButtonStyle())
                    .help("Zoom In")
                    
                    Button(action: { resetZoom() }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(ControlButtonStyle())
                    .help("Reset Zoom & Position")
                }
                
                Divider()
                    .frame(height: 24)
                
                // Always on top toggle
                Button(action: { isAlwaysOnTop.toggle() }) {
                    Image(systemName: isAlwaysOnTop ? "pin.fill" : "pin")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isAlwaysOnTop ? .accentColor : .secondary)
                }
                .buttonStyle(ControlButtonStyle(isActive: isAlwaysOnTop))
                .help(isAlwaysOnTop ? "Disable Always on Top" : "Enable Always on Top")
                
                // Lock toggle (click-through mode)
                Button(action: { isLocked.toggle() }) {
                    Image(systemName: isLocked ? "lock.fill" : "lock.open")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isLocked ? .orange : .secondary)
                }
                .buttonStyle(ControlButtonStyle(isActive: isLocked))
                .help(isLocked ? "Unlock Window (⌘L)" : "Lock Window - Click Through (⌘L)")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func zoomIn() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            zoomScale = min(zoomScale * 1.25, 10.0)
        }
    }
    
    private func zoomOut() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            zoomScale = max(zoomScale / 1.25, 0.1)
        }
    }
    
    private func resetZoom() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            zoomScale = 1.0
            offset = .zero
        }
    }
}

struct ControlButtonStyle: ButtonStyle {
    var isActive: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isActive ? .accentColor : (configuration.isPressed ? .primary : .secondary))
            .frame(width: 28, height: 28)
            .background(
                Circle()
                    .fill(isActive ? Color.accentColor.opacity(0.15) : (configuration.isPressed ? Color.primary.opacity(0.1) : Color.clear))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

#Preview {
    ContentView()
        .frame(width: 600, height: 400)
}
