//
//  BonjourBrowser.swift
//  MouseMe
//
//  Discovers helper servers advertised as _mouseme._tcp on the local network.
//  Surfaces Local-Network permission state so the UI can prompt the user.
//

import Foundation
import Network
import Observation

@Observable
final class BonjourBrowser {
    struct Service: Identifiable, Hashable {
        let id: String
        let name: String
        let endpoint: NWEndpoint
    }

    private(set) var services: [Service] = []
    private(set) var isBrowsing: Bool = false
    private(set) var permissionDenied: Bool = false
    private(set) var lastErrorMessage: String?

    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "MouseMe.bonjour")

    func start() {
        // Always restart from scratch — a failed/cancelled browser instance
        // would otherwise stick around as a no-op.
        browser?.cancel()
        browser = nil
        services = []
        permissionDenied = false
        lastErrorMessage = nil

        let descriptor = NWBrowser.Descriptor.bonjour(type: "_mouseme._tcp", domain: nil)
        let params = NWParameters.tcp
        params.includePeerToPeer = true
        let b = NWBrowser(for: descriptor, using: params)
        b.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor [weak self] in
                self?.update(from: results)
            }
        }
        b.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch state {
                case .ready:
                    self.isBrowsing = true
                    self.permissionDenied = false
                    self.lastErrorMessage = nil
                case .waiting(let err):
                    self.isBrowsing = false
                    self.handle(err)
                case .failed(let err):
                    self.isBrowsing = false
                    self.handle(err)
                    // Drop the dead instance so refresh() can rebuild.
                    self.browser = nil
                case .cancelled:
                    self.isBrowsing = false
                default: break
                }
            }
        }
        browser = b
        b.start(queue: queue)
    }

    func refresh() { start() }

    func stop() {
        browser?.cancel()
        browser = nil
        services.removeAll()
        isBrowsing = false
    }

    private func update(from results: Set<NWBrowser.Result>) {
        var seen: [Service] = []
        for r in results {
            if case let .service(name, type, domain, _) = r.endpoint {
                seen.append(Service(
                    id: "\(name).\(type).\(domain)",
                    name: name,
                    endpoint: r.endpoint
                ))
            }
        }
        services = seen.sorted { $0.name < $1.name }
    }

    private func handle(_ err: NWError) {
        lastErrorMessage = err.localizedDescription
        permissionDenied = NetworkPermission.isPermissionDenied(err)
    }
}

/// Helpers for the iOS Local-Network privacy gate.
enum NetworkPermission {
    /// True when an NWError is the "Local Network not authorised" flavour
    /// (mDNS `NoAuth(-65555)` or POSIX `EPERM`).
    static func isPermissionDenied(_ err: NWError) -> Bool {
        switch err {
        case .dns(let code):
            return code == -65555
        case .posix(let code):
            return code == .EPERM
        default:
            return false
        }
    }
}
