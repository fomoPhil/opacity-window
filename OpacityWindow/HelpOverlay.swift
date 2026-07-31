import SwiftUI

/// Instructions panel, shown from the "?" button in the toolbar.
///
/// This is deliberately a *sibling* of ImageView in ContentView's ZStack rather
/// than a child of anything. The opacity slider dims the image, and the toolbar
/// fades itself out when the pointer leaves it. Help that inherited either of
/// those would be unreadable exactly when someone needs it, so this layer stays
/// at full opacity no matter what the rest of the window is doing.
/// Reports the natural height of the instructions so the card can shrink-wrap
/// them. A ScrollView takes every point of height it is offered, which left the
/// card with a block of dead space below the last row.
private struct ContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct HelpOverlay: View {
    var onDismiss: () -> Void

    @State private var contentHeight: CGFloat = 0

    var body: some View {
        ZStack {
            // Scrim: dims whatever image is loaded so the card always has contrast
            // to sit on, and gives a click-anywhere-to-close target.
            Color.black.opacity(0.55)
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)

            card
                .padding(20)
        }
        .transition(.opacity)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("How to use it")
                    .font(.system(size: 15, weight: .semibold))
                Spacer(minLength: 12)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close instructions")
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()

            // The window can be as small as 300x200, so this has to scroll rather
            // than assume it fits.
            ScrollView {
                VStack(alignment: .leading, spacing: 13) {
                    HelpRow(symbol: "photo.badge.plus",
                            title: "Add a reference",
                            detail: "Drag an image in, or press ⌘O.")
                    HelpRow(symbol: "circle.lefthalf.filled",
                            title: "Fade it",
                            detail: "Slide left to see through to whatever is behind.")
                    HelpRow(symbol: "lock.fill",
                            title: "Lock it to work underneath",
                            detail: "Press ⌘L. Clicks pass straight through, so you can draw in the app below while the reference stays put.")
                    HelpRow(symbol: "pin.fill",
                            title: "Floats above your work",
                            detail: "On by default, so the reference never vanishes behind the app you switch to.")
                    HelpRow(symbol: "arrow.up.left.and.arrow.down.right",
                            title: "Zoom and move",
                            detail: "Pinch or use the zoom buttons, drag to reposition, double-click to reset.")

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                            .frame(width: 16)
                        Text("Locked and stuck? Click the orange **Unlock** button at the window's top right.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 2)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
                    }
                )
            }
            // Shrink-wrap to the rows, but stay scrollable if the window is small
            // enough that they genuinely do not fit (the minimum is 300x200).
            .frame(maxHeight: contentHeight == 0 ? nil : contentHeight)
            .onPreferenceChange(ContentHeightKey.self) { contentHeight = $0 }

            Divider()

            Button("Got it", action: onDismiss)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .keyboardShortcut(.defaultAction)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
        }
        .frame(maxWidth: 360)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.35), radius: 22, y: 8)
        // Escape closes, matching every other panel on the system.
        .background(
            Button("", action: onDismiss)
                .keyboardShortcut(.cancelAction)
                .opacity(0)
        )
    }
}

private struct HelpRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 18, alignment: .center)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HelpOverlay(onDismiss: {})
        .frame(width: 520, height: 420)
}
