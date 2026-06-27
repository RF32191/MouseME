//
//  ContentView.swift
//  MouseMe
//
//  Created by Ryan Joshua Fermoselle on 6/18/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        #if os(macOS)
        MacReceiverView()
        #else
        TabView {
            MouseSurfaceView()
                .tabItem { Label("Mouse", systemImage: "cursorarrow.motionlines") }

            KeyboardView()
                .tabItem { Label("Keyboard", systemImage: "keyboard") }

            MediaView()
                .tabItem { Label("Media", systemImage: "playpause.fill") }

            TVRemoteView()
                .tabItem { Label("TV", systemImage: "tv") }

            ConnectView()
                .tabItem { Label("Connect", systemImage: "antenna.radiowaves.left.and.right") }
                .badge(state.client.isConnected ? nil : "!")

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(AppTheme.accent)
        .appScreenBackground()
        .toolbarBackground(AppTheme.backgroundTop, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(AppTheme.backgroundTop, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        #endif
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
