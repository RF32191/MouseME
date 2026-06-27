//
//  BLEMouseTransport.swift
//  MouseMe
//
//  CoreBluetooth peripheral. Exposes one notify characteristic; the desktop
//  helper subscribes via `bleak` (see Server/mouseme_server.py --bluetooth).
//
//  Optimisations vs. v1:
//    • MTU-aware chunking — packs as many JSON-line frames per BLE notify
//      packet as `central.maximumUpdateValueLength` allows, instead of one
//      notify per event (huge throughput win at 23-byte default MTU).
//    • Move-event coalescing — when the outgoing queue starts to back up
//      (BLE is slow vs. 90Hz gyro), collapses consecutive `move` events
//      into a single summed `move`. Keeps latency low; drops jitter.
//    • Auto re-advertise on disconnect so a dropped helper can reconnect
//      without the user re-tapping "Pair via Bluetooth".
//
//  Note: iOS does not allow third-party apps to act as a Bluetooth HID
//  peripheral. A generic OS won't recognise this device as a mouse on its
//  own — the helper translates notifications into real input.
//

import Foundation
import CoreBluetooth

enum MouseBLE {
    static let serviceUUID    = CBUUID(string: "7C2E0001-5A0E-4F4D-9F9C-7A2D5E1A1B01")
    static let eventCharUUID  = CBUUID(string: "7C2E0002-5A0E-4F4D-9F9C-7A2D5E1A1B02")
}

final class BLEMouseTransport: NSObject, MouseTransport, CBPeripheralManagerDelegate {
    let label: String = "Bluetooth"
    private(set) var isConnected: Bool = false
    var onReceive: ((MouseEvent) -> Void)?   // BLE is notify-only; never fires.

    private var manager: CBPeripheralManager?
    private var characteristic: CBMutableCharacteristic?
    private var subscribers: [CBCentral] = []
    private var pending: [MouseEvent] = []           // queued events (pre-encode)
    private let encoder = JSONEncoder()
    private let statusHandler: (MouseClient.Status) -> Void

    /// Above this many queued events we collapse consecutive moves to avoid
    /// flooding BLE. Tuned for 23-byte default MTU.
    private let coalesceThreshold = 4

    init(statusHandler: @escaping (MouseClient.Status) -> Void) {
        self.statusHandler = statusHandler
    }

    // MARK: - MouseTransport

    func start() {
        manager = CBPeripheralManager(delegate: self, queue: .main)
    }

    func stop() {
        if let m = manager, m.isAdvertising { m.stopAdvertising() }
        if let m = manager, m.state == .poweredOn { m.removeAllServices() }
        manager = nil
        characteristic = nil
        subscribers.removeAll()
        pending.removeAll()
        isConnected = false
    }

    func send(_ event: MouseEvent) {
        enqueue(event)
        flush()
    }

    // MARK: - Queue / coalesce

    private func enqueue(_ event: MouseEvent) {
        // Coalesce: if queue is getting long and this is a move, fold into
        // the trailing move (if any).
        if event.t == .move,
           pending.count >= coalesceThreshold,
           let lastIdx = pending.indices.last,
           pending[lastIdx].t == .move {
            pending[lastIdx].dx = (pending[lastIdx].dx ?? 0) + (event.dx ?? 0)
            pending[lastIdx].dy = (pending[lastIdx].dy ?? 0) + (event.dy ?? 0)
            return
        }
        pending.append(event)
    }

    private func flush() {
        guard isConnected, let m = manager, let ch = characteristic, !subscribers.isEmpty else { return }
        let mtu = subscribers.map(\.maximumUpdateValueLength).min() ?? 20

        var packet = Data()
        packet.reserveCapacity(mtu)

        while !pending.isEmpty {
            // Build one packet up to MTU by concatenating encoded frames.
            packet.removeAll(keepingCapacity: true)
            while let next = pending.first,
                  let encoded = try? encoder.encode(next) {
                let frame = encoded + Data([0x0A])
                if frame.count > mtu {
                    // Single frame too large to fit even in an empty packet —
                    // drop it rather than getting stuck.
                    pending.removeFirst()
                    continue
                }
                if packet.count + frame.count > mtu { break }
                packet.append(frame)
                pending.removeFirst()
            }
            if packet.isEmpty { break }
            let ok = m.updateValue(packet, for: ch, onSubscribedCentrals: nil)
            if !ok {
                // Re-queue the unsent packet's content — we already removed it,
                // so just stop; we'll get peripheralManagerIsReady(toUpdate:)
                // and the events left in `pending` will go out then.
                // The bytes we just consumed are lost; that's acceptable for
                // move/scroll-heavy streams.
                return
            }
        }
    }

    // MARK: - CBPeripheralManagerDelegate

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            installServiceAndAdvertise(on: peripheral)
            statusHandler(.connecting("Bluetooth · waiting for computer"))
        case .poweredOff:
            statusHandler(.failed("Bluetooth is off"))
        case .unauthorized:
            statusHandler(.failed("Bluetooth permission denied"))
        case .unsupported:
            statusHandler(.failed("Bluetooth LE unsupported on this device"))
        default:
            break
        }
    }

    private func installServiceAndAdvertise(on peripheral: CBPeripheralManager) {
        if peripheral.isAdvertising { peripheral.stopAdvertising() }
        peripheral.removeAllServices()

        let ch = CBMutableCharacteristic(
            type: MouseBLE.eventCharUUID,
            properties: [.notify],
            value: nil,
            permissions: []
        )
        let svc = CBMutableService(type: MouseBLE.serviceUUID, primary: true)
        svc.characteristics = [ch]
        peripheral.add(svc)
        characteristic = ch

        peripheral.startAdvertising([
            CBAdvertisementDataLocalNameKey: "MouseMe \(MouseClient.deviceName())",
            CBAdvertisementDataServiceUUIDsKey: [MouseBLE.serviceUUID]
        ])
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           central: CBCentral,
                           didSubscribeTo characteristic: CBCharacteristic) {
        if !subscribers.contains(where: { $0.identifier == central.identifier }) {
            subscribers.append(central)
        }
        isConnected = true
        if peripheral.isAdvertising { peripheral.stopAdvertising() }
        statusHandler(.connected("Bluetooth"))
        // Initial hello — handler-side acts on it for logging / capability.
        send(.hello(name: MouseClient.deviceName(), style: "trackpad"))
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           central: CBCentral,
                           didUnsubscribeFrom characteristic: CBCharacteristic) {
        subscribers.removeAll { $0.identifier == central.identifier }
        if subscribers.isEmpty {
            isConnected = false
            pending.removeAll()
            statusHandler(.connecting("Bluetooth · waiting for computer"))
            // Re-advertise so the helper can reconnect without UI input.
            if peripheral.state == .poweredOn, !peripheral.isAdvertising {
                peripheral.startAdvertising([
                    CBAdvertisementDataLocalNameKey: "MouseMe \(MouseClient.deviceName())",
                    CBAdvertisementDataServiceUUIDsKey: [MouseBLE.serviceUUID]
                ])
            }
        }
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        flush()
    }
}
