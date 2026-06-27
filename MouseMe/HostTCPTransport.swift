//
//  HostTCPTransport.swift
//  MouseMe
//
//  "Host mode": the phone runs an NWListener and advertises Bonjour as
//  `_mousemehost._tcp`. The desktop helper dials in. This is the path that
//  works when the phone IS the network — e.g. with Personal Hotspot turned
//  on and the computer joined to the phone's Wi-Fi.
//
//  Hardening notes:
//    • iOS will refuse to advertise a Bonjour type unless it's listed in
//      Info.plist's NSBonjourServices. Both `_mouseme._tcp` and
//      `_mousemehost._tcp` are declared in the build settings.
//    • If the preferred port is already in use we fall back to `.any` so
//      the listener still comes up — the phone shows the chosen port.
//    • Listener `.waiting(err)` is forwarded to the UI so the user can
//      see when local-network permission is missing or denied.
//

import Foundation
import Network

final class HostTCPTransport: MouseTransport {
    let label: String = "Hotspot host"
    private(set) var isConnected: Bool = false
    var onReceive: ((MouseEvent) -> Void)?

    private var listener: NWListener?
    private var connection: NWConnection?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let queue = DispatchQueue(label: "MouseMe.host")
    private let statusHandler: (MouseClient.Status) -> Void
    private let infoHandler: (HostInfo?) -> Void
    private var rxBuffer = Data()

    struct HostInfo: Equatable {
        var port: UInt16
        var ip: String?
        var clientLabel: String?
    }
    private(set) var info: HostInfo?

    init(statusHandler: @escaping (MouseClient.Status) -> Void,
         infoHandler: @escaping (HostInfo?) -> Void) {
        self.statusHandler = statusHandler
        self.infoHandler = infoHandler
    }

    func start(preferredPort: UInt16 = 8237) {
        // First try the preferred port. If it's taken we retry on .any.
        if let l = makeListener(port: NWEndpoint.Port(rawValue: preferredPort) ?? .any) {
            attach(l)
            return
        }
        if let l = makeListener(port: .any) {
            attach(l)
            return
        }
        statusHandler(.failed("Could not start the listener on this device."))
    }

    private func makeListener(port: NWEndpoint.Port) -> NWListener? {
        let params = NWParameters.tcp
        if let tcp = params.defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options {
            tcp.noDelay = true
            tcp.enableKeepalive = true
            tcp.keepaliveIdle = 10
        }
        // Reuse address so a quick relaunch doesn't hit TIME_WAIT.
        params.allowLocalEndpointReuse = true

        do {
            let l = try NWListener(using: params, on: port)
            l.service = NWListener.Service(
                name: "MouseMe \(MouseClient.deviceName())",
                type: "_mousemehost._tcp"
            )
            return l
        } catch {
            return nil
        }
    }

    private func attach(_ l: NWListener) {
        listener = l
        l.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .setup:
                self.statusHandler(.connecting("Preparing host…"))
            case .waiting(let err):
                // Common: missing local-network permission, or no usable interface.
                if NetworkPermission.isPermissionDenied(err) {
                    self.statusHandler(.failed("Local Network access is denied. Enable it in Settings → Privacy & Security → Local Network."))
                } else {
                    self.statusHandler(.failed("Waiting: \(err.localizedDescription)"))
                }
            case .ready:
                let actual = l.port?.rawValue ?? 0
                let ip = Self.bestLocalIP()
                let i = HostInfo(port: actual, ip: ip, clientLabel: nil)
                self.info = i
                self.infoHandler(i)
                let where_ = ip ?? "this phone"
                self.statusHandler(.connecting("Hosting on \(where_):\(actual) — waiting for computer"))
            case .failed(let err):
                self.statusHandler(.failed(err.localizedDescription))
            case .cancelled:
                self.isConnected = false
                self.statusHandler(.idle)
            @unknown default: break
            }
        }
        l.newConnectionHandler = { [weak self] newConn in
            guard let self else { return }
            self.adopt(connection: newConn)
        }
        l.start(queue: queue)
    }

    private func adopt(connection newConn: NWConnection) {
        // One client at a time — close any previous one.
        self.connection?.cancel()
        self.connection = newConn
        self.rxBuffer.removeAll()
        newConn.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.isConnected = true
                let who = Self.describe(endpoint: newConn.endpoint)
                var updated = self.info
                updated?.clientLabel = who
                self.info = updated
                self.infoHandler(updated)
                self.statusHandler(.connected("Host · \(who)"))
                self.sendHello()
                self.startReceive(on: newConn)
            case .failed, .cancelled:
                self.isConnected = false
                var updated = self.info
                updated?.clientLabel = nil
                self.info = updated
                self.infoHandler(updated)
                if let p = self.info?.port {
                    let ip = self.info?.ip ?? "this phone"
                    self.statusHandler(.connecting("Hosting on \(ip):\(p) — waiting for computer"))
                } else {
                    self.statusHandler(.connecting("Hosting — waiting for computer"))
                }
            default: break
            }
        }
        newConn.start(queue: queue)
    }

    func stop() {
        connection?.cancel()
        listener?.cancel()
        connection = nil
        listener = nil
        isConnected = false
        rxBuffer.removeAll()
        info = nil
        infoHandler(nil)
    }

    func send(_ event: MouseEvent) {
        guard let c = connection, isConnected else { return }
        guard var data = try? encoder.encode(event) else { return }
        data.append(0x0A)
        c.send(content: data, completion: .contentProcessed { _ in })
    }

    private func sendHello() {
        send(.hello(name: MouseClient.deviceName(), style: "trackpad"))
    }

    private func startReceive(on conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty { self.consume(data) }
            if error != nil || isComplete { return }
            self.startReceive(on: conn)
        }
    }

    private func consume(_ chunk: Data) {
        rxBuffer.append(chunk)
        while let nl = rxBuffer.firstIndex(of: 0x0A) {
            let line = rxBuffer.subdata(in: rxBuffer.startIndex..<nl)
            rxBuffer.removeSubrange(rxBuffer.startIndex...nl)
            guard !line.isEmpty else { continue }
            if let evt = try? decoder.decode(MouseEvent.self, from: line) {
                onReceive?(evt)
            }
        }
    }

    // MARK: - Helpers

    private static func describe(endpoint: NWEndpoint) -> String {
        switch endpoint {
        case .hostPort(let h, _):       return "\(h)"
        case .service(let n, _, _, _):  return n
        default:                        return "client"
        }
    }

    /// Best-guess IPv4 for showing the user. Prefers a Personal-Hotspot
    /// `bridge*` interface, then any non-loopback IPv4.
    static func bestLocalIP() -> String? {
        var addrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrs) == 0, let first = addrs else { return nil }
        defer { freeifaddrs(addrs) }

        var hotspot: String?
        var fallback: String?
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let cur = ptr {
            let ifa = cur.pointee
            let flags = Int32(ifa.ifa_flags)
            if let sa = ifa.ifa_addr,
               sa.pointee.sa_family == sa_family_t(AF_INET),
               (flags & IFF_UP) != 0,
               (flags & IFF_LOOPBACK) == 0 {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let r = getnameinfo(sa, socklen_t(sa.pointee.sa_len),
                                    &host, socklen_t(host.count),
                                    nil, 0, NI_NUMERICHOST)
                if r == 0 {
                    let ip = String(cString: host)
                    let name = ifa.ifa_name.map { String(cString: $0) } ?? ""
                    // bridge100 = iPhone Personal Hotspot tether interface.
                    if name.hasPrefix("bridge") || name.hasPrefix("ap") {
                        hotspot = ip
                    } else if ip.hasPrefix("172.20.") && hotspot == nil {
                        hotspot = ip
                    } else if fallback == nil {
                        fallback = ip
                    }
                }
            }
            ptr = ifa.ifa_next
        }
        return hotspot ?? fallback
    }
}
