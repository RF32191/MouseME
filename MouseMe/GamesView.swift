//
//  GamesView.swift
//  MouseMe
//
//  In-app games — currently an Aim Trainer driven by the phone's gyroscope.
//  Useful as a fun way to dial in sensitivity for the Air Mouse style.
//

import SwiftUI
#if canImport(CoreMotion)
import CoreMotion
#endif

struct GamesView: View {
    var body: some View {
        List {
            Section("Mini games") {
                NavigationLink {
                    AimTrainerView()
                } label: {
                    GameRow(
                        title: "Aim Trainer",
                        blurb: "Hit pop-up targets by aiming the phone. Tap to fire.",
                        systemImage: "scope",
                        tint: .red
                    )
                }
                NavigationLink {
                    ReactionRoyaleView()
                } label: {
                    GameRow(
                        title: "Reaction Royale",
                        blurb: "Tap the lit button before the timer runs out. Speeds up.",
                        systemImage: "bolt.fill",
                        tint: .yellow
                    )
                }
            }
            Section {
                Text("Both games are self-contained inside the app and do not require a helper connection.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.labelTertiary)
            }
        }
        .appListChrome()
        .navigationTitle("Games")
        .appPageChrome()
    }
}

private struct GameRow: View {
    let title: String
    let blurb: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 28))
                .foregroundStyle(tint)
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(blurb).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Aim Trainer

private struct Target: Identifiable {
    let id = UUID()
    let position: CGPoint  // unit square (0…1)
    let bornAt: Date
    let lifetime: TimeInterval
}

@MainActor
@Observable
fileprivate final class AimTrainerEngine {
    var crosshair: CGPoint = .init(x: 0.5, y: 0.5)
    var targets: [Target] = []
    var score: Int = 0
    var hits: Int = 0
    var misses: Int = 0
    var remaining: TimeInterval = 30
    var isRunning: Bool = false
    var sensitivity: Double = 1.5

    private var timerTask: Task<Void, Never>?
    private var spawnTask: Task<Void, Never>?
    private var expireTask: Task<Void, Never>?

    #if canImport(CoreMotion) && os(iOS)
    private let motion = CMMotionManager()
    private var center: CMAttitude?
    #endif

    var accuracy: Double {
        let total = hits + misses
        return total == 0 ? 0 : Double(hits) / Double(total)
    }

    func start(duration: TimeInterval = 30) {
        stop()
        crosshair = .init(x: 0.5, y: 0.5)
        targets = []
        score = 0; hits = 0; misses = 0
        remaining = duration
        isRunning = true
        startMotion()
        startTimers()
    }

    func stop() {
        isRunning = false
        timerTask?.cancel(); timerTask = nil
        spawnTask?.cancel(); spawnTask = nil
        expireTask?.cancel(); expireTask = nil
        #if canImport(CoreMotion) && os(iOS)
        if motion.isDeviceMotionActive {
            motion.stopDeviceMotionUpdates()
        }
        #endif
    }

    func fire() {
        guard isRunning else { return }
        let cx = crosshair.x
        let cy = crosshair.y
        if let idx = targets.firstIndex(where: { t in
            let dx = t.position.x - cx
            let dy = t.position.y - cy
            return (dx * dx + dy * dy).squareRoot() < 0.07
        }) {
            hits += 1
            score += 100
            targets.remove(at: idx)
            Haptics.success()
        } else {
            misses += 1
            score = max(0, score - 25)
            Haptics.warning()
        }
    }

    private func startTimers() {
        let tick = 0.1
        timerTask = Task { [weak self] in
            while let self, self.isRunning {
                try? await Task.sleep(nanoseconds: UInt64(tick * 1e9))
                self.remaining = max(0, self.remaining - tick)
                if self.remaining <= 0 { self.stop(); return }
            }
        }
        spawnTask = Task { [weak self] in
            while let self, self.isRunning {
                let delay = Double.random(in: 0.55...1.15)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1e9))
                let p = CGPoint(x: .random(in: 0.1...0.9), y: .random(in: 0.1...0.9))
                self.targets.append(Target(
                    position: p,
                    bornAt: .now,
                    lifetime: .random(in: 1.4...2.4)
                ))
            }
        }
        expireTask = Task { [weak self] in
            while let self, self.isRunning {
                try? await Task.sleep(nanoseconds: 100_000_000)
                let now = Date.now
                let before = self.targets.count
                self.targets.removeAll { now.timeIntervalSince($0.bornAt) > $0.lifetime }
                let expired = before - self.targets.count
                if expired > 0 {
                    self.misses += expired
                    self.score = max(0, self.score - 10 * expired)
                }
            }
        }
    }

    private func startMotion() {
        #if canImport(CoreMotion) && os(iOS)
        guard motion.isDeviceMotionAvailable else { return }
        center = nil
        motion.deviceMotionUpdateInterval = 1.0 / 60.0
        motion.startDeviceMotionUpdates(to: .main) { [weak self] m, _ in
            guard let self, let m else { return }
            if self.center == nil {
                self.center = m.attitude.copy() as? CMAttitude
                return
            }
            let att = m.attitude.copy() as! CMAttitude
            att.multiply(byInverseOf: self.center!)
            let gain = 1.6 * self.sensitivity
            let nx = 0.5 + att.yaw   * gain * 0.25
            let ny = 0.5 + att.pitch * gain * 0.25
            self.crosshair = .init(
                x: min(max(nx, 0.02), 0.98),
                y: min(max(ny, 0.02), 0.98)
            )
        }
        #endif
    }
}

private struct AimTrainerView: View {
    @Environment(AppState.self) private var state
    @State private var engine = AimTrainerEngine()
    @State private var showEnd = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [.black, .gray.opacity(0.6)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                // Targets
                ForEach(engine.targets) { t in
                    let age = Date.now.timeIntervalSince(t.bornAt)
                    let remaining = max(0, 1 - age / t.lifetime)
                    Circle()
                        .strokeBorder(Color.red, lineWidth: 3)
                        .background(Circle().fill(Color.red.opacity(0.35)))
                        .frame(width: 60, height: 60)
                        .position(x: t.position.x * geo.size.width,
                                  y: t.position.y * geo.size.height)
                        .opacity(0.4 + 0.6 * remaining)
                }

                // Crosshair
                Group {
                    Circle()
                        .strokeBorder(Color.green, lineWidth: 2)
                        .frame(width: 28, height: 28)
                    Rectangle().fill(Color.green).frame(width: 14, height: 2)
                    Rectangle().fill(Color.green).frame(width: 2, height: 14)
                }
                .position(x: engine.crosshair.x * geo.size.width,
                          y: engine.crosshair.y * geo.size.height)
                .allowsHitTesting(false)

                // HUD
                VStack {
                    HStack {
                        hudCard(title: "SCORE", value: "\(engine.score)")
                        Spacer()
                        hudCard(title: "TIME", value: String(format: "%.1fs", engine.remaining))
                        Spacer()
                        hudCard(title: "ACC", value: String(format: "%.0f%%", engine.accuracy * 100))
                    }
                    Spacer()
                    if !engine.isRunning {
                        Button {
                            engine.sensitivity = state.sensitivity
                            engine.start()
                        } label: {
                            Label("Start round", systemImage: "play.fill")
                                .font(.headline)
                                .padding(.horizontal, 24).padding(.vertical, 14)
                                .background(.green, in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .padding(.bottom, 30)
                    }
                }
                .padding()
            }
            .contentShape(Rectangle())
            .onTapGesture { engine.fire() }
            .navigationTitle("Aim Trainer")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onChange(of: engine.remaining) { _, new in
                if new <= 0 && !showEnd { showEnd = true }
            }
            .onDisappear { engine.stop() }
            .alert("Round over", isPresented: $showEnd) {
                Button("Done", role: .cancel) { }
                Button("Play again") {
                    engine.sensitivity = state.sensitivity
                    engine.start()
                }
            } message: {
                Text("Score \(engine.score) · Accuracy \(Int(engine.accuracy * 100))%")
            }
        }
    }

    private func hudCard(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.white.opacity(0.6))
            Text(value).font(.title3.monospacedDigit()).foregroundStyle(.white)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Reaction Royale

@MainActor
@Observable
private final class ReactionEngine {
    var litIndex: Int? = nil
    var score: Int = 0
    var bestReaction: TimeInterval? = nil
    var remaining: TimeInterval = 30
    var isRunning: Bool = false
    let buttonCount = 9

    private var task: Task<Void, Never>?
    private var litAt: Date = .now
    private var window: TimeInterval = 1.5

    func start() {
        stop()
        score = 0; bestReaction = nil
        remaining = 30; window = 1.5
        isRunning = true
        task = Task { [weak self] in
            while let self, self.isRunning {
                let idx = Int.random(in: 0..<self.buttonCount)
                self.litIndex = idx
                self.litAt = .now
                let deadline = Date.now.addingTimeInterval(self.window)
                while self.isRunning,
                      self.litIndex == idx,
                      Date.now < deadline {
                    try? await Task.sleep(nanoseconds: 30_000_000)
                    self.remaining = max(0, self.remaining - 0.03)
                    if self.remaining <= 0 { self.stop(); return }
                }
                if self.litIndex == idx {
                    // missed
                    self.score = max(0, self.score - 50)
                    self.litIndex = nil
                    Haptics.warning()
                }
                self.window = max(0.45, self.window * 0.96)
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
    }

    func stop() {
        isRunning = false
        task?.cancel(); task = nil
        litIndex = nil
    }

    func tap(_ index: Int) {
        guard isRunning, let lit = litIndex else { return }
        if index == lit {
            let dt = Date.now.timeIntervalSince(litAt)
            if bestReaction == nil || dt < bestReaction! { bestReaction = dt }
            score += max(10, Int(300 - dt * 250))
            litIndex = nil
            Haptics.click()
        } else {
            score = max(0, score - 25)
            Haptics.warning()
        }
    }
}

private struct ReactionRoyaleView: View {
    @State private var engine = ReactionEngine()
    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack {
            HStack {
                stat("SCORE", "\(engine.score)")
                Spacer()
                stat("TIME", String(format: "%.1fs", engine.remaining))
                Spacer()
                stat("BEST", engine.bestReaction.map { String(format: "%.0fms", $0 * 1000) } ?? "—")
            }
            .padding(.horizontal)

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(0..<engine.buttonCount, id: \.self) { i in
                    Button {
                        engine.tap(i)
                    } label: {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(engine.litIndex == i ? Color.yellow : Color.gray.opacity(0.2))
                            .frame(height: 100)
                            .overlay(
                                Image(systemName: engine.litIndex == i ? "bolt.fill" : "circle")
                                    .font(.title)
                                    .foregroundStyle(engine.litIndex == i ? .black : .secondary)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()

            if !engine.isRunning {
                Button {
                    engine.start()
                } label: {
                    Label("Start round", systemImage: "play.fill")
                        .font(.headline)
                        .padding(.horizontal, 24).padding(.vertical, 14)
                        .background(.green, in: Capsule())
                        .foregroundStyle(.white)
                }
                .padding(.bottom)
            }
            Spacer()
        }
        .navigationTitle("Reaction Royale")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onDisappear { engine.stop() }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.title3.monospacedDigit())
        }
    }
}

#Preview {
    GamesView().environment(AppState())
}
