//
//  MouseSurfaceView.swift
//  MouseMe
//

import SwiftUI

struct MouseSurfaceView: View {
    @Environment(AppState.self) private var state
    @State private var showMacSetup = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                connectionBar
                sensorBar
                Rectangle().fill(AppTheme.border).frame(height: 1)
                surface
            }
            .appScreenBackground()
            .navigationTitle(state.style.title)
            .appPageChrome()
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showMacSetup = true
                    } label: {
                        Label("Mac setup", systemImage: "questionmark.circle")
                    }
                    .accessibilityLabel("Mac setup instructions")
                }
            }
            .sheet(isPresented: $showMacSetup) {
                MacSetupInstructionsView()
            }
            #endif
            .onDisappear { stopMotionSensors() }
            .onChange(of: state.client.isConnected) { _, connected in
                if !connected { stopMotionSensors() }
            }
        }
    }

    @ViewBuilder
    private var surface: some View {
        switch state.style {
        case .trackpad:  TrackpadSurface()
        case .classic:   ClassicMouseSurface()
        case .airMouse:  AirMouseSurface()
        case .deskSlide: DeskSlideSurface()
        case .gaming:    GamingSurface()
        case .presenter: PresenterSurface()
        }
    }

    private var connectionBar: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(state.client.isConnected ? AppTheme.success : AppTheme.warning)
                .frame(width: 10, height: 10)
                .shadow(color: (state.client.isConnected ? AppTheme.success : AppTheme.warning).opacity(0.5), radius: 4)
            Text(connectionLabel)
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.labelSecondary)
            Spacer()
            Image(systemName: state.style.symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(state.style.tint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppTheme.surface)
    }

    private var sensorBar: some View {
        HStack(spacing: 10) {
            SensorPill(label: "Gyro",
                       systemImage: "gyroscope",
                       isOn: state.gyroActive,
                       tint: .purple,
                       isAvailable: state.motion.isAvailable) {
                state.gyroActive.toggle()
                applyGyro()
            }

            SensorPill(label: "Slide",
                       systemImage: "iphone.gen3.motion",
                       isOn: state.slideActive,
                       tint: .teal,
                       isAvailable: state.slide.isAvailable) {
                state.slideActive.toggle()
                applySlide()
            }

            Spacer()

            if state.slideActive {
                Button {
                    state.slide.recenter()
                    if state.hapticsEnabled { Haptics.tap() }
                } label: {
                    Label("Recenter", systemImage: "scope")
                        .labelStyle(.iconOnly)
                        .font(.callout)
                        .padding(8)
                        .background(AppTheme.cardRaised, in: Circle())
                        .overlay(Circle().stroke(AppTheme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help("Reset the slide tracker. Pick the phone up, set it down, tap this.")
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 6)
    }

    private func applyGyro() {
        if state.gyroActive {
            state.motion.sensitivity = state.sensitivity * state.style.baseDPI
            state.motion.invertX = state.invertX
            state.motion.invertY = state.invertY
            state.motion.start()
            if state.hapticsEnabled { Haptics.success() }
        } else {
            state.motion.stop()
        }
    }

    private func applySlide() {
        if state.slideActive {
            state.slide.sensitivity = state.sensitivity * state.style.baseDPI
            state.slide.invertX = state.invertX
            state.slide.invertY = state.invertY
            state.slide.start()
            if state.hapticsEnabled { Haptics.success() }
        } else {
            state.slide.stop()
        }
    }

    private func stopMotionSensors() {
        state.motion.stop()
        state.slide.stop()
        state.gyroActive = false
        state.slideActive = false
    }

    private var connectionLabel: String {
        switch state.client.status {
        case .idle: "Not connected — open the Connect tab"
        case .connecting(let l): "Connecting to \(l)…"
        case .connected(let l): "Connected to \(l)"
        case .failed(let r): "Error: \(r)"
        }
    }
}

private struct SensorPill: View {
    let label: String
    let systemImage: String
    let isOn: Bool
    let tint: Color
    let isAvailable: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(label).font(.footnote.weight(.semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(isOn ? tint : AppTheme.cardRaised)
            )
            .overlay(
                Capsule().stroke(isOn ? tint.opacity(0.5) : AppTheme.border, lineWidth: 1)
            )
            .foregroundStyle(isOn ? Color.white : AppTheme.labelSecondary)
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1.0 : 0.4)
    }
}

// MARK: - Trackpad

private struct TrackpadSurface: View {
    @Environment(AppState.self) private var state
    @State private var lastPoint: CGPoint?
    @State private var fingerCount: Int = 1
    @State private var scrollAccumulator: CGFloat = 0
    @State private var moveFilter = MoveDeltaFilter()

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { geo in
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(AppTheme.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(AppTheme.borderStrong, lineWidth: 1)
                        )
                    VStack(spacing: 8) {
                        Image(systemName: "hand.point.up.left.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.accent.opacity(0.85))
                        Text("Glide to move · tap to click")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.labelTertiary)
                    }
                }
                .contentShape(Rectangle())
                .gesture(dragGesture(in: geo.size))
                .onTapGesture {
                    state.client.send(.click(.left, .click))
                    if state.hapticsEnabled { Haptics.click() }
                }
                .onTapGesture(count: 2) {
                    state.client.send(.click(.left, .click))
                    state.client.send(.click(.left, .click))
                    if state.hapticsEnabled { Haptics.click() }
                }
            }
            .padding(.horizontal)

            // Two click bars + scroll strip
            HStack(spacing: 12) {
                ClickButton(label: "Left", systemImage: "cursorarrow.click") {
                    state.client.send(.click(.left, .click))
                }
                ScrollStrip()
                    .frame(width: 60)
                ClickButton(label: "Right", systemImage: "cursorarrow.click.2") {
                    state.client.send(.click(.right, .click))
                }
            }
            .frame(height: 70)
            .padding([.horizontal, .bottom])
        }
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if let last = lastPoint {
                    let scaled = PointerMove.fromTouch(
                        rawDx: Double(value.location.x - last.x),
                        rawDy: Double(value.location.y - last.y),
                        sensitivity: state.sensitivity,
                        dpi: state.style.baseDPI,
                        invertX: state.invertX,
                        invertY: state.invertY
                    )
                    if let out = moveFilter.push(rawDx: scaled.dx, rawDy: scaled.dy) {
                        state.client.send(.move(dx: out.dx, dy: out.dy))
                    }
                }
                lastPoint = value.location
            }
            .onEnded { _ in
                if let out = moveFilter.flush() {
                    state.client.send(.move(dx: out.dx, dy: out.dy))
                }
                lastPoint = nil
            }
    }
}

private struct ScrollStrip: View {
    @Environment(AppState.self) private var state
    @State private var lastY: CGFloat?

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(AppTheme.cardRaised)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .overlay(
                VStack {
                    Image(systemName: "chevron.up")
                    Spacer()
                    Image(systemName: "arrow.up.and.down")
                        .foregroundStyle(AppTheme.labelTertiary)
                    Spacer()
                    Image(systemName: "chevron.down")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.labelSecondary)
                .padding(.vertical, 8)
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if let last = lastY {
                            let dy = Double(value.location.y - last) * state.scrollSensitivity * 0.4
                            if abs(dy) >= 0.1 {
                                state.client.send(.scroll(dx: 0, dy: -dy))
                            }
                        }
                        lastY = value.location.y
                    }
                    .onEnded { _ in lastY = nil }
            )
    }
}

// MARK: - Classic

private struct ClassicMouseSurface: View {
    @Environment(AppState.self) private var state
    @State private var lastPoint: CGPoint?
    @State private var moveFilter = MoveDeltaFilter()

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ClickButton(label: "Left", systemImage: "l.square.fill") {
                    state.client.send(.click(.left, .click))
                }
                ClickButton(label: "Middle", systemImage: "m.square.fill") {
                    state.client.send(.click(.middle, .click))
                }
                ClickButton(label: "Right", systemImage: "r.square.fill") {
                    state.client.send(.click(.right, .click))
                }
            }
            .frame(height: 90)
            .padding(.horizontal)

            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppTheme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(AppTheme.borderStrong, lineWidth: 1)
                    )
                    .overlay(
                        Text("Move pad")
                            .font(.caption.weight(.medium)).foregroundStyle(AppTheme.labelTertiary)
                    )
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if let last = lastPoint {
                                    let scaled = PointerMove.fromTouch(
                                        rawDx: Double(value.location.x - last.x),
                                        rawDy: Double(value.location.y - last.y),
                                        sensitivity: state.sensitivity,
                                        invertX: state.invertX,
                                        invertY: state.invertY
                                    )
                                    if let out = moveFilter.push(rawDx: scaled.dx, rawDy: scaled.dy) {
                                        state.client.send(.move(dx: out.dx, dy: out.dy))
                                    }
                                }
                                lastPoint = value.location
                            }
                            .onEnded { _ in
                                if let out = moveFilter.flush() {
                                    state.client.send(.move(dx: out.dx, dy: out.dy))
                                }
                                lastPoint = nil
                            }
                    )
                    .padding(.horizontal)
                    .frame(width: geo.size.width)
            }

            ScrollStrip()
                .frame(height: 70)
                .padding([.horizontal, .bottom])
        }
    }
}

// MARK: - Air mouse

private struct AirMouseSurface: View {
    @Environment(AppState.self) private var state
    @GestureState private var pressing: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .strokeBorder(state.style.tint.opacity(0.4), lineWidth: 2)
                Image(systemName: "gyroscope")
                    .font(.system(size: 80, weight: .light))
                    .foregroundStyle(state.style.tint)
                    .scaleEffect(state.motion.isRunning ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.25), value: state.motion.isRunning)
            }
            .padding(.horizontal, 40)

            Text(state.motion.isAvailable
                 ? (state.motion.isRunning ? "Aiming…" : "Hold trigger and aim")
                 : "Motion sensor unavailable on this device")
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.labelSecondary)

            // Trigger
            Text(state.motion.isRunning ? "RELEASE" : "HOLD TO AIM")
                .font(.headline.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 80)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(state.motion.isRunning ? Color.red : state.style.tint)
                )
                .padding(.horizontal)
                .gesture(
                    LongPressGesture(minimumDuration: 0.01)
                        .sequenced(before: DragGesture(minimumDistance: 0))
                        .updating($pressing) { value, st, _ in
                            switch value {
                            case .second(true, _): st = true
                            default: st = false
                            }
                        }
                )
                .onChange(of: pressing) { _, new in
                    if new {
                        state.motion.sensitivity = state.sensitivity * state.style.baseDPI
                        state.motion.invertX = state.invertX
                        state.motion.invertY = state.invertY
                        state.motion.start()
                        if state.hapticsEnabled { Haptics.tap() }
                    } else {
                        state.motion.stop()
                    }
                }

            HStack(spacing: 12) {
                ClickButton(label: "Left", systemImage: "cursorarrow.click") {
                    state.client.send(.click(.left, .click))
                }
                ClickButton(label: "Right", systemImage: "cursorarrow.click.2") {
                    state.client.send(.click(.right, .click))
                }
            }
            .frame(height: 70)
            .padding([.horizontal, .bottom])
        }
        .onDisappear { state.motion.stop() }
    }
}

// MARK: - Desk slide

private struct DeskSlideSurface: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 16) {
            // Live status card
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.cardRaised, state.style.tint.opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(state.style.tint.opacity(0.4), lineWidth: 1)
                    )
                VStack(spacing: 10) {
                    Image(systemName: state.slide.isRunning
                          ? (state.slide.stationary ? "pause.circle.fill" : "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                          : "iphone.gen3")
                        .font(.system(size: 72, weight: .light))
                        .foregroundStyle(.white)
                    Text(statusText)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Lay the phone **face up in portrait** on a flat desk. Tap Start, wait a moment, then **push** in the direction you want the cursor to go. Lift to reposition anytime.")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal)
                }
            }
            .padding(.horizontal)

            HStack(spacing: 12) {
                Button {
                    if state.slide.isRunning {
                        state.slide.stop()
                    } else {
                        state.slide.sensitivity = state.sensitivity * state.style.baseDPI
                        state.slide.invertX = state.invertX
                        state.slide.invertY = state.invertY
                        state.slide.start()
                        if state.hapticsEnabled { Haptics.success() }
                    }
                } label: {
                    Label(state.slide.isRunning ? "Stop tracking" : "Start tracking",
                          systemImage: state.slide.isRunning ? "stop.circle.fill" : "play.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(state.slide.isRunning ? Color.red : state.style.tint)
                        )
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button {
                    state.slide.recenter()
                    if state.hapticsEnabled { Haptics.tap() }
                } label: {
                    Label("Recalibrate", systemImage: "scope")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(AppTheme.cardRaised)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(AppTheme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!state.slide.isRunning)
            }
            .padding(.horizontal)

            HStack(spacing: 12) {
                ClickButton(label: "Left", systemImage: "cursorarrow.click") {
                    state.client.send(.click(.left, .click))
                }
                ClickButton(label: "Right", systemImage: "cursorarrow.click.2") {
                    state.client.send(.click(.right, .click))
                }
            }
            .frame(height: 70)
            .padding([.horizontal, .bottom])
        }
        .onDisappear { state.slide.stop() }
    }

    private var statusText: String {
        if !state.slide.isAvailable { return "Motion sensor unavailable" }
        if !state.slide.isRunning   { return "Ready" }
        return state.slide.stationary ? "Stationary (locked)" : "Sliding"
    }
}

// MARK: - Gaming

private struct GamingSurface: View {
    @Environment(AppState.self) private var state
    @State private var lastPoint: CGPoint?
    @State private var moveFilter = MoveDeltaFilter(smoothness: 0.62, emitThreshold: 0.4)

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                ClickButton(label: "Back", systemImage: "arrow.uturn.backward") {
                    state.client.send(.click(.middle, .click))
                }
                .frame(width: 90)
                GeometryReader { _ in
                    RoundedRectangle(cornerRadius: 24)
                        .fill(AppTheme.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(AppTheme.borderStrong, lineWidth: 1)
                        )
                        .overlay(Text("High-DPI Aim").font(.caption.weight(.medium)).foregroundStyle(AppTheme.labelTertiary))
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    if let last = lastPoint {
                                        let scaled = PointerMove.fromTouch(
                                            rawDx: Double(value.location.x - last.x),
                                            rawDy: Double(value.location.y - last.y),
                                            sensitivity: state.sensitivity,
                                            dpi: state.style.baseDPI,
                                            invertX: state.invertX,
                                            invertY: state.invertY
                                        )
                                        if let out = moveFilter.push(rawDx: scaled.dx, rawDy: scaled.dy) {
                                            state.client.send(.move(dx: out.dx, dy: out.dy))
                                        }
                                    }
                                    lastPoint = value.location
                                }
                                .onEnded { _ in
                                    if let out = moveFilter.flush() {
                                        state.client.send(.move(dx: out.dx, dy: out.dy))
                                    }
                                    lastPoint = nil
                                }
                        )
                }
                ClickButton(label: "Fwd", systemImage: "arrow.uturn.forward") {
                    state.client.send(.click(.middle, .click))
                }
                .frame(width: 90)
            }
            .padding(.horizontal)

            HStack(spacing: 12) {
                ClickButton(label: "Fire", systemImage: "scope") {
                    state.client.send(.click(.left, .click))
                }
                .tint(.red)
                ClickButton(label: "ADS", systemImage: "viewfinder.circle") {
                    state.client.send(.click(.right, .down))
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        state.client.send(.click(.right, .up))
                    }
                }
            }
            .frame(height: 80)
            .padding([.horizontal, .bottom])
        }
    }
}

// MARK: - Presenter

private struct PresenterSurface: View {
    @Environment(AppState.self) private var state
    @GestureState private var laserHeld: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            laserPad
                .padding(.horizontal)

            HStack(spacing: 12) {
                BigButton(title: "Prev", systemImage: "arrow.left", tint: .orange) {
                    state.client.send(.key("left"))
                }
                BigButton(title: "Next", systemImage: "arrow.right", tint: .orange) {
                    state.client.send(.key("right"))
                }
            }
            .padding(.horizontal)

            BigButton(title: "Click", systemImage: "cursorarrow.click", tint: .blue) {
                state.client.send(.click(.left, .click))
            }
            .padding([.horizontal, .bottom])
        }
        .onChange(of: laserHeld) { _, active in
            applyLaser(active: active)
        }
        .onDisappear { applyLaser(active: false) }
    }

    private var laserPad: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: laserHeld
                            ? [.red, .red.opacity(0.55)]
                            : [.red.opacity(0.65), .red.opacity(0.25)],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            VStack(spacing: 10) {
                Image(systemName: laserHeld ? "scope" : "dot.scope")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(laserHeld ? 0.9 : 0.0), radius: 14)
                    .scaleEffect(laserHeld ? 1.08 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.55), value: laserHeld)

                Text(laserHeld ? "LASER ACTIVE" : "HOLD TO POINT")
                    .font(.headline.bold())
                    .foregroundStyle(.white)

                Text(laserHeld
                     ? "Aim the phone at the screen — yaw/pitch move the cursor."
                     : "Press and hold this pad, then aim the phone like a laser pointer.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .gesture(
            LongPressGesture(minimumDuration: 0.01)
                .sequenced(before: DragGesture(minimumDistance: 0))
                .updating($laserHeld) { value, st, _ in
                    switch value {
                    case .second(true, _): st = true
                    default: st = false
                    }
                }
        )
        .overlay(alignment: .topTrailing) {
            if !state.motion.isAvailable {
                Label("Gyro unavailable", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .padding(6)
                    .background(AppTheme.cardRaised, in: Capsule())
                    .overlay(Capsule().stroke(AppTheme.border, lineWidth: 1))
                    .foregroundStyle(AppTheme.warning)
                    .padding(8)
            }
        }
    }

    private func applyLaser(active: Bool) {
        if active {
            // Higher gain for presenter use — projector / TV is usually
            // further away than the phone can sweep, so we want big motion.
            state.motion.sensitivity = state.sensitivity * state.style.baseDPI * 1.4
            state.motion.invertX = state.invertX
            state.motion.invertY = state.invertY
            state.motion.start()
            if state.hapticsEnabled { Haptics.success() }
        } else {
            state.motion.stop()
        }
    }
}

// MARK: - Shared building blocks

private struct ClickButton: View {
    let label: String
    let systemImage: String
    let action: () -> Void
    @Environment(AppState.self) private var state

    var body: some View {
        Button(action: {
            action()
            if state.hapticsEnabled { Haptics.click() }
        }) {
            VStack(spacing: 4) {
                Image(systemName: systemImage).font(.title3)
                Text(label).font(.caption2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .foregroundStyle(AppTheme.labelSecondary)
        }
        .buttonStyle(.plain)
    }
}

private struct BigButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.title3.bold())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(tint.opacity(0.85))
            )
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MouseSurfaceView().environment(AppState())
}
