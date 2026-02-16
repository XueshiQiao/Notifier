//
//  ContentView.swift
//  Notifier
//
//  Created by Xueshi Qiao on 2/16/26.
//

import SwiftUI
import AppKit
import Combine
import UserNotifications

struct ContentView: View {
    @State private var server = HTTPServer()
    @State private var notificationManager = NotificationManager.shared
    @State private var isAccessibilityGranted = AXIsProcessTrusted()
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: server.isRunning ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 60))
                    .foregroundStyle(server.isRunning ? .green : .secondary)
                    .symbolEffect(.variableColor, isActive: server.isRunning)
                
                Text("HTTP Notification Server")
                    .font(.title)
                    .fontWeight(.bold)
            }
            .padding(.top)
            
            Divider()
            
            // Server Status
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Status:")
                        .fontWeight(.semibold)
                    Spacer()
                    Circle()
                        .fill(server.isRunning ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                    Text(server.isRunning ? "Running" : "Stopped")
                        .foregroundStyle(server.isRunning ? .green : .red)
                }
                
                HStack {
                    Text("Port:")
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(server.port)")
                        .monospaced()
                }
                
                HStack {
                    Text("Notifications:")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(notificationManager.isAuthorized ? "Authorized" : "Not Authorized")
                        .foregroundStyle(notificationManager.isAuthorized ? .green : .orange)
                }

                HStack {
                    Text("Accessibility:")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(isAccessibilityGranted ? "Authorized" : "Not Authorized")
                        .foregroundStyle(isAccessibilityGranted ? .green : .orange)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Message:")
                        .fontWeight(.semibold)
                    Text(server.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)
            
            // Control Buttons
            VStack(spacing: 12) {
                if server.isRunning {
                    Button(action: {
                        server.stop()
                    }) {
                        Label("Stop Server", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                } else {
                    Button(action: {
                        server.start()
                    }) {
                        Label("Start Server", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                if !notificationManager.isAuthorized {
                    Button(action: {
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!
                        )
                    }) {
                        Label("Grant Notification Permission", systemImage: "bell.badge")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                if !isAccessibilityGranted {
                    Button(action: {
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                        )
                    }) {
                        Label("Grant Accessibility Permission", systemImage: "lock.shield")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                
                // Test Button
                Button(action: {
                    Task {
                        await testNotification()
                    }
                }) {
                    Label("Test Notification", systemImage: "bell.badge.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
            
            Divider()
            
            // Usage Instructions
            VStack(alignment: .leading, spacing: 8) {
                Text("Usage")
                    .font(.headline)
                
                Text("Send a POST request to http://localhost:\(server.port)")
                    .font(.caption)
                    .monospaced()
                
                Text("Example with curl:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.top, 4)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    Text("""
                    curl -X POST http://localhost:8000 \\
                      -H "Content-Type: application/json" \\
                      -d '{"title":"Hello","body":"Test notification","subtitle":"Optional","pid":1234}'
                    """)
                    .font(.system(size: 10))
                    .monospaced()
                    .padding(8)
                    .background(Color.black.opacity(0.8))
                    .foregroundStyle(.white)
                    .cornerRadius(6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 400, idealWidth: 400, minHeight: 600, idealHeight: 600)
        .task {
            await notificationManager.requestAuthorization()
        }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            isAccessibilityGranted = AXIsProcessTrusted()
            Task {
                let settings = await UNUserNotificationCenter.current().notificationSettings()
                notificationManager.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    /// Test notification with sample data
    private func testNotification() async {
        let testRequest = NotificationRequest(
            title: "Test",
            body: "PID is 58415",
            subtitle: nil,
            pid: 58415,
            tty: "/dev/ttys024"
        )
        
        do {
            try await notificationManager.postNotification(from: testRequest)
            print("🧪 Test notification posted successfully")
        } catch {
            print("❌ Test notification failed: \(error)")
        }
    }
}

#Preview {
    ContentView()
}
