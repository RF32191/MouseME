//
//  MediaView.swift
//  MouseMe
//
//  Quick media + system controls: volume, mute, playback, brightness.
//

import SwiftUI

struct MediaView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    transport
                    volumeBlock
                    brightnessBlock
                }
                .padding()
            }
            .appPageChrome()
            .navigationTitle("Media")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .appPageChrome()
        .disabled(!state.client.isConnected)
        .opacity(state.client.isConnected ? 1 : 0.5)
    }

    private var transport: some View {
        HStack(spacing: 18) {
            CircleControl(systemImage: "backward.end.fill", tint: AppTheme.accent) {
                state.client.send(.media(.prev))
            }
            CircleControl(systemImage: "playpause.fill", tint: AppTheme.accent, big: true) {
                state.client.send(.media(.playPause))
            }
            CircleControl(systemImage: "forward.end.fill", tint: AppTheme.accent) {
                state.client.send(.media(.next))
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .appCard(radius: 22)
    }

    private var volumeBlock: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "speaker.wave.2.fill")
                Text("Volume").font(.headline)
                Spacer()
                Button {
                    state.client.send(.media(.mute))
                    Haptics.click()
                } label: {
                    Label("Mute", systemImage: "speaker.slash.fill")
                        .labelStyle(.iconOnly)
                        .padding(10)
                        .background(Circle().fill(AppTheme.cardRaised))
                        .overlay(Circle().stroke(AppTheme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 10) {
                StepControl(systemImage: "speaker.fill") {
                    state.client.send(.media(.volumeDown))
                }
                StepControl(systemImage: "speaker.wave.3.fill") {
                    state.client.send(.media(.volumeUp))
                }
            }
        }
        .padding()
        .appCard(radius: 22)
    }

    private var brightnessBlock: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "sun.max.fill")
                Text("Brightness").font(.headline)
                Spacer()
            }
            HStack(spacing: 10) {
                StepControl(systemImage: "sun.min.fill") {
                    state.client.send(.media(.brightnessDown))
                }
                StepControl(systemImage: "sun.max.fill") {
                    state.client.send(.media(.brightnessUp))
                }
            }
            Text("Brightness keys are platform-specific. Works on Windows; on macOS the helper needs Accessibility access to send F1/F2.")
                .font(.caption2)
                .foregroundStyle(AppTheme.labelTertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .appCard(radius: 22)
    }
}

private struct CircleControl: View {
    let systemImage: String
    let tint: Color
    var big: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            action()
            Haptics.click()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: big ? 36 : 26, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: big ? 78 : 60, height: big ? 78 : 60)
                .background(Circle().fill(tint))
        }
        .buttonStyle(.plain)
    }
}

private struct StepControl: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button {
            action()
            Haptics.tap()
        } label: {
            Image(systemName: systemImage)
                .font(.title2)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(
                    RoundedRectangle(cornerRadius: 14).fill(AppTheme.cardRaised)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border, lineWidth: 1)
                )
                .foregroundStyle(AppTheme.labelSecondary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MediaView().environment(AppState())
}
