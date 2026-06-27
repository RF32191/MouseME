import Foundation
import Combine

/// Manages the WebSocket connection to the MouseME server running on the host computer.
final class WebSocketClient: ObservableObject {

    // MARK: - Published state

    @Published var isConnected = false
    @Published var serverAddress: String {
        didSet { UserDefaults.standard.set(serverAddress, forKey: "serverAddress") }
    }
    @Published var serverPort: String {
        didSet { UserDefaults.standard.set(serverPort, forKey: "serverPort") }
    }
    @Published var sensitivity: Double {
        didSet { UserDefaults.standard.set(sensitivity, forKey: "sensitivity") }
    }

    // MARK: - Private

    private var webSocket: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private var pingTask: Task<Void, Never>?

    // MARK: - Init

    init() {
        serverAddress = UserDefaults.standard.string(forKey: "serverAddress") ?? ""
        serverPort    = UserDefaults.standard.string(forKey: "serverPort")    ?? "8765"
        sensitivity   = UserDefaults.standard.double(forKey: "sensitivity").nonZero ?? 1.5
    }

    // MARK: - Connection

    func connect() {
        guard !serverAddress.isEmpty,
              let port = Int(serverPort),
              let url  = URL(string: "ws://\(serverAddress):\(port)") else { return }

        disconnect()

        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()

        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard let self, self.isConnected else { break }
                self.sendPing()
            }
        }

        DispatchQueue.main.async { self.isConnected = true }
    }

    func disconnect() {
        pingTask?.cancel()
        pingTask = nil
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        DispatchQueue.main.async { self.isConnected = false }
    }

    // MARK: - Mouse events

    /// Send a relative pointer movement to the server.
    func sendMove(dx: Double, dy: Double) {
        let scaledDx = dx * sensitivity
        let scaledDy = dy * sensitivity
        send(["action": "move", "dx": scaledDx, "dy": scaledDy])
    }

    /// Send a left (primary) click.
    func sendClick() {
        send(["action": "click"])
    }

    /// Send a double click.
    func sendDoubleClick() {
        send(["action": "double_click"])
    }

    /// Send a right (secondary) click.
    func sendRightClick() {
        send(["action": "right_click"])
    }

    /// Send a scroll event.  Positive amount scrolls up, negative scrolls down.
    func sendScroll(amount: Double) {
        send(["action": "scroll", "amount": amount])
    }

    // MARK: - Helpers

    private func sendPing() {
        webSocket?.sendPing { [weak self] error in
            if error != nil {
                DispatchQueue.main.async { self?.isConnected = false }
            }
        }
    }

    private func send(_ dict: [String: Any]) {
        guard isConnected,
              let data = try? JSONSerialization.data(withJSONObject: dict),
              let text = String(data: data, encoding: .utf8) else { return }
        webSocket?.send(.string(text)) { _ in }
    }
}

// MARK: - Double helper

private extension Double {
    /// Returns self if non-zero, otherwise the provided default.
    var nonZero: Double? { self == 0 ? nil : self }
}
