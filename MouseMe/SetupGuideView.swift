//
//  SetupGuideView.swift
//  MouseMe
//
//  Walks the user through getting connected. Shows live-detected interfaces
//  on the phone, recommends the best path, and provides copy/share buttons
//  for the exact helper command to run on the computer.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SetupGuideView: View {
    @Environment(AppState.self) private var state
    @State private var interfaces: [NetworkInterface] = []
    @State private var refreshToken = 0

    private let port: UInt16 = 8237

    var body: some View {
        List {
            Section {
                Text("Pick the path that fits your computer. The Mac path needs no script at all.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Easiest — Run MouseMe on your Mac", systemImage: "laptopcomputer")
                        .font(.headline)
                        .foregroundStyle(.tint)
                    Text("MouseMe is a single project that builds for **both** iPhone and Mac. Install the Mac version once and the phone discovers it automatically — no Python, no terminal.")
                        .font(.callout)
                }
                .padding(.vertical, 4)
            }

            Section("On your Mac — install MouseMe") {
                numbered(1, "Copy the project to your Mac. Easiest: AirDrop the whole `MouseMe` folder, or download from GitHub. Keep it somewhere persistent like `~/Developer/MouseMe`.")
                numbered(2, "Install **Xcode** from the Mac App Store if you don't already have it (it's free).")
                numbered(3, "Open `MouseMe.xcodeproj` by double-clicking it. Xcode launches with the project loaded.")
                numbered(4, "At the top of the Xcode window, click the scheme/destination chooser and pick **My Mac** (it shows your Mac's name).")
                numbered(5, "Press **⌘R** (or click the ▶︎ play button). Xcode builds and launches MouseMe. The first build downloads dependencies and takes a minute.")
                numbered(6, "When MouseMe opens on your Mac, leave the **Receiving** switch turned on. macOS will prompt for **Accessibility** permission the first time — click **Open Settings**, find MouseMe in the list, and toggle it on.")
                Text("That's it on the Mac side. The window shows `Listening on port 8237` and your Mac's IP. Keep this app running.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("On your iPhone — connect to your Mac") {
                numbered(1, "Make sure the Mac and the iPhone are on the **same Wi-Fi network**. A guest or client-isolated network won't work.")
                numbered(2, "On the previous screen (**Connect**), look under **Computers nearby**. Your Mac shows up automatically, named something like “MouseMe Ryan’s Mac”. Tap it.")
                numbered(3, "First time only: iOS asks for **Local Network** permission. Allow it. If you said no by accident, use the **Open Settings** button up top to fix it.")
                numbered(4, "Status changes to **Connected**. Now switch to the **Mouse** tab and start moving the cursor — by touch, gyro, or sliding the phone on the desk.")
                Text("If the Mac doesn’t appear automatically, tap **Add manually** below and type the IP shown in the MouseMe app on the Mac.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Windows / Linux — get the helper onto your computer") {
                if let url = bundledScriptURL {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AirDrop the helper script to your Mac (or save to iCloud Drive / email it to a Windows or Linux machine). After AirDrop it lands in `~/Downloads/mouseme_server.py`, which the commands below already point at — no path errors.")
                            .font(.footnote)
                        ShareLink(item: url) {
                            Label("Send helper script to computer", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 4)
                } else {
                    Text("Helper script not bundled. You can also grab it from the project's `Server/` folder.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Text("Install Python dependencies once:")
                    .font(.footnote)
                CommandRow(text: "pip3 install pyautogui zeroconf qrcode bleak")
            }

            Section("This phone's active networks") {
                if interfaces.isEmpty {
                    Text("No active IPv4 interfaces. Connect to Wi-Fi or turn on Personal Hotspot.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ForEach(interfaces) { ifc in
                    HStack {
                        Label(ifc.kind.label, systemImage: ifc.kind.symbol)
                        Spacer()
                        Text(ifc.ip)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                Button {
                    refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }

            // Best option 1 — Personal Hotspot (works with no router at all,
            // and over USB if you plug the phone in).
            if let hp = interfaces.first(where: { $0.kind == .hotspot }) {
                method(
                    title: "Personal Hotspot (recommended)",
                    icon: "personalhotspot",
                    tint: .blue,
                    summary: "Personal Hotspot is on. Join “\(MouseClient.deviceName())” from your computer's Wi-Fi (or just plug in via USB — works without Wi-Fi).",
                    steps: [
                        "Tap “Start host on this phone” on the previous screen.",
                        "On your computer, join the phone's hotspot or plug in via USB-C / Lightning.",
                        "Run this on your computer (after AirDropping the script with Step 1 above):"
                    ],
                    command: "python3 ~/Downloads/mouseme_server.py --connect \(hp.ip):\(port)"
                )
            } else {
                method(
                    title: "Personal Hotspot (no router needed)",
                    icon: "personalhotspot",
                    tint: .blue,
                    summary: "Phone makes its own network. iOS only lets you turn this on manually — open Settings → Personal Hotspot and enable “Allow Others to Join”. USB tether works too.",
                    steps: [
                        "iOS Settings → Personal Hotspot → Allow Others to Join.",
                        "On your computer, join the phone's hotspot or plug in via USB.",
                        "Come back here and tap “Start host on this phone”.",
                        "Then on your computer run (after AirDropping the script with Step 1 above):"
                    ],
                    command: "python3 ~/Downloads/mouseme_server.py --host"
                )
            }

            // Best option 2 — same Wi-Fi
            if let wifi = interfaces.first(where: { $0.kind == .wifi }) {
                method(
                    title: "Same Wi-Fi network",
                    icon: "wifi",
                    tint: .green,
                    summary: "Phone is on Wi-Fi at \(wifi.ip). Computer should be on the same Wi-Fi (not a guest network — those usually block device-to-device traffic).",
                    steps: [
                        "Run this on your computer (after AirDropping the script with Step 1 above):",
                    ],
                    command: "python3 ~/Downloads/mouseme_server.py"
                )
            } else {
                method(
                    title: "Same Wi-Fi network",
                    icon: "wifi",
                    tint: .green,
                    summary: "Connect this phone to Wi-Fi first.",
                    steps: ["Then run on your computer:"],
                    command: "python3 ~/Downloads/mouseme_server.py"
                )
            }

            // Bluetooth — no Wi-Fi at all
            method(
                title: "Bluetooth LE (no Wi-Fi at all)",
                icon: "dot.radiowaves.left.and.right",
                tint: .purple,
                summary: "Lower throughput than Wi-Fi but works completely off-grid. Tap Pair via Bluetooth on the previous screen, then run:",
                steps: [],
                command: "python3 ~/Downloads/mouseme_server.py --bluetooth"
            )

            Section("First-time computer setup") {
                Text("macOS: grant Terminal / Python “Accessibility” in System Settings → Privacy & Security → Accessibility so the helper can move the cursor.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("How to connect")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { refresh() }
        #if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            refresh()
        }
        #endif
    }

    /// URL of the bundled helper script; `nil` if (for any reason) it isn't
    /// in the app bundle on this build.
    private var bundledScriptURL: URL? {
        Bundle.main.url(forResource: "mouseme_server", withExtension: "py")
    }

    private func refresh() {
        interfaces = NetworkScout.interfaces()
        refreshToken &+= 1
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•").foregroundStyle(.secondary)
            Text(text)
        }
    }

    private func numbered(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(n)")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.accentColor))
            Text(.init(text))
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func method(title: String,
                        icon: String,
                        tint: Color,
                        summary: String,
                        steps: [String],
                        command: String) -> some View {        Section {
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: icon)
                    .font(.headline)
                    .foregroundStyle(tint)
                Text(summary)
                    .font(.callout)
                ForEach(steps.indices, id: \.self) { i in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(i + 1).").foregroundStyle(.secondary)
                        Text(steps[i])
                    }
                    .font(.footnote)
                }
                CommandRow(text: command)
            }
            .padding(.vertical, 4)
        }
    }
}

/// One-line monospaced command with Copy + Share buttons.
struct CommandRow: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                Text(text)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
            }
            .background(
                RoundedRectangle(cornerRadius: 8).fill(.quaternary)
            )

            HStack(spacing: 12) {
                Button {
                    #if canImport(UIKit)
                    UIPasteboard.general.string = text
                    Haptics.success()
                    #endif
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)

                ShareLink(item: text) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

#Preview {
    NavigationStack { SetupGuideView() }.environment(AppState())
}
