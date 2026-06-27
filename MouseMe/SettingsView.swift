//
//  SettingsView.swift
//  MouseMe
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        NavigationStack {
            Form {
                Section("Customisation") {
                    NavigationLink {
                        MouseStylePicker()
                    } label: {
                        Label("Mouse style", systemImage: "paintpalette")
                    }
                    NavigationLink {
                        GamesView()
                    } label: {
                        Label("Games", systemImage: "gamecontroller")
                    }
                }

                Section("Pointer") {
                    HStack {
                        Text("Sensitivity")
                        Spacer()
                        Text(String(format: "%.2f×", state.sensitivity))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $state.sensitivity, in: 0.25...4.0, step: 0.05)

                    HStack {
                        Text("Scroll speed")
                        Spacer()
                        Text(String(format: "%.2f×", state.scrollSensitivity))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $state.scrollSensitivity, in: 0.25...4.0, step: 0.05)

                    Toggle("Invert horizontal", isOn: $state.invertX)
                    Toggle("Invert vertical", isOn: $state.invertY)
                }

                Section("Feedback") {
                    Toggle("Haptics", isOn: $state.hapticsEnabled)
                }

                Section("Motion") {
                    LabeledContent("Gyroscope",
                                   value: state.motion.isAvailable ? "Available" : "Unavailable")
                    LabeledContent("Air-mouse active",
                                   value: state.motion.isRunning ? "Yes" : "No")
                }

                Section {
                    MoreAppsPromoView(style: .list)
                } header: {
                    Text("More from Ryan")
                } footer: {
                    Text("Tap Get to open the App Store.")
                }

                Section("About") {
                    LabeledContent("Bonjour type", value: "_mouseme._tcp")
                    LabeledContent("Default port", value: "8237")
                    Text("MouseMe on iPhone controls your Mac. Install MouseMe on both devices and connect over the same Wi‑Fi.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .onChange(of: state.sensitivity) { _, new in
                state.motion.sensitivity = new
            }
            .onChange(of: state.invertX) { _, new in
                state.motion.invertX = new
            }
            .onChange(of: state.invertY) { _, new in
                state.motion.invertY = new
            }
        }
    }
}

#Preview {
    SettingsView().environment(AppState())
}
