import SwiftUI

/// Large trackpad surface.  A single-finger drag moves the pointer.
/// A two-finger drag is reserved for the system scroll gesture.
/// A quick tap fires a left click; a long press fires a right click.
struct MousePadView: View {

    @ObservedObject var client: WebSocketClient

    @State private var lastDragLocation: CGPoint?
    @State private var isLongPressing = false

    var body: some View {
        GeometryReader { _ in
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                    )

                VStack(spacing: 6) {
                    Image(systemName: "cursorarrow.motionlines")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("Trackpad")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            // Drag → move pointer
            .gesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .local)
                    .onChanged { value in
                        if let last = lastDragLocation {
                            let dx = value.location.x - last.x
                            let dy = value.location.y - last.y
                            client.sendMove(dx: dx, dy: dy)
                        }
                        lastDragLocation = value.location
                    }
                    .onEnded { _ in lastDragLocation = nil }
            )
            // Tap → left click
            .onTapGesture {
                client.sendClick()
            }
            // Long press → right click
            .onLongPressGesture(minimumDuration: 0.5) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                client.sendRightClick()
            }
        }
    }
}
