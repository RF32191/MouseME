//
//  MacEventInjector.swift
//  MouseMe (macOS receiver)
//
//  Translates inbound `MouseEvent` payloads into real input on macOS via
//  Quartz Event Services (CGEvent). Requires the user to grant Accessibility
//  permission in System Settings → Privacy & Security → Accessibility.
//

#if os(macOS)

import Foundation
import AppKit
import CoreGraphics

@MainActor
final class MacEventInjector {

    // MARK: - Permission

    /// Whether this process is trusted for Accessibility (required to post
    /// synthetic keyboard / mouse events). `prompt` shows the system dialog.
    static func isTrusted(prompt: Bool = false) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
        let opts: NSDictionary = [key: prompt]
        return AXIsProcessTrustedWithOptions(opts)
    }

    // MARK: - Mouse

    func move(dx: Double, dy: Double) {
        guard dx != 0 || dy != 0 else { return }
        // NSEvent uses bottom-left origin (+Y = up). CGWarp uses top-left (+Y = down).
        var point = NSEvent.mouseLocation
        point.x += dx
        point.y += dy
        point = clamp(point)
        CGWarpMouseCursorPosition(quartzPoint(from: point))
    }

    /// Convert global Cocoa screen coords → Quartz coords for CGWarpMouseCursorPosition.
    private func quartzPoint(from cocoa: NSPoint) -> CGPoint {
        let primaryMaxY = NSScreen.screens.map(\.frame.maxY).max() ?? NSScreen.main?.frame.maxY ?? 0
        return CGPoint(x: cocoa.x, y: primaryMaxY - cocoa.y)
    }

    func click(_ button: MouseButton, action: MouseAction) {
        let loc = CGEvent(source: nil)?.location ?? .zero
        let cgButton: CGMouseButton
        let down: CGEventType
        let up: CGEventType
        switch button {
        case .left:
            cgButton = .left
            down = .leftMouseDown
            up = .leftMouseUp
        case .right:
            cgButton = .right
            down = .rightMouseDown
            up = .rightMouseUp
        case .middle:
            cgButton = .center
            down = .otherMouseDown
            up = .otherMouseUp
        }
        switch action {
        case .down:
            post(down, at: loc, button: cgButton)
        case .up:
            post(up, at: loc, button: cgButton)
        case .click:
            post(down, at: loc, button: cgButton)
            post(up, at: loc, button: cgButton)
        }
    }

    func scroll(dx: Double, dy: Double) {
        // Quartz uses inverted Y for natural scrolling expectations. We pass
        // the raw deltas through; macOS user-prefs apply natural-scroll flip.
        guard let event = CGEvent(scrollWheelEvent2Source: nil,
                                  units: .pixel,
                                  wheelCount: 2,
                                  wheel1: Int32(dy.rounded()),
                                  wheel2: Int32(dx.rounded()),
                                  wheel3: 0) else { return }
        event.post(tap: .cghidEventTap)
    }

    private func post(_ type: CGEventType, at point: CGPoint, button: CGMouseButton) {
        guard let event = CGEvent(mouseEventSource: nil,
                                  mouseType: type,
                                  mouseCursorPosition: point,
                                  mouseButton: button) else { return }
        event.post(tap: .cghidEventTap)
    }

    private func clamp(_ p: CGPoint) -> CGPoint {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(p) })
                          ?? NSScreen.main else { return p }
        let f = screen.frame
        return CGPoint(x: min(max(p.x, f.minX), f.maxX - 1),
                       y: min(max(p.y, f.minY), f.maxY - 1))
    }

    // MARK: - Keyboard

    func type(_ string: String) {
        for scalar in string.unicodeScalars {
            postUnicode(scalar)
        }
    }

    private func postUnicode(_ scalar: Unicode.Scalar) {
        var ch = UniChar(scalar.value & 0xFFFF)
        if let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) {
            down.keyboardSetUnicodeString(stringLength: 1, unicodeString: &ch)
            down.post(tap: .cghidEventTap)
        }
        if let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) {
            up.keyboardSetUnicodeString(stringLength: 1, unicodeString: &ch)
            up.post(tap: .cghidEventTap)
        }
    }

    func key(_ name: String, mods: [String], action: MouseAction) {
        let modFlags = Self.flags(for: mods)
        if let code = Self.keyCode(for: name) {
            switch action {
            case .down:  postKey(code, down: true, flags: modFlags)
            case .up:    postKey(code, down: false, flags: modFlags)
            case .click:
                postKey(code, down: true, flags: modFlags)
                postKey(code, down: false, flags: modFlags)
            }
        } else if name.count == 1 {
            // Fall back: type the single character with modifiers reapplied
            // around it. Modifier-only fallbacks are not attempted.
            type(name)
        }
    }

    private func postKey(_ code: CGKeyCode, down: Bool, flags: CGEventFlags) {
        guard let event = CGEvent(keyboardEventSource: nil,
                                  virtualKey: code,
                                  keyDown: down) else { return }
        if !flags.isEmpty { event.flags = flags }
        event.post(tap: .cghidEventTap)
    }

    private static func flags(for mods: [String]) -> CGEventFlags {
        var f: CGEventFlags = []
        for m in mods {
            switch m.lowercased() {
            case "cmd", "command", "win", "super": f.insert(.maskCommand)
            case "shift": f.insert(.maskShift)
            case "alt", "option", "opt": f.insert(.maskAlternate)
            case "ctrl", "control": f.insert(.maskControl)
            case "fn", "function": f.insert(.maskSecondaryFn)
            default: break
            }
        }
        return f
    }

    // MARK: - Media keys (NX_KEYTYPE_*)

    func media(_ cmd: MediaCommand) {
        let nxCode: Int32
        switch cmd {
        case .volumeUp:       nxCode = 0   // NX_KEYTYPE_SOUND_UP
        case .volumeDown:     nxCode = 1   // NX_KEYTYPE_SOUND_DOWN
        case .brightnessUp:   nxCode = 2   // NX_KEYTYPE_BRIGHTNESS_UP
        case .brightnessDown: nxCode = 3   // NX_KEYTYPE_BRIGHTNESS_DOWN
        case .mute:           nxCode = 7   // NX_KEYTYPE_MUTE
        case .playPause:      nxCode = 16  // NX_KEYTYPE_PLAY
        case .next:           nxCode = 17  // NX_KEYTYPE_NEXT
        case .prev:           nxCode = 18  // NX_KEYTYPE_PREVIOUS
        }
        postNX(nxCode, down: true)
        postNX(nxCode, down: false)
    }

    private func postNX(_ keyCode: Int32, down: Bool) {
        let flags: NSEvent.ModifierFlags = down
            ? NSEvent.ModifierFlags(rawValue: 0xa00)
            : NSEvent.ModifierFlags(rawValue: 0xb00)
        let data1 = (Int(keyCode) << 16) | ((down ? 0xa : 0xb) << 8)
        guard let ev = NSEvent.otherEvent(with: .systemDefined,
                                          location: .zero,
                                          modifierFlags: flags,
                                          timestamp: 0,
                                          windowNumber: 0,
                                          context: nil,
                                          subtype: 8,
                                          data1: data1,
                                          data2: -1) else { return }
        ev.cgEvent?.post(tap: .cghidEventTap)
    }

    // MARK: - Cursor jiggle

    func jiggle() {
        let pattern: [(Double, Double)] = [
            (40,0),(-80,0),(80,0),(-40,0),(0,40),(0,-80),(0,80),(0,-40)
        ]
        for (i, step) in pattern.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.04) { [weak self] in
                self?.move(dx: step.0, dy: step.1)
            }
        }
    }

    // MARK: - Key-name → virtual key code

    private static func keyCode(for raw: String) -> CGKeyCode? {
        switch raw.lowercased() {
        // Letters
        case "a": return 0;  case "s": return 1;  case "d": return 2;  case "f": return 3
        case "h": return 4;  case "g": return 5;  case "z": return 6;  case "x": return 7
        case "c": return 8;  case "v": return 9;  case "b": return 11; case "q": return 12
        case "w": return 13; case "e": return 14; case "r": return 15; case "y": return 16
        case "t": return 17; case "o": return 31; case "u": return 32; case "i": return 34
        case "p": return 35; case "l": return 37; case "j": return 38; case "k": return 40
        case "n": return 45; case "m": return 46
        // Digits
        case "1": return 18; case "2": return 19; case "3": return 20; case "4": return 21
        case "6": return 22; case "5": return 23; case "9": return 25; case "7": return 26
        case "8": return 28; case "0": return 29
        // Editing
        case "enter", "return": return 36
        case "tab": return 48
        case "space": return 49
        case "backspace", "bs": return 51
        case "escape", "esc": return 53
        case "capslock": return 57
        case "delete", "del", "forwarddelete": return 117
        case "help", "insert": return 114
        // Navigation
        case "home": return 115
        case "end": return 119
        case "pageup", "pgup": return 116
        case "pagedown", "pgdn": return 121
        case "left": return 123
        case "right": return 124
        case "down": return 125
        case "up": return 126
        // Function row
        case "f1": return 122
        case "f2": return 120
        case "f3": return 99
        case "f4": return 118
        case "f5": return 96
        case "f6": return 97
        case "f7": return 98
        case "f8": return 100
        case "f9": return 101
        case "f10": return 109
        case "f11": return 103
        case "f12": return 111
        case "f13": return 105
        case "f14": return 107
        case "f15": return 113
        case "f16": return 106
        case "f17": return 64
        case "f18": return 79
        case "f19": return 80
        case "f20": return 90
        // Modifiers as standalone (rare)
        case "cmd", "command", "win", "super": return 55
        case "shift": return 56
        case "option", "alt", "opt": return 58
        case "ctrl", "control": return 59
        case "fn", "function": return 63
        // Punctuation
        case "-", "minus":  return 27
        case "=", "equals": return 24
        case "[":           return 33
        case "]":           return 30
        case ";":           return 41
        case "'":           return 39
        case ",":           return 43
        case ".":           return 47
        case "/":           return 44
        case "\\":          return 42
        case "`":           return 50
        default: return nil
        }
    }
}

#endif
