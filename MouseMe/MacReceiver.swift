//
//  MacReceiver.swift
//  MouseMe (macOS receiver)
//
//  Replaces the Python helper for the Mac case. Hosts an NWListener on
//  `_mouseme._tcp` so MouseMe on iPhone discovers it automatically, reads
//  newline-framed JSON `MouseEvent`s, and dispatches via `MacEventInjector`.
//

#if os(macOS)

import Foundation
import Network
import AppKit
import Observation

@MainActor
@Observable
final class MacReceiver {

    enum State: Equatable {
        case stopped
        case starting
        case listening(port: UInt16)
        case failed(String)
    }

    struct ConnectedClient: Identifiable, Equatable {
        let id = UUID()
        var label: String
        var address: String?
        var since: Date
    }

    private(set) var state: State = .stopped
    private(set) var clients: [ConnectedClient] = []
    private(set) var lastEventSummary: String?
    private(set) var lastEventAt: Date?
    private(set) var eventsThisSession: Int = 0
    var preferredPort: UInt16 = 8237

    private let injector = MacEventInjector()
    let tv = TVController()
    private var listener: NWListener?
    private var connections: [ObjectIdentifier: ClientConnection] = [:]
    private let queue = DispatchQueue(label: "MouseMe.macReceiver")
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    var isAccessibilityTrusted: Bool {
        MacEventInjector.isTrusted(prompt: false)
    }

    // MARK: - Lifecycle

    func start() {
        guard case .stopped = state else { return }
        state = .starting

        if let l = makeListener(port: NWEndpoint.Port(rawValue: preferredPort) ?? .any) {
            attach(l)
            return
        }
        if let l = makeListener(port: .any) {
            attach(l)
            return
        }
        state = .failed("Could not open a listening port on this Mac.")
    }

    func stop() {
        listener?.cancel()
        listener = nil
        for (_, c) in connections { c.cancel() }
        connections.removeAll()
        clients.removeAll()
        state = .stopped
    }

    func toggle() {
        switch state {
        case .stopped, .failed: start()
        default: stop()
        }
    }

    func requestAccessibility() {
        _ = MacEventInjector.isTrusted(prompt: true)
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Listener wiring

    private func makeListener(port: NWEndpoint.Port) -> NWListener? {
        let params = NWParameters.tcp
        if let tcp = params.defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options {
            tcp.noDelay = true
            tcp.enableKeepalive = true
            tcp.keepaliveIdle = 10
        }
        params.allowLocalEndpointReuse = true
        do {
            let l = try NWListener(using: params, on: port)
            l.service = NWListener.Service(
                name: "MouseMe \(Self.machineName())",
                type: "_mouseme._tcp"
            )
            return l
        } catch {
            return nil
        }
    }

    private func attach(_ l: NWListener) {
        listener = l
        l.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch state {
                case .ready:
                    if let p = self.listener?.port?.rawValue {
                        self.state = .listening(port: p)
                    }
                case .failed(let err):
                    self.state = .failed(err.localizedDescription)
                case .cancelled:
                    self.state = .stopped
                default: break
                }
            }
        }
        l.newConnectionHandler = { [weak self] conn in
            Task { @MainActor [weak self] in
                self?.accept(conn)
            }
        }
        l.start(queue: queue)
    }

    private func accept(_ raw: NWConnection) {
        let c = ClientConnection(connection: raw,
                                 onReceive: { [weak self] event, c in
                                     Task { @MainActor [weak self] in
                                         self?.dispatch(event, from: c)
                                     }
                                 },
                                 onState: { [weak self] _, c in
                                     Task { @MainActor [weak self] in
                                         self?.refreshClients()
                                         if case .cancelled = c.connection.state {
                                             self?.connections.removeValue(forKey: ObjectIdentifier(c))
                                             self?.refreshClients()
                                         }
                                     }
                                 })
        connections[ObjectIdentifier(c)] = c
        c.start(queue: queue)
    }

    private func refreshClients() {
        clients = connections.values.map { c in
            ConnectedClient(label: c.label ?? "Phone",
                            address: c.peer,
                            since: c.connectedAt)
        }
    }

    // MARK: - Event dispatch

    private func dispatch(_ event: MouseEvent, from client: ClientConnection) {
        eventsThisSession &+= 1
        lastEventAt = Date()

        switch event.t {
        case .hello:
            client.label = event.name
            refreshClients()
            lastEventSummary = "Paired with \(event.name ?? "phone")"

        case .move:
            injector.move(dx: event.dx ?? 0, dy: event.dy ?? 0)
            lastEventSummary = "Move"

        case .click:
            if let b = event.button, let a = event.action {
                injector.click(b, action: a)
                lastEventSummary = "\(b.rawValue.capitalized) \(a.rawValue)"
            }

        case .scroll:
            injector.scroll(dx: event.dx ?? 0, dy: event.dy ?? 0)
            lastEventSummary = "Scroll"

        case .key:
            if let k = event.key {
                injector.key(k, mods: event.mods ?? [], action: event.action ?? .click)
                lastEventSummary = "Key \(k)"
            }

        case .text:
            if let s = event.text, !s.isEmpty {
                injector.type(s)
                lastEventSummary = "Type \"\(s.prefix(24))\""
            }

        case .media:
            if let m = event.cmd {
                injector.media(m)
                lastEventSummary = "Media \(m.rawValue)"
            }

        case .tv:
            if let cmd = event.tv {
                tv.send(cmd)
                lastEventSummary = "TV \(cmd.rawValue)"
            }

        case .tvConfig:
            if let host = event.tvHost?.trimmingCharacters(in: .whitespaces), !host.isEmpty {
                tv.rokuIP = host
                tv.deviceName = host
                lastEventSummary = "TV target → \(host)"
            }

        case .jiggle:
            injector.jiggle()
            lastEventSummary = "Find cursor"

        case .ping:
            // Echo back as pong so the phone can measure RTT.
            var pong = MouseEvent(t: .pong)
            pong.id = event.id
            pong.ts = event.ts
            client.send(pong)

        case .pong:
            break
        }
    }

    // MARK: - Helpers

    static func machineName() -> String {
        Host.current().localizedName ?? "Mac"
    }

    static func bestLocalIP() -> String? {
        // Prefer en* with a private IPv4. Falls back to first non-loopback.
        var addrs: [(String, String)] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let p = cursor {
            defer { cursor = p.pointee.ifa_next }
            guard let sa = p.pointee.ifa_addr else { continue }
            guard sa.pointee.sa_family == sa_family_t(AF_INET) else { continue }
            let name = String(cString: p.pointee.ifa_name)
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(sa,
                           socklen_t(p.pointee.ifa_addr.pointee.sa_len),
                           &host, socklen_t(host.count),
                           nil, 0, NI_NUMERICHOST) == 0 {
                let ip = String(cString: host)
                guard !ip.isEmpty, ip != "127.0.0.1" else { continue }
                addrs.append((name, ip))
            }
        }
        if let en = addrs.first(where: { $0.0.hasPrefix("en") }) { return en.1 }
        return addrs.first?.1
    }
}

// MARK: - Per-client connection wrapper

@MainActor
private final class ClientConnection {
    let connection: NWConnection
    var label: String?
    var peer: String?
    let connectedAt = Date()

    private let onReceive: (MouseEvent, ClientConnection) -> Void
    private let onState: (NWConnection.State, ClientConnection) -> Void
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private var rxBuffer = Data()

    init(connection: NWConnection,
         onReceive: @escaping (MouseEvent, ClientConnection) -> Void,
         onState: @escaping (NWConnection.State, ClientConnection) -> Void) {
        self.connection = connection
        self.onReceive = onReceive
        self.onState = onState
        if case let .hostPort(host, port) = connection.endpoint {
            self.peer = "\(host):\(port)"
        }
    }

    nonisolated func start(queue: DispatchQueue) {
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.onState(state, self)
                if case .ready = state { self.startReceive() }
            }
        }
        connection.start(queue: queue)
    }

    func cancel() { connection.cancel() }

    func send(_ event: MouseEvent) {
        guard var data = try? encoder.encode(event) else { return }
        data.append(0x0A)
        connection.send(content: data, completion: .contentProcessed { _ in })
    }

    private nonisolated func startReceive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                Task { @MainActor [weak self] in self?.consume(data) }
            }
            if error != nil || isComplete {
                self.connection.cancel()
                return
            }
            self.startReceive()
        }
    }

    private func consume(_ chunk: Data) {
        rxBuffer.append(chunk)
        while let nl = rxBuffer.firstIndex(of: 0x0A) {
            let line = rxBuffer.subdata(in: rxBuffer.startIndex..<nl)
            rxBuffer.removeSubrange(rxBuffer.startIndex...nl)
            guard !line.isEmpty else { continue }
            if let evt = try? decoder.decode(MouseEvent.self, from: line) {
                onReceive(evt, self)
            }
        }
    }
}

#endif
