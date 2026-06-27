//
//  QRScannerView.swift
//  MouseMe
//
//  AVFoundation QR-code scanner wrapped as a SwiftUI sheet. Recognises a
//  `mouseme://connect?host=<ip>&port=<port>&name=<label>` URL printed by
//  the desktop helper at startup.
//

import SwiftUI
#if os(iOS)
import AVFoundation
import UIKit
#endif

struct PairingPayload: Equatable, Hashable {
    var host: String
    var port: UInt16
    var name: String?

    /// Accepts both `mouseme://connect?host=…&port=…` URLs and bare
    /// `host:port` strings for forgiving manual entry.
    static func parse(_ raw: String) -> PairingPayload? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("mouseme://") {
            guard let url = URL(string: trimmed),
                  let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            else { return nil }
            let items = comps.queryItems ?? []
            let host = items.first(where: { $0.name == "host" })?.value ?? ""
            let portStr = items.first(where: { $0.name == "port" })?.value ?? ""
            guard !host.isEmpty, let port = UInt16(portStr) else { return nil }
            let name = items.first(where: { $0.name == "name" })?.value
            return PairingPayload(host: host, port: port, name: name)
        }
        // Fallback: "ip:port"
        let parts = trimmed.split(separator: ":")
        if parts.count == 2,
           let port = UInt16(parts[1]) {
            return PairingPayload(host: String(parts[0]), port: port, name: nil)
        }
        return nil
    }
}

#if os(iOS)

struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onScan: (PairingPayload) -> Void

    @State private var error: String?
    @State private var scanned = false

    var body: some View {
        ZStack {
            QRCameraView { string in
                guard !scanned else { return }
                guard let payload = PairingPayload.parse(string) else { return }
                scanned = true
                onScan(payload)
                dismiss()
            } onError: { msg in
                error = msg
            }
            .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .padding()
                    }
                }
                Spacer()
                VStack(spacing: 8) {
                    if let error {
                        Text(error)
                            .padding()
                            .background(.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
                    } else {
                        Text("Point the camera at the QR code printed by the MouseMe helper.")
                            .font(.subheadline)
                            .padding()
                            .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.bottom, 32)
                .padding(.horizontal)
            }
        }
    }
}

private struct QRCameraView: UIViewControllerRepresentable {
    let onCode: (String) -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> QRCameraController {
        QRCameraController(onCode: onCode, onError: onError)
    }
    func updateUIViewController(_ uiViewController: QRCameraController, context: Context) {}
}

final class QRCameraController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    nonisolated(unsafe) private let session = AVCaptureSession()
    nonisolated(unsafe) private var previewLayer: AVCaptureVideoPreviewLayer?
    nonisolated private let onCode: (String) -> Void
    nonisolated private let onError: (String) -> Void
    private let sessionQueue = DispatchQueue(label: "MouseMe.camera")

    init(onCode: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
        self.onCode = onCode
        self.onError = onError
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self else { return }
            if granted {
                self.sessionQueue.async { self.configureAndStart() }
            } else {
                Task { @MainActor in
                    self.onError("Camera permission denied. Enable it in Settings.")
                }
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [session] in
            session.stopRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    nonisolated private func configureAndStart() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            Task { @MainActor in self.onError("No camera available.") }
            return
        }
        session.beginConfiguration()
        if session.canAddInput(input) { session.addInput(input) }
        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]
        }
        session.commitConfiguration()
        session.startRunning()

        Task { @MainActor in
            let layer = AVCaptureVideoPreviewLayer(session: self.session)
            layer.videoGravity = .resizeAspectFill
            layer.frame = self.view.bounds
            self.view.layer.addSublayer(layer)
            self.previewLayer = layer
        }
    }

    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput,
                                    didOutput metadataObjects: [AVMetadataObject],
                                    from connection: AVCaptureConnection) {
        guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = obj.stringValue else { return }
        let cb = onCode
        Task { @MainActor in cb(value) }
    }
}

#endif
