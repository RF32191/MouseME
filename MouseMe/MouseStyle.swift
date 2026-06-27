//
//  MouseStyle.swift
//  MouseMe
//

import SwiftUI

enum MouseStyle: String, CaseIterable, Identifiable, Codable {
    case trackpad      // big touch surface, two-finger scroll
    case classic       // left + right + middle, scroll wheel
    case airMouse      // gyroscope move + on-screen click
    case deskSlide     // slide the phone on a desk like a real mouse
    case gaming        // higher DPI, side buttons
    case presenter     // next/prev slide + laser

    var id: String { rawValue }

    var title: String {
        switch self {
        case .trackpad:  "Trackpad"
        case .classic:   "Classic Mouse"
        case .airMouse:  "Air Mouse"
        case .deskSlide: "Desk Slide"
        case .gaming:    "Gaming"
        case .presenter: "Presenter"
        }
    }

    var symbol: String {
        switch self {
        case .trackpad:  "rectangle.and.hand.point.up.left"
        case .classic:   "computermouse"
        case .airMouse:  "gyroscope"
        case .deskSlide: "iphone.gen3.motion"
        case .gaming:    "gamecontroller"
        case .presenter: "rectangle.on.rectangle.angled"
        }
    }

    var tint: Color {
        switch self {
        case .trackpad:  .blue
        case .classic:   .gray
        case .airMouse:  .purple
        case .deskSlide: .teal
        case .gaming:    .red
        case .presenter: .orange
        }
    }

    var blurb: String {
        switch self {
        case .trackpad:  "Glide one finger to move. Tap to click, two-finger drag to scroll."
        case .classic:   "Three on-screen buttons and a scroll strip."
        case .airMouse:  "Hold the trigger and aim with the phone in the air."
        case .deskSlide: "Lay the phone flat and slide it on the desk like a real mouse."
        case .gaming:    "High DPI, low smoothing, extra side buttons."
        case .presenter: "Drive slide decks with next/prev and a virtual laser."
        }
    }

    var baseDPI: Double {
        switch self {
        case .trackpad:  1.0
        case .classic:   1.0
        case .airMouse:  1.2
        case .deskSlide: 1.0
        case .gaming:    2.2
        case .presenter: 0.8
        }
    }
}
