//
//  TVDiscovery.swift
//  MouseMe
//
//  Finds Roku TVs on the local network by probing port 8060.
//

import Foundation
import Observation

struct DiscoveredTV: Identifiable, Hashable {
    let id: String
    let name: String
    let ip: String
}

@Observable
final class TVDiscovery {
    private(set) var devices: [DiscoveredTV] = []
    private(set) var isScanning = false
    private(set) var status = "Tap **Find TVs** to scan your Wi‑Fi network."

    func scan() async {
        guard !isScanning else { return }
        isScanning = true
        defer { isScanning = false }

        guard let prefix = Self.subnetPrefix() else {
            status = "Connect to Wi‑Fi first, then scan again."
            devices = []
            return
        }

        status = "Scanning \(prefix).x …"
        devices = []
        var found: [DiscoveredTV] = []

        await withTaskGroup(of: DiscoveredTV?.self) { group in
            var inFlight = 0
            for host in 1...254 {
                let ip = "\(prefix).\(host)"
                group.addTask { await Self.probeRoku(at: ip) }
                inFlight += 1
                if inFlight >= 48 {
                    if let d = await group.next(), let device = d { found.append(device) }
                    inFlight -= 1
                }
            }
            while let d = await group.next() {
                if let device = d { found.append(device) }
            }
        }

        devices = found.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        status = devices.isEmpty
            ? "No Roku TVs found. Enter an IP manually or check the TV is on the same Wi‑Fi."
            : "Found \(devices.count) TV\(devices.count == 1 ? "" : "s") — tap one to connect."
    }

    private static func subnetPrefix() -> String? {
        let ifaces = NetworkScout.interfaces()
        guard let iface = ifaces.first(where: { $0.kind == .wifi || $0.kind == .hotspot }) else { return nil }
        let parts = iface.ip.split(separator: ".")
        guard parts.count == 4 else { return nil }
        return parts.prefix(3).joined(separator: ".")
    }

    private static func probeRoku(at ip: String) async -> DiscoveredTV? {
        guard let url = URL(string: "http://\(ip):8060/query/device-info") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 0.4
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            let xml = String(data: data, encoding: .utf8) ?? ""
            guard xml.contains("friendly-device-name") || xml.lowercased().contains("roku") else { return nil }
            let name = extractXMLTag("friendly-device-name", from: xml) ?? "Roku (\(ip))"
            return DiscoveredTV(id: ip, name: name, ip: ip)
        } catch {
            return nil
        }
    }

    private static func extractXMLTag(_ tag: String, from xml: String) -> String? {
        guard let open = xml.range(of: "<\(tag)>"),
              let close = xml.range(of: "</\(tag)>") else { return nil }
        return String(xml[open.upperBound..<close.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
