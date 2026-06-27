//
//  MacSetupInstructionsView.swift
//  MouseMe
//
//  Step-by-step guide for installing the Mac receiver and connecting.
//

import SwiftUI

struct MacSetupInstructionsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("MouseMe is one project that builds for iPhone and Mac. Install the Mac app once — your phone discovers it automatically. No Python or terminal required.", systemImage: "laptopcomputer.and.iphone")
                        .font(.callout)
                }

                Section("1 · Get the project on your Mac") {
                    instruction(1, "Copy the **MouseMe** folder to your Mac. AirDrop the whole project, sync via iCloud Drive, or clone/download from GitHub.")
                    instruction(2, "Save it somewhere permanent, e.g. `~/Developer/MouseMe`.")
                }

                Section("2 · Install Xcode (one time)") {
                    instruction(1, "Open the **Mac App Store** on your Mac and install **Xcode** (free).")
                    instruction(2, "Launch Xcode once so it finishes installing components.")
                }

                Section("3 · Build & run MouseMe on your Mac") {
                    instruction(1, "Double-click **`MouseMe.xcodeproj`** in the project folder.")
                    instruction(2, "At the top of Xcode, click the device menu and choose **My Mac**.")
                    instruction(3, "Press **⌘R** (or click ▶︎). The first build takes about a minute.")
                    instruction(4, "When MouseMe opens, leave **Receiving** turned **on**.")
                    instruction(5, "macOS asks for **Accessibility** permission — open **System Settings → Privacy & Security → Accessibility**, enable **MouseMe**, then return to the app.")
                    instruction(6, "Note the **IP address** and **port 8237** shown in the Mac app window. Keep MouseMe running.")
                }

                Section("4 · Connect from your iPhone") {
                    instruction(1, "Connect **iPhone and Mac to the same Wi-Fi** (not a guest/isolated network).")
                    instruction(2, "Open the **Connect** tab. Under **Computers nearby**, tap your Mac (e.g. “MouseMe Ryan’s Mac”).")
                    instruction(3, "Allow **Local Network** when iOS asks.")
                    instruction(4, "Status shows **Connected** — switch to the **Mouse** tab and start using trackpad, slide, or gyro modes.")
                    instruction(5, "If the Mac doesn’t appear, tap **Add manually** and enter the IP from the Mac app.")
                }

                Section("Desk Slide tip") {
                    Text("For slide mode: lay the phone **face up in portrait** (screen toward ceiling, home button toward you). Tap **Start tracking**, wait half a second, then slide it on the desk like a mouse.")
                        .font(.callout)
                }
            }
            .navigationTitle("Mac Setup")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func instruction(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.accentColor.opacity(0.15)))
            Text(text)
                .font(.callout)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    MacSetupInstructionsView()
}
