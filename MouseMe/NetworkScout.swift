//
//  NetworkScout.swift
//  MouseMe
//
//  Enumerates the iPhone's active IPv4 interfaces so the Setup Guide can
//  recommend the right connection mode (Wi-Fi, Personal Hotspot, USB).
//

import Foundation

enum InterfaceKind {
    case wifi          // en0 typically
    case hotspot       // bridge100 / ap1 — Personal Hotspot when on
    case usb           // en* with 169.254 or 172.20.10.x via USB tether
    case cellular      // pdp_ip0..
    case loopback
    case other

    var label: String {
        switch self {
        case .wifi:     return "Wi-Fi"
        case .hotspot:  return "Personal Hotspot"
        case .usb:      return "USB tether"
        case .cellular: return "Cellular"
        case .loopback: return "Loopback"
        case .other:    return "Other"
        }
    }

    var symbol: String {
        switch self {
        case .wifi:     return "wifi"
        case .hotspot:  return "personalhotspot"
        case .usb:      return "cable.connector"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .loopback: return "arrow.uturn.left"
        case .other:    return "network"
        }
    }
}

struct NetworkInterface: Identifiable, Hashable {
    let id: String      // ifname
    let name: String
    let ip: String
    let kind: InterfaceKind
}

enum NetworkScout {
    static func interfaces() -> [NetworkInterface] {
        var addrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrs) == 0, let first = addrs else { return [] }
        defer { freeifaddrs(addrs) }

        var out: [NetworkInterface] = []
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
                    let name = ifa.ifa_name.map { String(cString: $0) } ?? "?"
                    out.append(NetworkInterface(id: name, name: name, ip: ip, kind: classify(name: name, ip: ip)))
                }
            }
            ptr = ifa.ifa_next
        }
        // Stable order: hotspot, wifi, usb, cellular, other
        let rank: (InterfaceKind) -> Int = {
            switch $0 {
            case .hotspot:  return 0
            case .wifi:     return 1
            case .usb:      return 2
            case .cellular: return 3
            case .other:    return 4
            case .loopback: return 5
            }
        }
        return out.sorted { rank($0.kind) < rank($1.kind) }
    }

    static func classify(name: String, ip: String) -> InterfaceKind {
        if name.hasPrefix("bridge") || name.hasPrefix("ap") { return .hotspot }
        if name.hasPrefix("pdp_ip") || name.hasPrefix("rmnet") { return .cellular }
        if name.hasPrefix("en") {
            // Personal Hotspot via USB lands on an en* with 172.20.10.x.
            if ip.hasPrefix("172.20.10.") { return .hotspot }
            return .wifi
        }
        if name.hasPrefix("utun") || name.hasPrefix("ipsec") { return .other }
        return .other
    }
}
