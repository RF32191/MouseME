//
//  TCPMouseTransport.swift
//  MouseMe
//
//  Client-side TCP: the phone dials the helper. JSON-lines (LF framed).
//

import Foundation
import Network

final class TCPMouseTransport: MouseTransport {
    let label: String
    private(set) var isConnected: Bool = false
    var onReceive: ((MouseEvent) -> Void)?

    private var connection: NWConnection?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let queue = DispatchQueue(label: "MouseMe.tcp")
    private let statusHandler: (MouseClient.Status) -> Void
    private var rxBuffer = Data()

    init(label: String, statusHandler: @escaping (MouseClient.Status) -> Void) {
        self.label = label
        self.statusHandler = statusHandler
    }

    func start(endpoint: NWEndpoint) {
        let params = NWParameters.tcp
        if let tcp = params.defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options {
            tcp.noDelay = true
            tcp.enableKeepalive = true
            tcp.keepaliveIdle = 10
        }
        let c = NWConnection(to: endpoint, using: params)
        connection = c
        c.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.isConnected = true
                self.statusHandler(.connected(self.label))
                self.sendHello()
                self.startReceive()
            case .failed(let err):
                self.isConnected = false
                self.statusHandler(.failed(err.localizedDescription))
            case .cancelled:
                self.isConnected = false
                self.statusHandler(.idle)
            default: break
            }
        }
        c.start(queue: queue)
    }

    func stop() {
        connection?.cancel()
        connection = nil
        isConnected = false
        rxBuffer.removeAll()
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

    private func startReceive() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty { self.consume(data) }
            if let error {
                self.isConnected = false
                self.statusHandler(.failed(error.localizedDescription))
                return
            }
            if isComplete {
                self.isConnected = false
                self.statusHandler(.idle)
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
                onReceive?(evt)
            }
        }
    }
}
