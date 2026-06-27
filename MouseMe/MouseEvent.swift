//
//  MouseEvent.swift
//  MouseMe
//
//  Wire protocol shared with the desktop helper. JSON-lines over TCP.
//

import Foundation

enum MouseButton: String, Codable {
    case left, right, middle
}

enum MouseAction: String, Codable {
    case down, up, click
}

enum MediaCommand: String, Codable {
    case volumeUp        = "volume_up"
    case volumeDown      = "volume_down"
    case mute            = "mute"
    case playPause       = "play_pause"
    case next            = "next"
    case prev            = "prev"
    case brightnessUp    = "brightness_up"
    case brightnessDown  = "brightness_down"
}

/// TV remote command. Currently maps to Roku ECP keys on the receiver,
/// but the names are generic so we can route to other brands later.
enum TVCommand: String, Codable {
    case home, back, info, search
    case up, down, left, right, ok
    case play, pause, replay, fwd, rev
    case volumeUp = "vol_up", volumeDown = "vol_down", mute
    case power, powerOn = "power_on", powerOff = "power_off"
    case channelUp = "channel_up", channelDown = "channel_down"
    case input
}

struct MouseEvent: Codable {
    enum Kind: String, Codable {
        case hello
        case move
        case click
        case scroll
        case key
        case text
        case media
        case ping
        case pong
        case jiggle
        case tv
        case tvConfig
    }

    var t: Kind
    var dx: Double?
    var dy: Double?
    var button: MouseButton?
    var action: MouseAction?
    var name: String?
    var style: String?
    var key: String?
    var mods: [String]?
    var text: String?
    var cmd: MediaCommand?
    var tv: TVCommand?
    var tvHost: String?
    var id: UInt32?       // ping/pong correlation
    var ts: Double?       // ms since epoch (phone-side)

    static func hello(name: String, style: String) -> MouseEvent {
        .init(t: .hello, name: name, style: style)
    }
    static func move(dx: Double, dy: Double) -> MouseEvent {
        .init(t: .move, dx: dx, dy: dy)
    }
    static func click(_ button: MouseButton, _ action: MouseAction) -> MouseEvent {
        .init(t: .click, button: button, action: action)
    }
    static func scroll(dx: Double, dy: Double) -> MouseEvent {
        .init(t: .scroll, dx: dx, dy: dy)
    }
    static func key(_ key: String, mods: [String] = [], action: MouseAction = .click) -> MouseEvent {
        .init(t: .key, action: action, key: key, mods: mods)
    }
    static func text(_ text: String) -> MouseEvent {
        .init(t: .text, text: text)
    }
    static func media(_ cmd: MediaCommand) -> MouseEvent {
        .init(t: .media, cmd: cmd)
    }
    static func tv(_ cmd: TVCommand) -> MouseEvent {
        .init(t: .tv, tv: cmd)
    }
    static func tvConfig(host: String) -> MouseEvent {
        .init(t: .tvConfig, tvHost: host)
    }
    static func ping(id: UInt32) -> MouseEvent {
        .init(t: .ping, id: id, ts: Date().timeIntervalSince1970 * 1000)
    }
    static func jiggle() -> MouseEvent {
        .init(t: .jiggle)
    }
}
