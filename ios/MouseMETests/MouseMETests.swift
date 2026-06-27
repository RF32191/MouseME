import XCTest
@testable import MouseME

final class MouseMETests: XCTestCase {

    // MARK: - WebSocketClient defaults

    func testDefaultPort() {
        let client = WebSocketClient()
        XCTAssertEqual(client.serverPort, "8765")
    }

    func testDefaultSensitivity() {
        let client = WebSocketClient()
        XCTAssertEqual(client.sensitivity, 1.5, accuracy: 0.01)
    }

    func testInitialConnectionState() {
        let client = WebSocketClient()
        XCTAssertFalse(client.isConnected)
    }

    // MARK: - Sensitivity persistence

    func testSensitivityPersistence() {
        let client = WebSocketClient()
        client.sensitivity = 3.0
        XCTAssertEqual(UserDefaults.standard.double(forKey: "sensitivity"), 3.0, accuracy: 0.01)
    }

    // MARK: - Server address persistence

    func testServerAddressPersistence() {
        let client = WebSocketClient()
        client.serverAddress = "192.168.0.42"
        XCTAssertEqual(UserDefaults.standard.string(forKey: "serverAddress"), "192.168.0.42")
    }

    // MARK: - Port persistence

    func testPortPersistence() {
        let client = WebSocketClient()
        client.serverPort = "9000"
        XCTAssertEqual(UserDefaults.standard.string(forKey: "serverPort"), "9000")
    }
}
