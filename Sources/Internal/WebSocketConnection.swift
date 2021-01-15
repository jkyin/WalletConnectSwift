//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation
import Starscream

class WebSocketConnection {
    let url: WCURL
    private let socket: WebSocket
    private let onConnect: (() -> Void)?
    private let onDisconnect: ((String, UInt16) -> Void)?
    private let onTextReceive: ((String) -> Void)?
    // needed to keep connection alive
    private var pingTimer: Timer?
    // TODO: make injectable on server creation
    private let pingInterval: TimeInterval = 30

    private var requestSerializer: RequestSerializer = JSONRPCSerializer()
    private var responseSerializer: ResponseSerializer = JSONRPCSerializer()

    // serial queue for receiving the calls.
    private let serialCallbackQueue: DispatchQueue

    private(set) var isConnected = false

    deinit {
        print("deinit: \(self)")
    }
    
    init(url: WCURL,
         onConnect: (() -> Void)?,
         onDisconnect: ((String, UInt16) -> Void)?,
         onTextReceive: ((String) -> Void)?) {
        self.url = url
        self.onConnect = onConnect
        self.onDisconnect = onDisconnect
        self.onTextReceive = onTextReceive
        serialCallbackQueue = DispatchQueue(label: "org.walletconnect.swift.connection-\(url.bridgeURL)-\(url.topic)")
        var request = URLRequest(url: url.bridgeURL)
        request.timeoutInterval = pingInterval
        socket = WebSocket(request: request)
        socket.delegate = self
        socket.callbackQueue = serialCallbackQueue
    }

    func connect() {
        socket.connect()
    }

    func disconnect() {
        socket.disconnect()
    }

    func send(_ text: String) {
        guard isConnected else { return }
        socket.write(string: text)
        log(text)
    }

    private func log(_ text: String) {
        if let request = try? requestSerializer.deserialize(text, url: url).json().string {
            LogService.shared.log("WC: ==> \(request)")
        } else if let response = try? responseSerializer.deserialize(text, url: url).json().string {
            LogService.shared.log("WC: ==> \(response)")
        } else {
            LogService.shared.log("WC: ==> \(text)")
        }
    }
    
    private func handleError(_ error: Error?) {
        LogService.shared.log("WC: Error, \(error as NSError?)")
    }
}

extension WebSocketConnection: WebSocketDelegate {
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        switch event {
        case .connected(_):
            isConnected = true
            pingTimer = Timer.scheduledTimer(withTimeInterval: pingInterval, repeats: true) { [weak self] _ in
                LogService.shared.log("WC: ==> ping")
                self?.socket.write(ping: Data())
            }
            onConnect?()
        case .disconnected(let reason, let code):
            isConnected = false
            pingTimer?.invalidate()
            onDisconnect?(reason, code)
        case .text(let string):
            onTextReceive?(string)
        case .binary(_):
            break
        case .ping(_):
            break
        case .pong(_):
            break
        case .viabilityChanged(_):
            break
        case .reconnectSuggested(_):
            break
        case .cancelled:
            isConnected = false
        case let .error(error):
            isConnected = false
            handleError(error)
        }
    }
}
