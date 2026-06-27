import SwiftUI

/// Vertical strip used for scrolling.  Drag up to scroll up; drag down to scroll down.
struct ScrollPadView: View {

    @ObservedObject var client: WebSocketClient

    @State private var lastDragY: CGFloat?

    var body: some View {
        GeometryReader { _ in
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                    )

                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundColor(.secondary)
                    Text("Scroll")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .local)
                    .onChanged { value in
                        if let last = lastDragY {
                            // Positive dy means finger moved down → scroll down (negative amount).
                            let delta = value.location.y - last
                            client.sendScroll(amount: -(delta / 10))
                        }
                        lastDragY = value.location.y
                    }
                    .onEnded { _ in lastDragY = nil }
            )
        }
    }
}
