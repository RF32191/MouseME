//
//  DeskSlideEngine.swift
//  MouseMe
//
//  Portrait, screen-up desk slide. Uses accelerometer on the desk plane
//  with one-way strokes (push only, no decel snap-back). Gyro is not used.
//

import Foundation
import Observation
#if canImport(CoreMotion)
import CoreMotion
#endif

@Observable
final class DeskSlideEngine {
    private(set) var isAvailable: Bool = false
    private(set) var isRunning: Bool = false
    private(set) var stationary: Bool = true

    var sensitivity: Double = 1.5
    var invertX: Bool = false
    var invertY: Bool = false

    private weak var client: MouseClient?

    #if canImport(CoreMotion) && os(iOS)
    private let manager = CMMotionManager()
    private let updateHz: Double = 120.0

    private var emaSX: Double = 0
    private var emaSY: Double = 0
    private var deltaFilter = MoveDeltaFilter(smoothness: 0.50, stillThreshold: 0.035, emitThreshold: 0.26)

    private var lastTimestamp: TimeInterval = 0
    private var stillAccum: TimeInterval = 0

    private var biasX: Double = 0
    private var biasY: Double = 0
    private var biasSamples: Int = 0
    private let biasWarmupSamples = 40

    private var strokeSignX: Int = 0
    private var strokeSignY: Int = 0
    private var strokeActive: Bool = false

    private let emaAlpha: Double = 0.38
    private let moveGain: Double = 0.33
    private let motionStart: Double = 0.08
    private let stillAccel: Double = 0.058
    private let pxPerMeter: Double = 9600.0
    private let stillHold: Double = 0.065
    private let flatGravityZ: Double = 0.50
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
        manager.deviceMotionUpdateInterval = 1.0 / updateHz
        snapStop()
        biasX = 0; biasY = 0; biasSamples = 0
        lastTimestamp = 0
        stillAccum = 0
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
        #endif
    }

    func recenter() {
        #if canImport(CoreMotion) && os(iOS)
        snapStop()
        biasSamples = 0
        biasX = 0; biasY = 0
        stillAccum = 0
        #endif
    }

    #if canImport(CoreMotion) && os(iOS)
    private func snapStop() {
        emaSX = 0
        emaSY = 0
        strokeSignX = 0
        strokeSignY = 0
        strokeActive = false
        deltaFilter.reset()
        stillAccum = 0
        stationary = true
    }

    private func adaptBias(_ sx: Double, _ sy: Double) {
        biasX = biasX * 0.996 + sx * 0.004
        biasY = biasY * 0.996 + sy * 0.004
    }

    private func signOf(_ v: Double) -> Int {
        if v > 0.02 { return 1 }
        if v < -0.02 { return -1 }
        return 0
    }

    private func aligned(_ value: Double, strokeSign: Int) -> Double {
        guard strokeSign != 0, signOf(value) == strokeSign else { return 0 }
        return value
    }

    /// Portrait, screen up: device +X = slide right, device +Y = slide toward top of phone.
    private func portraitDeskAccel(_ motion: CMDeviceMotion) -> (x: Double, y: Double)? {
        let ua = motion.userAcceleration
        let g = motion.gravity
        guard g.z < -flatGravityZ else { return nil }

        let dot = ua.x * g.x + ua.y * g.y + ua.z * g.z
        let px = ua.x - dot * g.x
        let py = ua.y - dot * g.y
        return (px * 9.80665, py * 9.80665)
    }

    private func armStroke(rawX: Double, rawY: Double) {
        strokeSignX = 0
        strokeSignY = 0
        if abs(rawX) >= abs(rawY) * 0.35 { strokeSignX = signOf(rawX) }
        if abs(rawY) >= abs(rawX) * 0.35 { strokeSignY = signOf(rawY) }
        if strokeSignX != 0 || strokeSignY != 0 {
            strokeActive = true
            stationary = false
        }
    }

    private func process(motion: CMDeviceMotion) {
        let now = motion.timestamp
        var dt = lastTimestamp == 0 ? (1.0 / updateHz) : (now - lastTimestamp)
        lastTimestamp = now
        if dt <= 0 || dt > 0.1 { dt = 1.0 / updateHz }

        guard let (sx, sy) = portraitDeskAccel(motion) else {
            if !stationary { snapStop() }
            return
        }

        if biasSamples < biasWarmupSamples {
            biasX += sx
            biasY += sy
            biasSamples += 1
            if biasSamples == biasWarmupSamples {
                biasX /= Double(biasWarmupSamples)
                biasY /= Double(biasWarmupSamples)
            }
            return
        }

        let cx = sx - biasX
        let cy = sy - biasY
        let rawMag = (cx * cx + cy * cy).squareRoot()

        if rawMag < stillAccel {
            stillAccum += dt
            emaSX *= 0.4
            emaSY *= 0.4
            if stillAccum >= stillHold {
                snapStop()
                adaptBias(sx, sy)
            }
            return
        }
        stillAccum = 0

        if stationary {
            if rawMag < motionStart { return }
            armStroke(rawX: cx, rawY: cy)
            guard strokeActive else { return }
        }

        emaSX = emaSX * (1 - emaAlpha) + cx * emaAlpha
        emaSY = emaSY * (1 - emaAlpha) + cy * emaAlpha

        let pushX = aligned(emaSX, strokeSign: strokeSignX)
        let pushY = aligned(emaSY, strokeSign: strokeSignY)
        let pushMag = (pushX * pushX + pushY * pushY).squareRoot()
        if pushMag < stillAccel {
            snapStop()
            adaptBias(sx, sy)
            return
        }

        // Portrait desk plane — slide right → cursor right, slide toward top → cursor up.
        var dxp = -pushX * dt * pxPerMeter * sensitivity * moveGain
        var dyp = -pushY * dt * pxPerMeter * sensitivity * moveGain
        if invertX { dxp = -dxp }
        if invertY { dyp = -dyp }

        guard let out = deltaFilter.push(rawDx: dxp, rawDy: dyp) else { return }
        client?.send(.move(dx: out.dx, dy: out.dy))
    }
    #endif
}
