//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation
import WalletConnectSwift

protocol WalletConnectDelegate {
    func failedToConnect()
    func didConnect()
    func didConnectBridgeServer()
    func didDisconnect()
}

class WalletConnect {
    var client: Client!
    var session: Session!
    var delegate: WalletConnectDelegate

    let sessionKey = "sessionKey"

    init(delegate: WalletConnectDelegate) {
        self.delegate = delegate
    }

    func connect() -> String {
        // gnosis wc bridge: https://safe-walletconnect.gnosis.io
        // test bridge with latest protocol version: https://bridge.walletconnect.org
        let wcUrl =  WCURL(topic: UUID().uuidString.lowercased(),
                           bridgeURL: URL(string: "https://bridge.walletconnect.org")!,
                           key: try! randomKey())
        let clientMeta = Session.ClientMeta(name: "ExampleDApp",
                                            description: "WalletConnectSwift",
                                            icons: [],
                                            url: URL(string: "https://jkyin.me")!)
        let dAppInfo = Session.DAppInfo(peerId: UUID().uuidString.lowercased(), peerMeta: clientMeta)
        client = Client(delegate: self, dAppInfo: dAppInfo)

        try! client.connect(to: wcUrl)
        return wcUrl.absoluteString
    }

    func reconnectIfNeeded() {
        if let oldSessionObject = UserDefaults.standard.object(forKey: sessionKey) as? Data,
            let session = try? JSONDecoder().decode(Session.self, from: oldSessionObject) {
            client = Client(delegate: self, dAppInfo: session.dAppInfo)
            try? client.reconnect(to: session)
        }
    }

    // https://developer.apple.com/documentation/security/1399291-secrandomcopybytes
    private func randomKey() throws -> String {
        var bytes = [Int8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status == errSecSuccess {
            return Data(bytes: bytes, count: 32).toHexString()
        } else {
            // we don't care in the example app
            enum TestError: Error {
                case unknown
            }
            throw TestError.unknown
        }
    }
}

extension WalletConnect: ClientDelegate {
    func client(_ client: Client, didFailToConnect url: WCURL, error: Error?) {
        delegate.failedToConnect()
    }

    func client(_ client: Client, didConnect session: Session) {
        self.session = session
        let sessionData = try! JSONEncoder().encode(session)
        UserDefaults.standard.set(sessionData, forKey: sessionKey)
        delegate.didConnect()
    }
    
    func client(_ client: Client, didConnect bridgeServer: WCURL) {
        delegate.didConnectBridgeServer()
    }

    func client(_ client: Client, didDisconnect session: Session) {
        UserDefaults.standard.removeObject(forKey: sessionKey)
        delegate.didDisconnect()
    }
}
