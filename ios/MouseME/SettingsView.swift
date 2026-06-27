import SwiftUI

struct SettingsView: View {

    @ObservedObject var client: WebSocketClient
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Server IP Address", text: $client.serverAddress)
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    TextField("Port", text: $client.serverPort)
                        .keyboardType(.numberPad)
                } header: {
                    Text("Server")
                } footer: {
                    Text("Enter the local IP address of the computer running the MouseME server.")
                }

                Section("Sensitivity") {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Pointer speed")
                            Spacer()
                            Text(String(format: "%.1f×", client.sensitivity))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $client.sensitivity, in: 0.5...5.0, step: 0.5)
                    }
                }

                Section("Connection") {
                    Button(client.isConnected ? "Reconnect" : "Connect") {
                        client.connect()
                        dismiss()
                    }

                    if client.isConnected {
                        Button("Disconnect", role: .destructive) {
                            client.disconnect()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
