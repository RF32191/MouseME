//
//  MacReceiverView.swift
//  MouseMe (macOS receiver)
//
//  The Mac window when MouseMe is launched on macOS. Hosts the receiver,
//  surfaces Accessibility-permission state, shows host:port + connected
//  phone, and exposes a big start/stop toggle.
//

#if os(macOS)

import SwiftUI
import AppKit

struct MacReceiverView: View {
    @State private var receiver = MacReceiver()
    @State private var accessibilityTrusted = false
    @State private var permissionTimer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if !accessibilityTrusted {
                accessibilityCard
            }

            statusCard

            if !receiver.clients.isEmpty {
                clientsCard
            }

            tvCard

            networkCard

            moreAppsCard

            Spacer(minLength: 0)
            footer
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: 600)
        .onAppear {
            accessibilityTrusted = MacEventInjector.isTrusted(prompt: false)
            // Poll Accessibility status — there's no notification when the
            // user toggles it. Cheap call, every 1.5s while visible.
            permissionTimer?.invalidate()
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
                Task { @MainActor in
                    accessibilityTrusted = MacEventInjector.isTrusted(prompt: false)
                }
            }
            receiver.start()
        }
        .onDisappear {
            permissionTimer?.invalidate()
            permissionTimer = nil
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: "cursorarrow.motionlines")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("MouseMe").font(.title.bold())
                Text("Receiver running on this Mac")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle(isOn: Binding(
                get: { isRunning },
                set: { wants in
                    if wants { receiver.start() } else { receiver.stop() }
                }
            )) {
                Text(isRunning ? "Receiving" : "Off")
            }
            .toggleStyle(.switch)
            .controlSize(.large)
        }
    }

    private var accessibilityCard: some View {
        cardBox(tint: .orange) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "exclamationmark.shield.fill")
                Text("Accessibility permission needed").bold()
            }
            Text("MouseMe needs the Accessibility permission to move the cursor and send keystrokes. Click **Open Settings**, find MouseMe in the list, and turn it on.")
                .font(.callout)
            HStack {
                Button {
                    receiver.openAccessibilitySettings()
                } label: {
                    Label("Open Settings", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.borderedProminent)
                Button("Prompt") {
                    receiver.requestAccessibility()
                }
                .help("Asks the system to add MouseMe to the Accessibility list.")
            }
        }
    }

    private var statusCard: some View {
        cardBox(tint: statusTint) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: statusSymbol)
                Text(statusTitle).bold()
            }
            switch receiver.state {
            case .listening(let port):
                Text("Phone should auto-discover this Mac on the local network. If it can't, connect manually using:")
                    .font(.callout)
                manualConnectRow(port: port)
            case .stopped:
                Text("Click the switch to start accepting connections.")
                    .font(.callout)
            case .starting:
                Text("Opening port…").font(.callout)
            case .failed(let reason):
                Text(reason).font(.callout).foregroundStyle(.red)
            }
        }
    }

    private func manualConnectRow(port: UInt16) -> some View {
        let ip = MacReceiver.bestLocalIP() ?? "(no network)"
        let target = "\(ip):\(port)"
        return HStack(spacing: 12) {
            Text(target)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(target, forType: .string)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var clientsCard: some View {
        cardBox(tint: .green) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                Text("Connected phones").bold()
            }
            ForEach(receiver.clients) { client in
                HStack {
                    VStack(alignment: .leading) {
                        Text(client.label).font(.callout.bold())
                        if let addr = client.address {
                            Text(addr)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text(client.since, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let summary = receiver.lastEventSummary {
                Divider()
                HStack {
                    Image(systemName: "waveform")
                    Text("Last: \(summary)").font(.caption)
                    Spacer()
                    Text("\(receiver.eventsThisSession) events")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var networkCard: some View {
        cardBox(tint: .blue) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "network")
                Text("How the phone finds this Mac").bold()
            }
            Text("Bonjour: `_mouseme._tcp` • Both devices must be on the same Wi-Fi (no client-isolation / guest network).")
                .font(.callout)
            if let ip = MacReceiver.bestLocalIP() {
                LabeledContent("This Mac") {
                    Text(ip).font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var tvCard: some View {
        cardBox(tint: .pink) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "tv")
                Text("TV remote target").bold()
                Spacer()
                if receiver.tv.isConfigured {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                }
            }
            Text("Phone can **Find TVs** on the TV Remote tab, or enter your Roku IP here. Roku: **Settings → Network → About**.")
                .font(.callout)
            if !receiver.tv.deviceName.isEmpty, receiver.tv.deviceName != receiver.tv.rokuIP {
                LabeledContent("Selected") {
                    Text(receiver.tv.deviceName).font(.callout)
                }
            }
            HStack {
                TextField("e.g. 192.168.1.50", text: Binding(
                    get: { receiver.tv.rokuIP },
                    set: { receiver.tv.rokuIP = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                Button("Test") {
                    receiver.tv.ping()
                }
                .buttonStyle(.bordered)
                .disabled(!receiver.tv.isConfigured)
            }
            if let result = receiver.tv.lastResult {
                Text(result).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var moreAppsCard: some View {
        cardBox(tint: .indigo) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "square.grid.2x2.fill")
                Text("More from Ryan").bold()
            }
            Text("Other apps by the same developer — open in the App Store.")
                .font(.callout)
            MoreAppsPromoView(style: .panel)
        }
    }

    private var footer: some View {
        HStack {
            Text("Privacy: events are processed locally — nothing leaves your network.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.bordered)
        }
    }

    // MARK: - Computed

    private var isRunning: Bool {
        switch receiver.state {
        case .stopped, .failed: return false
        default: return true
        }
    }

    private var statusTitle: String {
        switch receiver.state {
        case .stopped:              return "Off"
        case .starting:             return "Starting…"
        case .listening(let port):  return "Listening on port \(port)"
        case .failed:               return "Listener failed"
        }
    }

    private var statusSymbol: String {
        switch receiver.state {
        case .stopped:   return "circle.dashed"
        case .starting:  return "ellipsis.circle"
        case .listening: return "wifi"
        case .failed:    return "exclamationmark.triangle.fill"
        }
    }

    private var statusTint: Color {
        switch receiver.state {
        case .stopped:   return .secondary
        case .starting:  return .yellow
        case .listening: return .green
        case .failed:    return .red
        }
    }

    @ViewBuilder
    private func cardBox<Content: View>(tint: Color, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8, content: content)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(tint.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(tint.opacity(0.25), lineWidth: 0.5)
            )
    }
}

#endif
