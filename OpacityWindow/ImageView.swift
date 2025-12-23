import SwiftUI

struct ImageView: View {
    let image: NSImage?
    @Binding var zoomScale: CGFloat
    @Binding var offset: CGSize
    let opacity: Double
    let isUIHovered: Bool
    
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(zoomScale)
                    .offset(offset)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .opacity(opacity)
                    .contentShape(Rectangle())
                    .allowsHitTesting(!isUIHovered)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                guard !isUIHovered else { return }
                                let delta = value / lastScale
                                lastScale = value
                                zoomScale = min(max(zoomScale * delta, 0.1), 10.0)
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                // Only allow dragging when UI is not hovered
                                guard !isUIHovered else { return }
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                    .onTapGesture(count: 2) {
                        guard !isUIHovered else { return }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if zoomScale != 1.0 || offset != .zero {
                                zoomScale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                zoomScale = 2.0
                            }
                        }
                    }
            } else {
                DropZonePlaceholder()
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }
}

struct DropZonePlaceholder: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundColor(.secondary)
            
            Text("Drop an image here")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
            
            Text("or use ⌘O to open")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                .foregroundColor(.secondary.opacity(0.3))
                .padding(20)
        )
    }
}

#Preview {
    ImageView(image: nil, zoomScale: .constant(1.0), offset: .constant(.zero), opacity: 1.0, isUIHovered: false)
        .frame(width: 400, height: 300)
}
