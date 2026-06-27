//
//  MouseTransport.swift
//  MouseMe
//
//  Pluggable transport for mouse events. Concrete implementations:
//
//    * TCPMouseTransport — Wi-Fi, talks to the Python helper over JSON-lines TCP
//    * BLEMouseTransport — CoreBluetooth peripheral, the helper subscribes via
//                          notifications on a custom GATT service
//

import Foundation

protocol MouseTransport: AnyObject {
    var label: String { get }
    var isConnected: Bool { get }
    /// Set by `MouseClient` so transports can deliver inbound JSON-line
    /// events (e.g. pong replies) back to the facade.
    var onReceive: ((MouseEvent) -> Void)? { get set }
    func send(_ event: MouseEvent)
    func stop()
}
