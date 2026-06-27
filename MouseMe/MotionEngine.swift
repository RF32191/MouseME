//
//  MotionEngine.swift
//  MouseMe
//
//  Translates phone attitude / rotation rate into mouse delta events.
//  Uses CoreMotion. iOS only — on other platforms it's a no-op shim.
//

import Foundation
import Observation
#if canImport(CoreMotion)
import CoreMotion
#endif

@Observable
final class MotionEngine {
    private(set) var isAvailable: Bool = false
    private(set) var isRunning: Bool = false
    var sensitivity: Double = 1.5
    var invertX: Bool = false
    var invertY: Bool = false

    private weak var client: MouseClient?

    #if canImport(CoreMotion) && os(iOS)
    private let manager = CMMotionManager()
    private var filteredYaw: Double = 0
    private var filteredPitch: Double = 0
    private var deltaFilter = MoveDeltaFilter(smoothness: 0.42, stillThreshold: 0.05, emitThreshold: 0.45)
    private let filterMix: Double = 0.32
    #endif

    init(client: MouseClient) {
        self.client = client
        #if canImport(CoreMotion) && os(iOS)
        self.isAvailable = manager.isDeviceMotionAvailable
        #else
        self.isAvailable = false
        #endif
    }

    func start() {
        #if canImport(CoreMotion) && os(iOS)
        guard manager.isDeviceMotionAvailable, !isRunning else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 90.0
        filteredYaw = 0
        filteredPitch = 0
        deltaFilter.reset()
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.process(motion: motion)
        }
        isRunning = true
        #endif
    }

    func stop() {
        #if canImport(CoreMotion) && os(iOS)
        guard isRunning else { return }
        manager.stopDeviceMotionUpdates()
        isRunning = false
        filteredYaw = 0
        filteredPitch = 0
        deltaFilter.reset()
        #endif
    }

    #if canImport(CoreMotion) && os(iOS)
    private func process(motion: CMDeviceMotion) {
        // Use rotation rate for low-latency 1:1 feel.
        // yaw   (around device Y) -> horizontal cursor movement
        // pitch (around device X) -> vertical cursor movement
        let yawRate = motion.rotationRate.y      // rad/s
        let pitchRate = motion.rotationRate.x    // rad/s

        // Low-pass filter to reject high-frequency gyro noise.
        filteredYaw = filteredYaw * (1 - filterMix) + yawRate * filterMix
        filteredPitch = filteredPitch * (1 - filterMix) + pitchRate * filterMix

        let pxPerRadian = 1800.0 * sensitivity   // screen-radian gain
        let dt = manager.deviceMotionUpdateInterval

        var dx = filteredYaw * dt * pxPerRadian
        var dy = filteredPitch * dt * pxPerRadian

        if invertX { dx = -dx }
        if !invertY { dy = -dy }     // raising the phone moves cursor up

        guard let out = deltaFilter.push(rawDx: dx, rawDy: dy) else { return }
        client?.send(.move(dx: out.dx, dy: out.dy))
    }
    #endif
}
