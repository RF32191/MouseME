//
//  ConnectView.swift
//  MouseMe
//
//  The iPhone's "find a computer and pair" screen. Consolidated layout:
//   • Setup guide entry (top)
//   • Status (visible when active)
//   • Last device (one-tap reconnect)
//   • Computers nearby (Bonjour list + refresh)
//   • Add manually (IP/port + QR scan)
//   • More ways (Host on phone + Bluetooth)
//   • Diagnostics (link to detail screen)
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ConnectView: View {
    @Environment(AppState.self) private var state
    @State private var browser = BonjourBrowser()
    @State private var manualHost: String = ""
    @State private var manualPort: String = "8237"
    @State private var showScanner = false

    var body: some View {
        NavigationStack {
            List {
                if browser.permissionDenied {
                    Section { permissionBanner }
                }

                Section {
                    NavigationLink {
                        SetupGuideView()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("How to connect").font(.body.weight(.semibold))
                                Text("The easiest path for your computer")
                                    .font(.caption).foregroundStyle(AppTheme.labelTertiary)
                            }
                        } icon: {
                            Image(systemName: "wand.and.stars").foregroundStyle(.tint)
                        }
                    }
                }

                statusSection
                lastDeviceSection
                nearbySection
                manualSection
                moreWaysSection

                Section {
                    AppPromoBannersView()
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } header: {
                    AppSectionTitle(title:"More from Ryan")
                }

                Section {
                    NavigationLink {
                        DiagnosticsView(browser: browser)
                    } label: {
                        Label("Diagnostics", systemImage: "stethoscope")
                    }
                }
            }
            .appListChrome()
            .navigationTitle("Connect")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .appPageChrome()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if state.client.isConnected || state.client.transportKind != .none {
                        Button("Disconnect", role: .destructive) {
                            state.client.disconnect()
                        }
                    }
                }
            }
            .onAppear {
                browser.start()
                if !state.client.isConnected,
                   case .idle = state.client.status,
                   let last = MouseClient.lastTCP() {
                    state.client.connect(host: last.host, port: last.port)
                }
            }
            .onDisappear { browser.stop() }
            #if os(iOS)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                browser.refresh()
            }
            .sheet(isPresented: $showScanner) {
                QRScannerView { payload in
                    state.client.connect(host: payload.host, port: payload.port)
                    Haptics.success()
                }
            }
            #endif
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var statusSection: some View {
        if state.client.isConnected ||
            isConnectingStatus(state.client.status) ||
            state.client.transportKind != .none {
            Section("Status") {
                statusRow
                if state.client.isConnected {
                    HStack {
                        Label("Transport", systemImage: transportSymbol)
                        Spacer()
                        Text(transportName).foregroundStyle(AppTheme.labelTertiary)
                    }
                    if let ms = state.client.latencyMs {
                        HStack {
                            Label("Latency", systemImage: "speedometer")
                            Spacer()
                            Text("\(ms) ms").foregroundStyle(latencyColor(ms))
                        }
                    }
                    Button {
                        jiggleCursor()
                    } label: {
                        Label("Find cursor on screen", systemImage: "scope")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var lastDeviceSection: some View {
        if let last = MouseClient.lastTCP(), !state.client.isConnected {
            Section("Recent") {
                Button {
                    state.client.connect(host: last.host, port: last.port)
                    Haptics.success()
                } label: {
                    Label("Reconnect to \(last.host):\(last.port)",
                          systemImage: "arrow.clockwise.circle.fill")
                }
                Button(role: .destructive) {
                    MouseClient.clearLastTCP()
                } label: {
                    Label("Forget", systemImage: "xmark.circle")
                }
            }
        }
    }

    private var nearbySection: some View {
        Section {
            HStack {
                Label(browseStateLabel,
                      systemImage: browser.isBrowsing ? "wifi" : "wifi.exclamationmark")
                    .foregroundStyle(browser.isBrowsing ? Color.secondary : .orange)
                Spacer()
                Button {
                    browser.refresh()
                    Haptics.tap()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
            if browser.services.isEmpty && browser.isBrowsing {
                Text("No computers found yet. On macOS, open the MouseMe app. On Windows / Linux, run the helper script.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.labelTertiary)
            }
            ForEach(browser.services) { svc in
                Button {
                    state.client.connect(to: svc.endpoint, label: svc.name)
                    Haptics.success()
                } label: {
                    HStack {
                        Image(systemName: "desktopcomputer")
                        VStack(alignment: .leading) {
                            Text(svc.name).font(.body)
                            Text("Bonjour · _mouseme._tcp")
                                .font(.caption).foregroundStyle(AppTheme.labelTertiary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(AppTheme.labelTertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            AppSectionTitle(title:"Computers nearby")
        }
    }

    private var manualSection: some View {
        Section {
            TextField("IP address (e.g. 192.168.1.20)", text: $manualHost)
                .textFieldStyle(AppDarkFieldStyle())
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()
                #if os(iOS)
                .keyboardType(.numbersAndPunctuation)
                #endif
            TextField("Port", text: $manualPort)
                .textFieldStyle(AppDarkFieldStyle())
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
            Button {
                guard let port = UInt16(manualPort), !manualHost.isEmpty else { return }
                state.client.connect(host: manualHost, port: port)
            } label: {
                Label("Connect", systemImage: "bolt.horizontal.fill")
            }
            .disabled(manualHost.isEmpty || UInt16(manualPort) == nil)

            #if os(iOS)
            Button {
                showScanner = true
            } label: {
                Label("Scan QR code", systemImage: "qrcode.viewfinder")
            }
            #endif
        } header: {
            AppSectionTitle(title:"Add manually")
        } footer: {
            AppSectionFooterText(text:"Use the IP shown by the MouseMe Mac app or by the Python helper.")
        }
    }

    private var moreWaysSection: some View {
        Section {
            if state.client.transportKind == .host, let info = state.client.hostInfo {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Hosting at \(info.ip ?? "this phone"):\(info.port)",
                          systemImage: "wifi.router.fill")
                    if let who = info.clientLabel {
                        Text("Computer: \(who)").font(.caption).foregroundStyle(AppTheme.labelTertiary)
                    } else {
                        Text("Waiting for computer to connect…")
                            .font(.caption).foregroundStyle(AppTheme.labelTertiary)
                    }
                }
                Button(role: .destructive) {
                    state.client.disconnect()
                } label: {
                    Label("Stop hosting", systemImage: "stop.circle")
                }
            } else {
                Button {
                    state.client.startHost()
                    Haptics.success()
                } label: {
                    Label("Host on this phone", systemImage: "wifi.router")
                }
            }

            Button {
                state.client.startBluetooth()
            } label: {
                Label("Pair via Bluetooth", systemImage: "dot.radiowaves.left.and.right")
            }
            .disabled(state.client.transportKind == .ble)
        } header: {
            AppSectionTitle(title:"Other transports")
        }
    }

    // MARK: - Pieces

    @ViewBuilder
    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Local Network access is off", systemImage: "exclamationmark.shield.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            Text("MouseMe can't discover computers, host on this phone, or connect over Wi-Fi without it. Enable “Local Network” for MouseMe in Settings → Privacy & Security.")
                .font(.footnote)
                .foregroundStyle(AppTheme.labelTertiary)
            #if os(iOS)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Open Settings", systemImage: "arrow.up.right.square")
            }
            .buttonStyle(.borderedProminent)
            #endif
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusRow: some View {
        switch state.client.status {
        case .idle:
            Label("Not connected", systemImage: "circle.dashed")
                .foregroundStyle(AppTheme.labelTertiary)
        case .connecting(let label):
            Label("\(label)", systemImage: "ellipsis.circle")
        case .connected(let label):
            Label("Connected: \(label)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed(let reason):
            Label(reason, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }

    private var transportSymbol: String {
        switch state.client.transportKind {
        case .tcp:  return "wifi"
        case .host: return "wifi.router.fill"
        case .ble:  return "dot.radiowaves.left.and.right"
        case .none: return "circle.dashed"
        }
    }

    private var browseStateLabel: String {
        if browser.permissionDenied { return "Local Network blocked" }
        if browser.isBrowsing       { return "Searching…" }
        if browser.lastErrorMessage != nil { return "Stopped (tap refresh)" }
        return "Idle"
    }

    private var transportName: String {
        switch state.client.transportKind {
        case .tcp:  return "Wi-Fi"
        case .host: return "Hotspot host"
        case .ble:  return "Bluetooth"
        case .none: return "—"
        }
    }

    private func latencyColor(_ ms: Int) -> Color {
        switch ms {
        case ..<25:  return .green
        case ..<80:  return .yellow
        default:     return .orange
        }
    }

    private func isConnectingStatus(_ status: MouseClient.Status) -> Bool {
        if case .connecting = status { return true }
        if case .failed = status { return true }
        return false
    }

    private func jiggleCursor() {
        Haptics.tap()
        state.client.send(.jiggle())
        let pattern: [(Double, Double)] = [(40,0),(-80,0),(80,0),(-40,0),(0,40),(0,-80),(0,80),(0,-40)]
        var delay = 0.0
        for (dx, dy) in pattern {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                state.client.send(.move(dx: dx, dy: dy))
            }
            delay += 0.05
        }
    }
}

// MARK: - Diagnostics

private struct DiagnosticsView: View {
    let browser: BonjourBrowser

    var body: some View {
        List {
            Section("This phone") {
                LabeledContent("Local IP") {
                    Text(HostTCPTransport.bestLocalIP() ?? "no network")
                        .foregroundStyle(AppTheme.labelTertiary)
                        .monospacedDigit()
                }
            }
            Section("Bonjour") {
                LabeledContent("State") {
                    Text(browser.isBrowsing ? "Browsing" : "Idle").foregroundStyle(AppTheme.labelTertiary)
                }
                LabeledContent("Helpers found") {
                    Text("\(browser.services.count)").foregroundStyle(AppTheme.labelTertiary)
                }
                if let err = browser.lastErrorMessage {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
                Button {
                    browser.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
        .appListChrome()
        .navigationTitle("Diagnostics")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .appPageChrome()
    }
}

#Preview {
    ConnectView().environment(AppState())
}
