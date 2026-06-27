//
//  KeyboardView.swift
//  MouseMe
//
//  Wireless keyboard. Types text, sends special keys (arrows, function keys,
//  Esc/Tab/Return) and modifier shortcuts like Cmd+C / Cmd+V / Ctrl+Z.
//

import SwiftUI

struct KeyboardView: View {
    @Environment(AppState.self) private var state
    @State private var buffer: String = ""
    @State private var lastSent: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    typingCard
                    arrowPad
                    Divider().padding(.horizontal)
                    Text("Shortcuts").font(.headline)
                    shortcutRow
                    Divider().padding(.horizontal)
                    Text("Quick macros").font(.headline)
                    macroRow
                    Divider().padding(.horizontal)
                    Text("Function keys").font(.headline)
                    functionKeyRow
                }
                .padding(.vertical)
                // Empty space at the bottom that captures background taps
                // so the user can dismiss the keyboard and reach the tab bar.
                Color.clear
                    .frame(height: 80)
                    .contentShape(Rectangle())
                    .onTapGesture { focused = false }
            }
            #if os(iOS)
            .scrollDismissesKeyboard(.interactively)
            #endif
            // Tap on any non-control area of the scroll view dismisses
            // the keyboard without blocking button / textfield taps.
            .simultaneousGesture(
                TapGesture().onEnded { focused = false }
            )
            .navigationTitle("Keyboard")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        focused = false
                    } label: {
                        Label("Hide keyboard", systemImage: "keyboard.chevron.compact.down")
                    }
                }
                #endif
                ToolbarItem(placement: .primaryAction) {
                    if focused {
                        Button("Done") { focused = false }
                    }
                }
            }
        }
        .disabled(!state.client.isConnected)
        .opacity(state.client.isConnected ? 1 : 0.5)
        .overlay(alignment: .top) {
            if !state.client.isConnected {
                Text("Connect to a helper to use the keyboard.")
                    .font(.footnote)
                    .padding(8)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Typing card

    private var typingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Type to send")
                .font(.headline)
                .padding(.horizontal)

            TextField("Tap here, then type…", text: $buffer)
                .focused($focused)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.thinMaterial)
                )
                .padding(.horizontal)
                .onChange(of: buffer) { _, new in
                    sendIncrementalText(new)
                }
                .submitLabel(.send)
                .onSubmit {
                    state.client.send(.key("enter"))
                    buffer = ""
                    lastSent = ""
                }

            HStack(spacing: 8) {
                KeyChip(label: "Enter", systemImage: "return") {
                    state.client.send(.key("enter"))
                }
                KeyChip(label: "Tab", systemImage: "arrow.right.to.line") {
                    state.client.send(.key("tab"))
                }
                KeyChip(label: "Esc", systemImage: "escape") {
                    state.client.send(.key("esc"))
                }
                KeyChip(label: "⌫", systemImage: "delete.left") {
                    state.client.send(.key("backspace"))
                    if !buffer.isEmpty { buffer.removeLast() }
                    lastSent = buffer
                }
            }
            .padding(.horizontal)
        }
    }

    private func sendIncrementalText(_ new: String) {
        // Compute the diff between lastSent and new; emit text adds & backspaces.
        let common = lastSent.commonPrefix(with: new)
        let toDelete = lastSent.count - common.count
        let toAdd = String(new.dropFirst(common.count))
        for _ in 0..<toDelete { state.client.send(.key("backspace")) }
        if !toAdd.isEmpty { state.client.send(.text(toAdd)) }
        lastSent = new
    }

    // MARK: - Arrow pad

    private var arrowPad: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Spacer()
                ArrowKey(direction: .up) { state.client.send(.key("up")) }
                Spacer()
            }
            HStack(spacing: 8) {
                ArrowKey(direction: .left)  { state.client.send(.key("left")) }
                ArrowKey(direction: .down)  { state.client.send(.key("down")) }
                ArrowKey(direction: .right) { state.client.send(.key("right")) }
            }
            HStack(spacing: 8) {
                KeyChip(label: "Home", systemImage: "house") {
                    state.client.send(.key("home"))
                }
                KeyChip(label: "End", systemImage: "flag.checkered") {
                    state.client.send(.key("end"))
                }
                KeyChip(label: "Pg↑", systemImage: "chevron.up.2") {
                    state.client.send(.key("pageup"))
                }
                KeyChip(label: "Pg↓", systemImage: "chevron.down.2") {
                    state.client.send(.key("pagedown"))
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Shortcuts

    private var shortcutRow: some View {
        let modKey = "cmd"     // helper translates per-platform
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ShortcutChip(label: "Copy",   combo: "⌘C") {
                    state.client.send(.key("c", mods: [modKey]))
                }
                ShortcutChip(label: "Paste",  combo: "⌘V") {
                    state.client.send(.key("v", mods: [modKey]))
                }
                ShortcutChip(label: "Cut",    combo: "⌘X") {
                    state.client.send(.key("x", mods: [modKey]))
                }
                ShortcutChip(label: "Undo",   combo: "⌘Z") {
                    state.client.send(.key("z", mods: [modKey]))
                }
                ShortcutChip(label: "Redo",   combo: "⇧⌘Z") {
                    state.client.send(.key("z", mods: [modKey, "shift"]))
                }
                ShortcutChip(label: "Save",   combo: "⌘S") {
                    state.client.send(.key("s", mods: [modKey]))
                }
                ShortcutChip(label: "All",    combo: "⌘A") {
                    state.client.send(.key("a", mods: [modKey]))
                }
                ShortcutChip(label: "Find",   combo: "⌘F") {
                    state.client.send(.key("f", mods: [modKey]))
                }
                ShortcutChip(label: "Switch", combo: "⌘Tab") {
                    state.client.send(.key("tab", mods: [modKey]))
                }
                ShortcutChip(label: "Quit",   combo: "⌘Q") {
                    state.client.send(.key("q", mods: [modKey]))
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Function keys

    private var functionKeyRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(1...12, id: \.self) { i in
                    Button("F\(i)") {
                        state.client.send(.key("f\(i)"))
                        if state.hapticsEnabled { Haptics.tap() }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Quick macros

    private var macroRow: some View {
        let mod = "cmd"
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                MacroChip(label: "New tab", systemImage: "plus.square") {
                    state.client.send(.key("t", mods: [mod]))
                }
                MacroChip(label: "Close tab", systemImage: "xmark.square") {
                    state.client.send(.key("w", mods: [mod]))
                }
                MacroChip(label: "Reload", systemImage: "arrow.clockwise") {
                    state.client.send(.key("r", mods: [mod]))
                }
                MacroChip(label: "Address bar", systemImage: "magnifyingglass") {
                    state.client.send(.key("l", mods: [mod]))
                }
                MacroChip(label: "Spotlight", systemImage: "sparkle.magnifyingglass") {
                    state.client.send(.key("space", mods: [mod]))
                }
                MacroChip(label: "Mission Ctrl", systemImage: "rectangle.3.group") {
                    state.client.send(.key("up", mods: ["ctrl"]))
                }
                MacroChip(label: "Show desktop", systemImage: "macwindow") {
                    state.client.send(.key("f11"))
                }
                MacroChip(label: "Screenshot", systemImage: "camera.viewfinder") {
                    state.client.send(.key("4", mods: [mod, "shift"]))
                }
                MacroChip(label: "Lock", systemImage: "lock.fill") {
                    state.client.send(.key("q", mods: [mod, "ctrl"]))
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Building blocks

private struct KeyChip: View {
    let label: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button {
            action()
            Haptics.tap()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                Text(label)
            }
            .font(.callout)
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(.thinMaterial))
        }
        .buttonStyle(.plain)
    }
}

private struct ShortcutChip: View {
    let label: String
    let combo: String
    let action: () -> Void

    var body: some View {
        Button {
            action()
            Haptics.click()
        } label: {
            VStack(spacing: 2) {
                Text(label).font(.caption.bold())
                Text(combo).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(minWidth: 60)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10).fill(.thinMaterial)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct MacroChip: View {
    let label: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button {
            action()
            Haptics.click()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage).font(.title3)
                Text(label).font(.caption2)
            }
            .frame(width: 84, height: 64)
            .background(
                RoundedRectangle(cornerRadius: 12).fill(.thinMaterial)
            )
        }
        .buttonStyle(.plain)
    }
}

private enum ArrowDirection {
    case up, down, left, right
    var symbol: String {
        switch self {
        case .up: "arrow.up"
        case .down: "arrow.down"
        case .left: "arrow.left"
        case .right: "arrow.right"
        }
    }
}

private struct ArrowKey: View {
    let direction: ArrowDirection
    let action: () -> Void

    var body: some View {
        Button {
            action()
            Haptics.tap()
        } label: {
            Image(systemName: direction.symbol)
                .font(.title2)
                .frame(width: 64, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 12).fill(.thinMaterial)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    KeyboardView().environment(AppState())
}
