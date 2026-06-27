//
//  TVController.swift
//  MouseMe (macOS receiver)
//
//  Forwards TV commands from the phone to a smart TV on the LAN.
//  Currently targets Roku via the External Control Protocol (ECP):
//      POST http://<IP>:8060/keypress/<Key>
//  No authentication needed. Generic enough that other brands can be
//  added later by routing on `kind`.
//

#if os(macOS)

import Foundation
import Network
import Observation

@MainActor
@Observable
final class TVController {

    /// IP/host of the target TV (Roku). Persisted in UserDefaults.
    var rokuIP: String {
        didSet {
            UserDefaults.standard.set(rokuIP, forKey: Self.ipKey)
        }
    }

    var deviceName: String {
        didSet {
            UserDefaults.standard.set(deviceName, forKey: Self.nameKey)
        }
    }

    private(set) var lastResult: String?
    private(set) var lastSentAt: Date?

    private static let ipKey = "MouseMe.rokuIP"
    private static let nameKey = "MouseMe.tvName"
    private static let rokuPort: UInt16 = 8060
    private let queue = DispatchQueue(label: "MouseMe.tvController")

    init() {
        self.rokuIP = UserDefaults.standard.string(forKey: Self.ipKey) ?? ""
        self.deviceName = UserDefaults.standard.string(forKey: Self.nameKey) ?? ""
    }

    var isConfigured: Bool {
        !rokuIP.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Maps our generic TV command to a Roku ECP key name.
    private func rokuKey(for cmd: TVCommand) -> String {
        switch cmd {
        case .home:        return "Home"
        case .back:        return "Back"
        case .info:        return "Info"
        case .search:      return "Search"
        case .up:          return "Up"
        case .down:        return "Down"
        case .left:        return "Left"
        case .right:       return "Right"
        case .ok:          return "Select"
        case .play:        return "Play"
        case .pause:       return "Play"     // Roku toggles play/pause on the same key
        case .replay:      return "InstantReplay"
        case .fwd:         return "Fwd"
        case .rev:         return "Rev"
        case .volumeUp:    return "VolumeUp"
        case .volumeDown:  return "VolumeDown"
        case .mute:        return "VolumeMute"
        case .power:       return "Power"
        case .powerOn:     return "PowerOn"
        case .powerOff:    return "PowerOff"
        case .channelUp:   return "ChannelUp"
        case .channelDown: return "ChannelDown"
        case .input:       return "InputHDMI1"
        }
    }

    func send(_ cmd: TVCommand) {
        let ip = rokuIP.trimmingCharacters(in: .whitespaces)
        guard !ip.isEmpty else {
            lastResult = "Set a Roku IP first"
            return
        }
        let key = rokuKey(for: cmd)
        lastSentAt = Date()
        postKeypress(host: ip, key: key)
    }

    func ping() { send(.home) }

    // MARK: - Network

    /// Roku speaks plain HTTP/1.1; using NWConnection sidesteps App Transport
    /// Security (which blocks `URLSession` to non-HTTPS endpoints by default).
    private func postKeypress(host: String, key: String) {
        let port = NWEndpoint.Port(rawValue: Self.rokuPort)!
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: port)
        let conn = NWConnection(to: endpoint, using: .tcp)

        let request = """
        POST /keypress/\(key) HTTP/1.1\r
        Host: \(host):\(Self.rokuPort)\r
        Content-Length: 0\r
        Connection: close\r
        \r

        """
        let payload = Data(request.utf8)

        conn.stateUpdateHandler = { [weak self, weak conn] state in
            guard let self else { return }
            switch state {
            case .ready:
                conn?.send(content: payload, completion: .contentProcessed { [weak self, weak conn] err in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        if let err = err {
                            self.lastResult = "\(key) send failed: \(err.localizedDescription)"
                        } else {
                            self.lastResult = "\(key) ✓"
                        }
                    }
                    // Read once to drain Roku's tiny response (best-effort), then close.
                    conn?.receive(minimumIncompleteLength: 1, maximumLength: 256) { _, _, _, _ in
                        conn?.cancel()
                    }
                })
            case .failed(let err):
                Task { @MainActor [weak self] in
                    self?.lastResult = "\(key) connect failed: \(err.localizedDescription)"
                }
                conn?.cancel()
            case .cancelled:
                break
            default:
                break
            }
        }
        conn.start(queue: queue)

        // Safety: cancel after 2s in case Roku ignores us.
        queue.asyncAfter(deadline: .now() + 2) { [weak conn] in
            conn?.cancel()
        }
    }
}

#endif
