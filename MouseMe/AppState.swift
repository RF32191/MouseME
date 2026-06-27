//
//  AppState.swift
//  MouseMe
//

import Foundation
import Observation

@Observable
final class AppState {
    var client: MouseClient
    var motion: MotionEngine
    var slide: DeskSlideEngine
    var style: MouseStyle = .trackpad
    var sensitivity: Double = 1.5      // 0.25 – 4.0
    var scrollSensitivity: Double = 1.0
    var invertX: Bool = false
    var invertY: Bool = false
    var hapticsEnabled: Bool = true
    var gyroActive: Bool = false        // gyro-based cursor steering
    var slideActive: Bool = false       // desk-slide inertial cursor

    init() {
        let c = MouseClient()
        self.client = c
        self.motion = MotionEngine(client: c)
        self.slide = DeskSlideEngine(client: c)
    }
}
