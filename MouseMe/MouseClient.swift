//
//  MouseClient.swift
//  MouseMe
//
//  Public facade that owns whichever transport (TCP-out, TCP-host, BLE) is
//  currently active. Adds ping/pong latency measurement and persistent
//  reconnect state. The rest of the app talks only to MouseClient.
//

import Foundation
import Network
import Observation
#if canImport(UIKit)
import UIKit
#endif

@Observable
final class MouseClient {
    enum Status: Equatable {
        case idle
        case connecting(String)
        case connected(String)
        case failed(String)
    }

    enum TransportKind: String {
        case none, tcp, host, ble
    }

    private(set) var status: Status = .idle
    private(set) var transportKind: TransportKind = .none
    private(set) var latencyMs: Int?
    private(set) var hostInfo: HostTCPTransport.HostInfo?

    var isConnected: Bool {
        if case .connected = status { return true } else { return false }
    }

    private var transport: MouseTransport?
    private var pingTimer: Timer?
    private var pingCounter: UInt32 = 0
    private var inFlightPings: [UInt32: TimeInterval] = [:]

    // MARK: - Outbound TCP (phone dials helper)

    func connect(to endpoint: NWEndpoint, label: String) {
        stopTransport()
        status = .connecting(label)
        let t = TCPMouseTransport(label: label) { [weak self] newStatus in
            Task { @MainActor in self?.applyStatus(newStatus) }
        }
        t.onReceive = { [weak self] evt in
            Task { @MainActor in self?.handleInbound(evt) }
        }
        transport = t
        transportKind = .tcp
        t.start(endpoint: endpoint)
        startPings()
    }

    func connect(host: String, port: UInt16) {
        let ep = NWEndpoint.hostPort(host: NWEndpoint.Host(host),
                                     port: NWEndpoint.Port(rawValue: port) ?? 8237)
        connect(to: ep, label: "\(host):\(port)")
        Self.rememberLastTCP(host: host, port: port)
    }

    // MARK: - Host mode (phone is the server)

    func startHost(port: UInt16 = 8237) {
        stopTransport()
        status = .connecting("Starting host…")
        let t = HostTCPTransport(
            statusHandler: { [weak self] newStatus in
                Task { @MainActor in self?.applyStatus(newStatus) }
            },
            infoHandler: { [weak self] info in
                Task { @MainActor in self?.hostInfo = info }
            }
        )
        t.onReceive = { [weak self] evt in
            Task { @MainActor in self?.handleInbound(evt) }
        }
        transport = t
        transportKind = .host
        t.start(preferredPort: port)
        startPings()
    }

    // MARK: - BLE

    func startBluetooth() {
        stopTransport()
        status = .connecting("Bluetooth")
        let t = BLEMouseTransport { [weak self] newStatus in
            Task { @MainActor in self?.applyStatus(newStatus) }
        }
        transport = t
        transportKind = .ble
        t.start()
        // BLE is notify-only; no inbound channel for pong → no latency.
    }

    // MARK: - Send / Disconnect

    func send(_ event: MouseEvent) {
        guard isConnected else { return }
        transport?.send(event)
    }

    func disconnect() {
        stopTransport()
        status = .idle
        transportKind = .none
        latencyMs = nil
        hostInfo = nil
    }

    private func stopTransport() {
        stopPings()
        transport?.stop()
        transport = nil
    }

    private func applyStatus(_ s: Status) {
        status = s
        if case .failed = s { latencyMs = nil }
        if case .idle = s { latencyMs = nil }
    }

    // MARK: - Ping / latency

    private func startPings() {
        stopPings()
        let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.sendPing() }
        }
        RunLoop.main.add(timer, forMode: .common)
        pingTimer = timer
    }

    private func stopPings() {
        pingTimer?.invalidate()
        pingTimer = nil
        inFlightPings.removeAll()
    }

    private func sendPing() {
        guard isConnected, transportKind != .ble else { return }
        pingCounter &+= 1
        let id = pingCounter
        inFlightPings[id] = Date().timeIntervalSince1970
        transport?.send(.ping(id: id))
        // Garbage-collect stale entries (>5s old)
        let cutoff = Date().timeIntervalSince1970 - 5
        inFlightPings = inFlightPings.filter { $0.value >= cutoff }
    }

    private func handleInbound(_ evt: MouseEvent) {
        guard evt.t == .pong, let id = evt.id, let sent = inFlightPings.removeValue(forKey: id) else { return }
        let rtt = (Date().timeIntervalSince1970 - sent) * 1000
        latencyMs = max(0, Int(rtt.rounded()))
    }

    // MARK: - Auto-reconnect persistence

    private static let lastHostKey = "MouseMe.lastHost"
    private static let lastPortKey = "MouseMe.lastPort"

    static func lastTCP() -> (host: String, port: UInt16)? {
        let d = UserDefaults.standard
        guard let host = d.string(forKey: lastHostKey), !host.isEmpty else { return nil }
        let port = UInt16(d.integer(forKey: lastPortKey))
        return port > 0 ? (host, port) : nil
    }

    static func rememberLastTCP(host: String, port: UInt16) {
        let d = UserDefaults.standard
        d.set(host, forKey: lastHostKey)
        d.set(Int(port), forKey: lastPortKey)
    }

    static func clearLastTCP() {
        let d = UserDefaults.standard
        d.removeObject(forKey: lastHostKey)
        d.removeObject(forKey: lastPortKey)
    }

    static func deviceName() -> String {
        #if canImport(UIKit)
        return UIDevice.current.name
        #else
        return Host.current().localizedName ?? "MouseMe"
        #endif
    }
}
