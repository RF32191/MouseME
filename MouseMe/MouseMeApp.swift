//
//  MouseMeApp.swift
//  MouseMe
//
//  Created by Ryan Joshua Fermoselle on 6/18/26.
//

import SwiftUI

@main
struct MouseMeApp: App {
    @State private var app = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(app)
                #if os(iOS)
                .preferredColorScheme(.dark)
                .tint(AppTheme.accent)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 480, height: 680)
        #endif
    }
}
