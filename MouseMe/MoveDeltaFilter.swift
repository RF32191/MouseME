//
//  MoveDeltaFilter.swift
//  MouseMe
//
//  Smooths pointer deltas and accumulates sub-pixel movement before emitting
//  whole-pixel events. Never zeroes an axis per-frame — that was blocking
//  slow vertical drags while still letting alternating jitter through.
//

import Foundation

enum PointerMove {
    /// Maps a touch drag step to Mac screen coordinates.
    /// iOS Y grows downward; macOS (NSEvent) Y grows upward — flip once here.
    static func fromTouch(rawDx: Double, rawDy: Double,
                          sensitivity: Double, dpi: Double = 1.0,
                          invertX: Bool, invertY: Bool) -> (dx: Double, dy: Double) {
        var dx = rawDx * sensitivity * dpi
        var dy = -rawDy * sensitivity * dpi
        if invertX { dx = -dx }
        if invertY { dy = -dy }
        return (dx, dy)
    }
}

struct MoveDeltaFilter {
    private var remainderX: Double = 0
    private var remainderY: Double = 0
    private var smoothX: Double = 0
    private var smoothY: Double = 0

    /// EMA blend for incoming deltas (0–1). Higher = snappier, lower = smoother.
    var smoothness: Double = 0.55
    /// When the smoothed value falls below this, bleed it toward zero to stop drift.
    var stillThreshold: Double = 0.06
    /// Minimum accumulated magnitude before emitting a pixel on that axis.
    var emitThreshold: Double = 0.55

    init(smoothness: Double = 0.55,
         stillThreshold: Double = 0.06,
         emitThreshold: Double = 0.55) {
        self.smoothness = smoothness
        self.stillThreshold = stillThreshold
        self.emitThreshold = emitThreshold
    }

    mutating func reset() {
        remainderX = 0
        remainderY = 0
        smoothX = 0
        smoothY = 0
    }

    mutating func push(rawDx: Double, rawDy: Double) -> (dx: Double, dy: Double)? {
        let a = smoothness
        smoothX = smoothX * (1 - a) + rawDx * a
        smoothY = smoothY * (1 - a) + rawDy * a

        if abs(smoothX) < stillThreshold { smoothX *= 0.5 }
        if abs(smoothY) < stillThreshold { smoothY *= 0.5 }

        remainderX += smoothX
        remainderY += smoothY

        var ix = 0.0
        var iy = 0.0
        if abs(remainderX) >= emitThreshold {
            ix = remainderX.rounded(.towardZero)
            remainderX -= ix
        }
        if abs(remainderY) >= emitThreshold {
            iy = remainderY.rounded(.towardZero)
            remainderY -= iy
        }

        if ix == 0, iy == 0 { return nil }
        return (ix, iy)
    }

    /// Emits any leftover fractional movement when a gesture ends.
    mutating func flush() -> (dx: Double, dy: Double)? {
        let ix = remainderX.rounded(.towardZero)
        let iy = remainderY.rounded(.towardZero)
        reset()
        if ix == 0, iy == 0 { return nil }
        return (ix, iy)
    }
}
