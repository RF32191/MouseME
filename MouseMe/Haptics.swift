//
//  Haptics.swift
//  MouseMe
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum Haptics {
    static func tap() {
        #if os(iOS)
        let g = UIImpactFeedbackGenerator(style: .light)
        g.impactOccurred()
        #endif
    }
    static func click() {
        #if os(iOS)
        let g = UIImpactFeedbackGenerator(style: .medium)
        g.impactOccurred()
        #endif
    }
    static func success() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
    static func warning() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }
}
