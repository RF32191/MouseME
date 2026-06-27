//
//  DeveloperApps.swift
//  MouseMe
//

import SwiftUI
#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

struct DeveloperApp: Identifiable, Hashable {
    let id: String
    let name: String
    let tagline: String
    let appStoreID: String
    let symbolName: String
    let tint: Color

    var appStoreURL: URL {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)")!
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: DeveloperApp, rhs: DeveloperApp) -> Bool {
        lhs.id == rhs.id
    }
}

enum DeveloperApps {
    static let catalog: [DeveloperApp] = [
        DeveloperApp(
            id: "opendesign",
            name: "OpenDesign",
            tagline: "3D, circuits, sketch & more — one creative studio.",
            appStoreID: "6758026545",
            symbolName: "cube.transparent.fill",
            tint: .purple
        ),
        DeveloperApp(
            id: "mogme",
            name: "MogMe",
            tagline: "Mog better with AI — face, body, fitness & games.",
            appStoreID: "6757411615",
            symbolName: "sparkles",
            tint: .orange
        ),
        DeveloperApp(
            id: "lifeinc",
            name: "Life Incorporated",
            tagline: "Create and perfect life — evolve from spark to civilization.",
            appStoreID: "6774629901",
            symbolName: "leaf.fill",
            tint: .green
        ),
    ]

    static var promoted: [DeveloperApp] { catalog }
}

enum AppStoreOpener {
    static func open(_ app: DeveloperApp) {
        #if os(macOS)
        NSWorkspace.shared.open(app.appStoreURL)
        #elseif canImport(UIKit)
        UIApplication.shared.open(app.appStoreURL)
        #endif
    }
}
