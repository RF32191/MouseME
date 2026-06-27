import SwiftUI

struct ContentView: View {

    @StateObject private var client = WebSocketClient()
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {

            // ── Header ──────────────────────────────────────────────────────
            HStack {
                Image(systemName: "cursorarrow.rays")
                    .font(.title2)
                    .foregroundColor(.accentColor)

                Text("MouseME")
                    .font(.title2.bold())

                Spacer()

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gear")
                        .font(.title2)
                }

                Button {
                    if client.isConnected { client.disconnect() }
                    else { client.connect() }
                } label: {
                    Image(systemName: client.isConnected ? "wifi" : "wifi.slash")
                        .font(.title2)
                        .foregroundColor(client.isConnected ? .green : .red)
                }
            }
            .padding()

            if !client.isConnected {
                notConnectedBanner
            }

            // ── Trackpad ────────────────────────────────────────────────────
            MousePadView(client: client)
                .frame(maxWidth: .infinity)
                .frame(height: 320)
                .padding(.horizontal)
                .padding(.bottom, 8)

            // ── Scroll strip ────────────────────────────────────────────────
            ScrollPadView(client: client)
                .frame(maxWidth: .infinity)
                .frame(height: 70)
                .padding(.horizontal)
                .padding(.bottom, 8)

            // ── Click buttons ───────────────────────────────────────────────
            HStack(spacing: 12) {
                clickButton(label: "Left Click",   icon: "cursorarrow") { client.sendClick() }
                clickButton(label: "Right Click",  icon: "contextualmenu.and.cursorarrow") { client.sendRightClick() }
                clickButton(label: "Double Click", icon: "hand.tap") { client.sendDoubleClick() }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(client: client)
        }
    }

    // MARK: - Sub-views

    private var notConnectedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text("Not connected — tap \(Image(systemName: "gear")) to configure the server.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    private func clickButton(
        label: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}
