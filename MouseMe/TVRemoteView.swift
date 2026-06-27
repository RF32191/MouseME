//
//  TVRemoteView.swift
//  MouseMe
//
//  Multi-layout TV remote with one-tap TV discovery.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum TVRemoteLayout: String, CaseIterable, Identifiable {
    case universal
    case appleTV
    case roku
    case simple

    var id: String { rawValue }

    var title: String {
        switch self {
        case .universal: return "Universal"
        case .appleTV:   return "Apple TV"
        case .roku:      return "Roku"
        case .simple:    return "Simple"
        }
    }

    var symbol: String {
        switch self {
        case .universal: return "rectangle.grid.2x2"
        case .appleTV:   return "appletvremote.gen1"
        case .roku:      return "tv"
        case .simple:    return "circle.grid.3x3"
        }
    }
}

struct TVRemoteView: View {
    @Environment(AppState.self) private var state
    @State private var layout: TVRemoteLayout = Self.savedLayout
    @State private var discovery = TVDiscovery()
    @State private var selectedTV: String = UserDefaults.standard.string(forKey: Self.tvIPKey) ?? ""
    @State private var manualIP = ""

    private static let tvIPKey = "MouseMe.selectedTVIP"
    private static let layoutKey = "MouseMe.tvRemoteLayout"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    discoverySection
                    layoutPicker
                    remoteBody
                }
                .padding()
            }
            .appScreenBackground()
            .navigationTitle("TV Remote")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    // MARK: - Chrome

    private var header: some View {
        VStack(spacing: 4) {
            Image(systemName: "tv")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.tint)
            Text(state.client.isConnected ? "Ready — commands go through your Mac" : "Connect to your Mac first")
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.labelSecondary)
            if !selectedTV.isEmpty {
                Label(selectedTV, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.success)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var discoverySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Find your TV").font(.headline)
                Spacer()
                Button {
                    Task { await discovery.scan() }
                } label: {
                    if discovery.isScanning {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Find TVs", systemImage: "antenna.radiowaves.left.and.right")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(discovery.isScanning || !state.client.isConnected)
            }

            Text(.init(discovery.status))
                .font(.caption)
                .foregroundStyle(AppTheme.labelTertiary)

            if !discovery.devices.isEmpty {
                ForEach(discovery.devices) { tv in
                    Button {
                        selectTV(tv)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tv.name).font(.body.weight(.medium))
                                Text(tv.ip).font(.caption.monospaced()).foregroundStyle(AppTheme.labelTertiary)
                            }
                            Spacer()
                            if selectedTV == tv.ip {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.success)
                            } else {
                                Text("Use").font(.caption.weight(.semibold))
                            }
                        }
                        .padding(12)
                        .background(AppTheme.cardRaised, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                TextField("Or enter IP (192.168.1.50)", text: $manualIP)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .textFieldStyle(.roundedBorder)
                    .font(.caption.monospaced())
                Button("Set") {
                    let ip = manualIP.trimmingCharacters(in: .whitespaces)
                    guard !ip.isEmpty else { return }
                    selectTV(DiscoveredTV(id: ip, name: "Manual (\(ip))", ip: ip))
                }
                .buttonStyle(.bordered)
                .disabled(manualIP.trimmingCharacters(in: .whitespaces).isEmpty || !state.client.isConnected)
            }
        }
        .padding(14)
        .appCard(radius: 16)
    }

    private var layoutPicker: some View {
        Picker("Layout", selection: $layout) {
            ForEach(TVRemoteLayout.allCases) { l in
                Label(l.title, systemImage: l.symbol).tag(l)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: layout) { _, new in
            UserDefaults.standard.set(new.rawValue, forKey: Self.layoutKey)
        }
    }

    @ViewBuilder
    private var remoteBody: some View {
        switch layout {
        case .universal: UniversalTVRemote(send: send, haptic: haptic)
        case .appleTV:   AppleTVRemote(send: send, haptic: haptic)
        case .roku:      RokuTVRemote(send: send, haptic: haptic)
        case .simple:    SimpleTVRemote(send: send, haptic: haptic)
        }
    }

    // MARK: - Actions

    private func selectTV(_ tv: DiscoveredTV) {
        selectedTV = tv.ip
        UserDefaults.standard.set(tv.ip, forKey: Self.tvIPKey)
        state.client.send(.tvConfig(host: tv.ip))
        haptic()
    }

    private func send(_ cmd: TVCommand) {
        state.client.send(.tv(cmd))
    }

    private func haptic() {
        #if canImport(UIKit)
        if state.hapticsEnabled {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        #endif
    }

    private static var savedLayout: TVRemoteLayout {
        guard let raw = UserDefaults.standard.string(forKey: layoutKey),
              let l = TVRemoteLayout(rawValue: raw) else { return .universal }
        return l
    }
}

// MARK: - Shared controls

private struct TVIconButton: View {
    let label: String
    let system: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: system).font(.title2)
                Text(label).font(.caption2)
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .padding(.vertical, 6)
            .background(tint.opacity(0.15))
            .foregroundStyle(tint)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

private struct TVDpad: View {
    let send: (TVCommand) -> Void
    let haptic: () -> Void
    var size: CGFloat = 72

    var body: some View {
        VStack(spacing: 8) {
            dpadBtn("chevron.up", .up)
            HStack(spacing: 8) {
                dpadBtn("chevron.left", .left)
                Button { send(.ok); haptic() } label: {
                    Text("OK").font(.title3.bold())
                        .frame(width: size, height: size)
                        .background(.tint.opacity(0.18))
                        .foregroundStyle(.tint)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                dpadBtn("chevron.right", .right)
            }
            dpadBtn("chevron.down", .down)
        }
    }

    private func dpadBtn(_ icon: String, _ cmd: TVCommand) -> some View {
        Button { send(cmd); haptic() } label: {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .frame(width: size, height: size)
                .background(.tint.opacity(0.12))
                .foregroundStyle(.tint)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Layouts

private struct UniversalTVRemote: View {
    let send: (TVCommand) -> Void
    let haptic: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                TVIconButton(label: "Power", system: "power", tint: .red) { send(.power); haptic() }
                TVIconButton(label: "Back", system: "arrow.uturn.backward", tint: .gray) { send(.back); haptic() }
                TVIconButton(label: "Home", system: "house.fill", tint: .accentColor) { send(.home); haptic() }
            }
            TVDpad(send: send, haptic: haptic)
            HStack(spacing: 12) {
                TVIconButton(label: "Rev", system: "backward.fill", tint: .gray) { send(.rev); haptic() }
                TVIconButton(label: "Play", system: "playpause.fill", tint: .accentColor) { send(.play); haptic() }
                TVIconButton(label: "Fwd", system: "forward.fill", tint: .gray) { send(.fwd); haptic() }
            }
            HStack(spacing: 12) {
                TVIconButton(label: "Vol+", system: "speaker.plus.fill", tint: .blue) { send(.volumeUp); haptic() }
                TVIconButton(label: "Mute", system: "speaker.slash.fill", tint: .orange) { send(.mute); haptic() }
                TVIconButton(label: "Vol−", system: "speaker.minus.fill", tint: .blue) { send(.volumeDown); haptic() }
            }
        }
    }
}

private struct RokuTVRemote: View {
    let send: (TVCommand) -> Void
    let haptic: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                TVIconButton(label: "Power", system: "power", tint: .red) { send(.power); haptic() }
                TVIconButton(label: "Back", system: "arrow.uturn.backward", tint: .gray) { send(.back); haptic() }
                TVIconButton(label: "Home", system: "house.fill", tint: .purple) { send(.home); haptic() }
            }
            TVDpad(send: send, haptic: haptic, size: 78)
            HStack(spacing: 12) {
                TVIconButton(label: "Replay", system: "arrow.counterclockwise", tint: .gray) { send(.replay); haptic() }
                TVIconButton(label: "Play", system: "playpause.fill", tint: .purple) { send(.play); haptic() }
                TVIconButton(label: "Info", system: "info.circle", tint: .gray) { send(.info); haptic() }
            }
            HStack(spacing: 12) {
                TVIconButton(label: "Ch+", system: "chevron.up", tint: .gray) { send(.channelUp); haptic() }
                TVIconButton(label: "Search", system: "magnifyingglass", tint: .gray) { send(.search); haptic() }
                TVIconButton(label: "Ch−", system: "chevron.down", tint: .gray) { send(.channelDown); haptic() }
            }
            HStack(spacing: 12) {
                TVIconButton(label: "Vol+", system: "speaker.wave.3.fill", tint: .blue) { send(.volumeUp); haptic() }
                TVIconButton(label: "Mute", system: "speaker.slash.fill", tint: .orange) { send(.mute); haptic() }
                TVIconButton(label: "Vol−", system: "speaker.wave.1.fill", tint: .blue) { send(.volumeDown); haptic() }
            }
        }
    }
}

private struct SimpleTVRemote: View {
    let send: (TVCommand) -> Void
    let haptic: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            TVDpad(send: send, haptic: haptic, size: 88)
            HStack(spacing: 16) {
                TVIconButton(label: "Home", system: "house.fill", tint: .accentColor) { send(.home); haptic() }
                TVIconButton(label: "Back", system: "arrow.uturn.backward", tint: .gray) { send(.back); haptic() }
            }
            HStack(spacing: 16) {
                TVIconButton(label: "Vol+", system: "plus", tint: .blue) { send(.volumeUp); haptic() }
                TVIconButton(label: "Vol−", system: "minus", tint: .blue) { send(.volumeDown); haptic() }
            }
        }
        .padding(.top, 8)
    }
}

private struct AppleTVRemote: View {
    let send: (TVCommand) -> Void
    let haptic: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Siri Remote–style touch surface
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(colors: [Color(white: 0.22), Color(white: 0.12)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .frame(height: 280)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "hand.point.up.left.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.35))
                        Text("Swipe for directions · Tap for OK")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.45))
                    }
                )
                .gesture(
                    DragGesture(minimumDistance: 12)
                        .onEnded { v in
                            let dx = v.translation.width
                            let dy = v.translation.height
                            if max(abs(dx), abs(dy)) < 12 {
                                send(.ok); haptic(); return
                            }
                            if abs(dx) > abs(dy) {
                                send(dx > 0 ? .right : .left)
                            } else {
                                send(dy > 0 ? .down : .up)
                            }
                            haptic()
                        }
                )

            HStack(spacing: 24) {
                Button { send(.back); haptic() } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.title2)
                        Text("Menu").font(.caption2)
                    }
                    .frame(width: 72, height: 56)
                }
                .buttonStyle(.plain)

                Button { send(.play); haptic() } label: {
                    Image(systemName: "playpause.fill")
                        .font(.title)
                        .frame(width: 64, height: 64)
                        .background(Circle().fill(.tint.opacity(0.2)))
                }
                .buttonStyle(.plain)

                Button { send(.home); haptic() } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "tv").font(.title2)
                        Text("Home").font(.caption2)
                    }
                    .frame(width: 72, height: 56)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 40) {
                Button { send(.volumeDown); haptic() } label: {
                    Image(systemName: "speaker.minus.fill").font(.title2)
                }
                .buttonStyle(.plain)
                Button { send(.volumeUp); haptic() } label: {
                    Image(systemName: "speaker.plus.fill").font(.title2)
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationStack {
        TVRemoteView()
            .environment(AppState())
    }
}
