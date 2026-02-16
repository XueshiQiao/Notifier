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
    @State private var updateChecker = UpdateChecker.shared
    @State private var isAccessibilityGranted = AXIsProcessTrusted()
    @State private var portString = "8000"
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: server.isRunning ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 60))
                    .foregroundStyle(server.isRunning ? .green : .secondary)
                    .symbolEffect(.variableColor, isActive: server.isRunning)

                Text("HTTP Notification Server")
                    .font(.title)
                    .fontWeight(.bold)

                if updateChecker.updateAvailable, let version = updateChecker.latestVersion {
                    Link(destination: URL(string: "https://github.com/XueshiQiao/Notifier/releases/latest")!) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 8, height: 8)
                            Text("Update Available: v\(version)")
                                .font(.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.top)

            // Card 1: HTTP Server
            VStack(alignment: .leading, spacing: 16) {
                Text("HTTP Server")
                    .font(.headline)

                HStack {
                    Text("Status:")
                        .fontWeight(.semibold)
                    Spacer()
                    Circle()
                        .fill(server.isRunning ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    Text(server.isRunning ? "Running" : "Stopped")
                        .foregroundStyle(server.isRunning ? .green : .red)
                }

                HStack {
                    Text("Port:")
                        .fontWeight(.semibold)
                    Spacer()
                    TextField("Port", text: $portString)
                        .monospaced()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                        .disabled(server.isRunning)
                        .onChange(of: portString) {
                            if let p = UInt16(portString) {
                                server.port = p
                            }
                        }
                }

                if server.isRunning {
                    Button(action: { server.stop() }) {
                        Label("Stop Server", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.large)
                } else {
                    Button(action: { server.start() }) {
                        Label("Start Server", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)

            // Card 2: Permissions
            VStack(alignment: .leading, spacing: 16) {
                Text("Permissions")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Notifications:")
                            .fontWeight(.semibold)
                        Spacer()
                        if notificationManager.isAuthorized {
                            Text("Authorized")
                                .foregroundStyle(.green)
                        } else {
                            Button("Grant") {
                                NSWorkspace.shared.open(
                                    URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!
                                )
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .controlSize(.small)
                        }
                    }
                    Text("Post notification on receiving request")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Accessibility:")
                            .fontWeight(.semibold)
                        Spacer()
                        if isAccessibilityGranted {
                            Text("Authorized")
                                .foregroundStyle(.green)
                        } else {
                            Button("Grant") {
                                NSWorkspace.shared.open(
                                    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                                )
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .controlSize(.small)
                        }
                    }
                    Text("Bring minimized windows to front when activating apps.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)

            // Usage Instructions
            VStack(alignment: .leading, spacing: 8) {
                Text("Usage")
                    .font(.headline)

                Text("Send a POST request to http://localhost:\(server.port.formatted(.number.grouping(.never)))")
                    .font(.caption)
                    .monospaced()
                    .textSelection(.enabled)

                Text("Example with curl:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.top, 4)

                ScrollView(.horizontal, showsIndicators: false) {
                    Text("""
                    curl -X POST http://localhost:\(server.port.formatted(.number.grouping(.never))) \\
                      -H "Content-Type: application/json" \\
                      -d '{
                        "title": "Build Complete",
                        "body": "Project compiled successfully",
                        "subtitle": "Optional Subtitle",
                        "pid": 1234
                      }'
                    """)
                    .font(.system(size: 11))
                    .monospaced()
                    .padding(10)
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundStyle(.white)
                    .textSelection(.enabled)
                }
                .background(Color.black.opacity(0.8))
                .cornerRadius(8)
                
                Text("Supported fields: title, body, subtitle, pid (activates app)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)

            Spacer()

            // Footer
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Text("v\(updateChecker.currentVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Button {
                        Task { await updateChecker.checkForUpdate() }
                    } label: {
                        if updateChecker.isChecking {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Text("Check for Updates")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                    .disabled(updateChecker.isChecking)
                }

                HStack(spacing: 4) {
                    Link("GitHub", destination: URL(string: "https://github.com/XueshiQiao/Notifier")!)
                        .font(.caption)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text("\u{00A9} 2026 XueshiQiao")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 4)
        }
        .padding()
        .frame(minWidth: 400, idealWidth: 400, minHeight: 560, idealHeight: 560)
        .task {
            await notificationManager.requestAuthorization()
            await updateChecker.startPeriodicChecks()
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
