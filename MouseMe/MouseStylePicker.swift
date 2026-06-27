//
//  MouseStylePicker.swift
//  MouseMe
//

import SwiftUI

struct MouseStylePicker: View {
    @Environment(AppState.self) private var state

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    var body: some View {
        @Bindable var state = state
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(MouseStyle.allCases) { style in
                    StyleTile(style: style, selected: state.style == style) {
                        state.style = style
                        Haptics.tap()
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Mouse Style")
    }
}

private struct StyleTile: View {
    let style: MouseStyle
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: style.symbol)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(style.tint)
                Text(style.title)
                    .font(.headline)
                Text(style.blurb)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.thinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(selected ? style.tint : .clear, lineWidth: 3)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MouseStylePicker().environment(AppState())
}
