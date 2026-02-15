//
//  HTTPServer.swift
//  Notifier
//
//  Created by Xueshi Qiao on 2/16/26.
//

import Foundation
import Network

/// HTTP Server that listens on port 8000 and handles POST requests
@Observable
class HTTPServer {
    private var listener: NWListener?
    private(set) var isRunning = false
    private(set) var statusMessage = "Server not started"
    private var connections: [NWConnection] = []
    
    let port: UInt16 = 8000
    
    /// Start the HTTP server
    func start() {
        guard listener == nil else {
            statusMessage = "Server already running"
            return
        }
        
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: port))
            
            listener?.stateUpdateHandler = { [weak self] state in
                guard let self = self else { return }
                
                switch state {
                case .ready:
                    self.isRunning = true
                    self.statusMessage = "Server running on port \(self.port)"
                    print("✅ HTTP Server listening on port \(self.port)")
                    
                case .failed(let error):
                    self.isRunning = false
                    self.statusMessage = "Server failed: \(error.localizedDescription)"
                    print("❌ Server failed: \(error)")
                    
                case .cancelled:
                    self.isRunning = false
                    self.statusMessage = "Server stopped"
                    print("⚠️ Server cancelled")
                    
                default:
                    break
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            listener?.start(queue: .main)
            
        } catch {
            statusMessage = "Failed to start: \(error.localizedDescription)"
            print("❌ Failed to start server: \(error)")
        }
    }
    
    /// Stop the HTTP server
    func stop() {
        listener?.cancel()
        listener = nil
        
        // Close all active connections
        connections.forEach { $0.cancel() }
        connections.removeAll()
        
        isRunning = false
        statusMessage = "Server stopped"
    }
    
    /// Handle incoming connection
    private func handleConnection(_ connection: NWConnection) {
        connections.append(connection)
        
        connection.stateUpdateHandler = { [weak self] state in
            if case .failed(_) = state, let self = self {
                self.connections.removeAll { $0 === connection }
            } else if case .cancelled = state, let self = self {
                self.connections.removeAll { $0 === connection }
            }
        }
        
        connection.start(queue: .main)
        receiveRequest(on: connection)
    }
    
    /// Receive HTTP request data
    private func receiveRequest(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Receive error: \(error)")
                connection.cancel()
                return
            }
            
            if let data = data, !data.isEmpty {
                self.handleRequest(data: data, connection: connection)
            }
            
            if isComplete {
                connection.cancel()
            }
        }
    }
    
    /// Parse and handle HTTP request
    private func handleRequest(data: Data, connection: NWConnection) {
        guard let requestString = String(data: data, encoding: .utf8) else {
            sendResponse(statusCode: 400, body: "Invalid request encoding", to: connection)
            return
        }
        
        let lines = requestString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            sendResponse(statusCode: 400, body: "Invalid request", to: connection)
            return
        }
        
        let components = requestLine.components(separatedBy: " ")
        guard components.count >= 2 else {
            sendResponse(statusCode: 400, body: "Malformed request line", to: connection)
            return
        }
        
        let method = components[0]
        
        // Only accept POST requests
        guard method == "POST" else {
            sendResponse(statusCode: 405, body: "Method Not Allowed. Use POST.", to: connection)
            return
        }
        
        // Find the body (after the blank line)
        if let bodyStartIndex = requestString.range(of: "\r\n\r\n") {
            let bodyString = String(requestString[bodyStartIndex.upperBound...])
            handlePostRequest(body: bodyString, connection: connection)
        } else {
            sendResponse(statusCode: 400, body: "Missing request body", to: connection)
        }
    }
    
    /// Handle POST request body
    private func handlePostRequest(body: String, connection: NWConnection) {
        guard let bodyData = body.data(using: .utf8) else {
            sendResponse(statusCode: 400, body: "Invalid body encoding", to: connection)
            return
        }
        
        // Parse JSON
        let decoder = JSONDecoder()
        do {
            let notificationRequest = try decoder.decode(NotificationRequest.self, from: bodyData)
            
            // Validate request
            guard notificationRequest.isValid else {
                sendResponse(statusCode: 400, body: "Invalid notification data: title and body are required", to: connection)
                return
            }
            
            // Post notification
            Task { @MainActor in
                do {
                    try await NotificationManager.shared.postNotification(from: notificationRequest)
                    sendResponse(statusCode: 200, body: "Notification posted successfully", to: connection)
                } catch {
                    sendResponse(statusCode: 500, body: "Failed to post notification: \(error.localizedDescription)", to: connection)
                }
            }
            
        } catch {
            sendResponse(statusCode: 400, body: "Invalid JSON: \(error.localizedDescription)", to: connection)
        }
    }
    
    /// Send HTTP response
    private func sendResponse(statusCode: Int, body: String, to connection: NWConnection) {
        let statusText: String
        switch statusCode {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 405: statusText = "Method Not Allowed"
        case 500: statusText = "Internal Server Error"
        default: statusText = "Unknown"
        }
        
        let response = """
        HTTP/1.1 \(statusCode) \(statusText)\r
        Content-Type: text/plain\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """
        
        guard let responseData = response.data(using: .utf8) else { return }
        
        connection.send(content: responseData, completion: .contentProcessed { error in
            if let error = error {
                print("❌ Send error: \(error)")
            }
            connection.cancel()
        })
    }
}
