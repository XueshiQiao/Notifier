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
import os

private let viewLogger = Logger(subsystem: "me.xueshi.Notifier", category: "ContentView")

struct ContentView: View {
    @State private var server = HTTPServer.shared
    @State private var notificationManager = NotificationManager.shared
    @State private var updateChecker = UpdateChecker.shared
    @State private var isAccessibilityGranted = AXIsProcessTrusted()
    @State private var portString = "8000"
    @State private var integrationStatus = ""
    @State private var integrationStatusLevel: IntegrationStatusLevel = .none
    @State private var isApplyingIntegration = false
    @State private var pendingPatchTarget: PatchTarget?
    @State private var showIntegrationAlert = false
    @State private var integrationAlertMode: IntegrationAlertMode = .confirmation
    @State private var isUsageExpanded = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: server.isRunning ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 60))
                    .foregroundStyle(server.isRunning ? .green : .secondary)
                    .frame(width: 60, height: 60, alignment: .bottom)

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

            // Card 3: CLI Integrations
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("CLI Integration")
                        .font(.headline)
                    Spacer()
                    if isApplyingIntegration {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                Text("Patch Claude Code and Gemini CLI config files with Notifier hooks.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Button("Patch Claude code") {
                        requestPatchConfirmation(for: .claudeCode)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(isApplyingIntegration)

                    Button("Patch Gemini Cli") {
                        requestPatchConfirmation(for: .geminiCLI)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(isApplyingIntegration)
                }

            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)

            // Usage Instructions
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isUsageExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Text("Usage")
                            .font(.headline)
                        Spacer()
                        Image(systemName: isUsageExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isUsageExpanded {
                    Text("Send a POST request to http://localhost:\(server.port.formatted(.number.grouping(.never)))")
                        .font(.caption)
                        .monospaced()
                        .textSelection(.enabled)

                    Text("Example with curl:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.top, 4)

                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(verbatim: """
                        curl -X POST http://localhost:\(server.port.formatted(.number.grouping(.never))) \\
                          -H "Content-Type: application/json" \\
                          -d '{
                            "title": "Build Complete",
                            "body": "Project compiled successfully",
                            "subtitle": "Optional Subtitle",
                            "pid": '"$PPID"'
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

                    Text("Supported fields: title, body, subtitle, callback_url, pid (fallback app activation)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)

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
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(minWidth: 400, idealWidth: 400)
        .task {
            await notificationManager.requestAuthorization()
            await updateChecker.startPeriodicChecks()
        }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            isAccessibilityGranted = AXIsProcessTrusted()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task {
                let settings = await UNUserNotificationCenter.current().notificationSettings()
                notificationManager.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
        .alert(integrationAlertTitle, isPresented: $showIntegrationAlert) {
            if integrationAlertMode == .confirmation {
                Button(patchConfirmButtonTitle) {
                    performPendingPatch()
                }
                Button("Cancel", role: .cancel) {
                    pendingPatchTarget = nil
                }
            } else {
                Button("OK", role: .cancel) {}
            }
        } message: {
            Text(integrationAlertMessage)
        }
    }
    
    /// Test notification with sample data
    private func testNotification() async {
        let testRequest = NotificationRequest(
            title: "Test",
            body: "PID is 58415",
            subtitle: nil,
            pid: 58415,
            tty: "/dev/ttys024",
            callbackUrl: nil
        )
        
        do {
            try await notificationManager.postNotification(from: testRequest)
            viewLogger.notice("Test notification posted successfully")
        } catch {
            viewLogger.notice("Test notification failed: \(error)")
        }
    }

    private func applyIntegration(_ operation: () throws -> CLIIntegrationReport) {
        isApplyingIntegration = true
        defer { isApplyingIntegration = false }

        do {
            let report = try operation()
            integrationStatus = report.userFacingMessage
            integrationStatusLevel = report.level
            DispatchQueue.main.async {
                integrationAlertMode = .result
                showIntegrationAlert = true
            }
        } catch {
            integrationStatus = "Integration failed: \(error.localizedDescription)"
            integrationStatusLevel = .error
            viewLogger.error("Integration failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                integrationAlertMode = .result
                showIntegrationAlert = true
            }
        }
    }

    private var patchResultAlertTitle: String {
        switch integrationStatusLevel {
        case .success:
            return "Patch Succeeded"
        case .warning:
            return "Patch Warning"
        case .error:
            return "Patch Failed"
        case .none:
            return "Patch Result"
        }
    }

    private func requestPatchConfirmation(for target: PatchTarget) {
        pendingPatchTarget = target
        integrationAlertMode = .confirmation
        showIntegrationAlert = true
    }

    private func performPendingPatch() {
        guard let target = pendingPatchTarget else { return }
        pendingPatchTarget = nil

        switch target {
        case .claudeCode:
            applyIntegration {
                try CLIIntegrationInstaller.installClaudeCode(port: server.port)
            }
        case .geminiCLI:
            applyIntegration {
                try CLIIntegrationInstaller.installGeminiCLI(port: server.port)
            }
        }
    }

    private var patchConfirmButtonTitle: String {
        switch pendingPatchTarget {
        case .claudeCode:
            return "Patch Claude code"
        case .geminiCLI:
            return "Patch Gemini Cli"
        case .none:
            return "Patch"
        }
    }

    private var patchConfirmationMessage: String {
        let targetText: String
        let fileList: [String]
        switch pendingPatchTarget {
        case .claudeCode:
            targetText = "Claude Code"
            fileList = [
                "~/.claude/settings.json"
            ]
        case .geminiCLI:
            targetText = "Gemini CLI"
            fileList = [
                "~/.gemini/settings.json",
                "~/.gemini/scripts/notify_via_app.py"
            ]
        case .none:
            targetText = "the selected CLI"
            fileList = []
        }

        let fileLines = fileList.isEmpty ? "(none)" : fileList.joined(separator: "\n")
        return """
        Are you sure you want to patch \(targetText) configuration files?

        1. Files to patch:
        \(fileLines)

        2. This action only updates local files and may create .notifier.bak backups.

        3. We do not send any request anywhere during this patch.
        """
    }

    private var integrationAlertTitle: String {
        integrationAlertMode == .confirmation ? "Confirm Patch" : patchResultAlertTitle
    }

    private var integrationAlertMessage: String {
        integrationAlertMode == .confirmation ? patchConfirmationMessage : integrationStatus
    }
}

#Preview {
    ContentView()
}

private struct CLIIntegrationReport {
    let summaryTitle: String
    let updatedFiles: [String]
    let backupFiles: [String]
    let level: IntegrationStatusLevel

    var userFacingMessage: String {
        var sections: [String] = [summaryTitle]
        if !updatedFiles.isEmpty {
            let updatedSection = (["Updated files:"] + updatedFiles.map { displayPath($0) }).joined(separator: "\n")
            sections.append(updatedSection)
        }
        if !backupFiles.isEmpty {
            let backupSection = (["Backup files:"] + backupFiles.map { displayPath($0) }).joined(separator: "\n")
            sections.append(backupSection)
        }
        return sections.joined(separator: "\n\n")
    }

    private func displayPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home + "/") {
            return "~" + String(path.dropFirst(home.count))
        }
        return path
    }
}

private enum CLIIntegrationInstaller {
    static func installClaudeCode(port: UInt16) throws -> CLIIntegrationReport {
        let fileManager = FileManager.default
        let claudeDirURL = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")

        guard directoryExists(at: claudeDirURL) else {
            return CLIIntegrationReport(
                summaryTitle: "Skipped Claude Code patch: ~/.claude folder does not exist!",
                updatedFiles: [],
                backupFiles: [],
                level: .warning
            )
        }

        let configURL = claudeDirURL.appendingPathComponent("settings.json")

        try ensureParentDirectory(for: configURL)
        let backup = try backupExistingFile(at: configURL)

        var rootConfig = try loadConfigObject(from: configURL)
        try upsertClaudeHooks(into: &rootConfig, port: port)
        try writeConfig(rootConfig, to: configURL)

        return CLIIntegrationReport(
            summaryTitle: "Claude Code integration completed!",
            updatedFiles: [configURL.path],
            backupFiles: backup.map { [$0.path] } ?? [],
            level: .success
        )
    }

    static func installGeminiCLI(port: UInt16) throws -> CLIIntegrationReport {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let geminiDirURL = home.appendingPathComponent(".gemini")

        guard directoryExists(at: geminiDirURL) else {
            return CLIIntegrationReport(
                summaryTitle: "Skipped Gemini Cli patch: ~/.gemini folder does not exist!",
                updatedFiles: [],
                backupFiles: [],
                level: .warning
            )
        }

        let configURL = geminiDirURL
            .appendingPathComponent("settings.json")
        let scriptURL = geminiDirURL
            .appendingPathComponent("scripts")
            .appendingPathComponent("notify_via_app.py")

        try ensureParentDirectory(for: configURL)
        try ensureParentDirectory(for: scriptURL)

        let configBackup = try backupExistingFile(at: configURL)
        let scriptBackup = try backupExistingFile(at: scriptURL)

        var rootConfig = try loadConfigObject(from: configURL)
        try upsertGeminiHooks(into: &rootConfig)
        try writeConfig(rootConfig, to: configURL)

        try writeGeminiNotifyScript(to: scriptURL, port: port)

        var backups: [String] = []
        if let configBackup { backups.append(configBackup.path) }
        if let scriptBackup { backups.append(scriptBackup.path) }

        return CLIIntegrationReport(
            summaryTitle: "Gemini Cli integration completed!",
            updatedFiles: [configURL.path, scriptURL.path],
            backupFiles: backups,
            level: .success
        )
    }

    private static func ensureParentDirectory(for fileURL: URL) throws {
        let parent = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
    }

    private static func directoryExists(at directoryURL: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    private static func backupExistingFile(at fileURL: URL) throws -> URL? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        var backupURL = URL(fileURLWithPath: fileURL.path + ".notifier.bak")
        var index = 1
        while fileManager.fileExists(atPath: backupURL.path) {
            backupURL = URL(fileURLWithPath: fileURL.path + ".notifier.bak.\(index)")
            index += 1
        }

        try fileManager.copyItem(at: fileURL, to: backupURL)
        return backupURL
    }

    private static func loadConfigObject(from fileURL: URL) throws -> [String: Any] {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return [:]
        }

        let data = try Data(contentsOf: fileURL)
        if data.trimmingPrefixAndSuffixWhitespaceAndNewlines().isEmpty {
            return [:]
        }

        let json = try JSONSerialization.jsonObject(with: data)
        guard let object = json as? [String: Any] else {
            throw CLIIntegrationInstallerError.invalidRootObject(fileURL.path)
        }
        return object
    }

    private static func writeConfig(_ config: [String: Any], to fileURL: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
        var output = data
        if data.last != 0x0A {
            output.append(0x0A)
        }
        try output.write(to: fileURL, options: .atomic)
    }

    private static func upsertClaudeHooks(into root: inout [String: Any], port: UInt16) throws {
        let preToolRule: [String: Any] = [
            "matcher": "Read|Bash|Edit|Write",
            "hooks": [[
                "type": "command",
                "command": claudePreToolCommand(port: port)
            ]]
        ]

        let notificationRule: [String: Any] = [
            "matcher": "",
            "hooks": [[
                "type": "command",
                "command": claudeNotificationCommand(port: port)
            ]]
        ]

        let stopRule: [String: Any] = [
            "hooks": [[
                "type": "command",
                "command": claudeStopCommand(port: port)
            ]]
        ]

        try upsertRule(into: &root, event: "PreToolUse", newRule: preToolRule) { rule in
            ruleContainsCommand(rule) { command in
                command.contains("Claude Code") && command.contains("localhost:")
            }
        }

        try upsertRule(into: &root, event: "Notification", newRule: notificationRule) { rule in
            ruleContainsCommand(rule) { command in
                command.contains("Claude needs your attention") || command.contains("Claude Code")
            }
        }

        try upsertRule(into: &root, event: "Stop", newRule: stopRule) { rule in
            ruleContainsCommand(rule) { command in
                command.contains("Task finished") && command.contains("Claude Code")
            }
        }
    }

    private static func upsertGeminiHooks(into root: inout [String: Any]) throws {
        let beforeToolRule: [String: Any] = [
            "matcher": "ask_user|run_shell_command|write_file|replace|delete_file",
            "hooks": [[
                "type": "command",
                "name": "BeforeTool Notification",
                "command": "~/.gemini/scripts/notify_via_app.py $PPID"
            ]]
        ]

        let notificationRule: [String: Any] = [
            "matcher": "ToolPermission",
            "hooks": [[
                "type": "command",
                "name": "Notification",
                "command": "~/.gemini/scripts/notify_via_app.py $PPID"
            ]]
        ]

        try upsertRule(into: &root, event: "BeforeTool", newRule: beforeToolRule) { rule in
            ruleContainsCommand(rule) { command in
                command.contains("notify_via_app.py $PPID") || command.contains("notify_via_app.js $PPID")
            }
        }

        try upsertRule(into: &root, event: "Notification", newRule: notificationRule) { rule in
            ruleContainsCommand(rule) { command in
                command.contains("notify_via_app.py $PPID") || command.contains("notify_via_app.js $PPID")
            }
        }
    }

    private static func upsertRule(
        into root: inout [String: Any],
        event: String,
        newRule: [String: Any],
        matchesManagedRule: ([String: Any]) -> Bool
    ) throws {
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        if root["hooks"] != nil && !(root["hooks"] is [String: Any]) {
            throw CLIIntegrationInstallerError.invalidHooksField
        }

        var eventRules = hooks[event] as? [Any] ?? []
        if hooks[event] != nil && !(hooks[event] is [Any]) {
            throw CLIIntegrationInstallerError.invalidHookEvent(event)
        }

        eventRules.removeAll { rule in
            guard let ruleObject = rule as? [String: Any] else { return false }
            return matchesManagedRule(ruleObject)
        }
        eventRules.append(newRule)

        hooks[event] = eventRules
        root["hooks"] = hooks
    }

    private static func ruleContainsCommand(_ rule: [String: Any], predicate: (String) -> Bool) -> Bool {
        guard let hooks = rule["hooks"] as? [Any] else {
            return false
        }
        for hook in hooks {
            guard let hookDict = hook as? [String: Any], let command = hookDict["command"] as? String else {
                continue
            }
            if predicate(command) {
                return true
            }
        }
        return false
    }

    private static func writeGeminiNotifyScript(to fileURL: URL, port: UInt16) throws {
        let script = geminiNotifyScript(port: port)
        guard let data = script.data(using: .utf8) else {
            throw CLIIntegrationInstallerError.scriptEncodingFailed
        }

        try data.write(to: fileURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fileURL.path)
    }

    private static func claudePreToolCommand(port: UInt16) -> String {
        #"""
        INPUT=$(cat) && TOOL=$(echo "$INPUT" | jq -r '.tool_name // "Tool"') && BODY=$(echo "$INPUT" | jq -r 'if .tool_input.file_path then .tool_input.file_path elif .tool_input.command then (.tool_input.command | tostring | .[0:100]) else .tool_name end') && BODY=$(echo "$BODY" | sed "s|$HOME|~|") && curl -s -o /dev/null -X POST http://localhost:\#(port) -H 'Content-Type: application/json' -d "$(jq -n --arg title 'Claude Code' --arg body "$TOOL: $BODY" --arg pid "$PPID" '{title: $title, body: $body, pid: ($pid | tonumber)}')"
        """#
    }

    private static func claudeNotificationCommand(port: UInt16) -> String {
        #"""
        MSG=$(cat | jq -r '.message // "Claude needs your attention"') && curl -s -X POST http://localhost:\#(port) -H 'Content-Type: application/json' -d "$(jq -n --arg title 'Claude Code' --arg body "$MSG" --arg pid "$PPID" '{title: $title, body: $body, pid: ($pid | tonumber)}')"
        """#
    }

    private static func claudeStopCommand(port: UInt16) -> String {
        #"""
        curl -s -X POST http://localhost:\#(port) -H 'Content-Type: application/json' -d "$(jq -n --arg pid "$PPID" '{title: "Claude Code", body: "Task finished", pid: ($pid | tonumber)}')"
        """#
    }

    private static func geminiNotifyScript(port: UInt16) -> String {
        #"""
        #!/usr/bin/env python3
        import json
        import os
        import re
        import sys
        import urllib.request


        def send_notification(payload):
            data = json.dumps(payload).encode("utf-8")
            request = urllib.request.Request(
                "http://localhost:\#(port)/",
                data=data,
                headers={"Content-Type": "application/json"},
                method="POST",
            )
            with urllib.request.urlopen(request, timeout=1):
                pass


        def allow_and_exit():
            sys.stdout.write(json.dumps({"decision": "allow"}))
            return


        try:
            input_data = sys.stdin.read()
            if not input_data:
                allow_and_exit()
                raise SystemExit(0)

            try:
                incoming = json.loads(input_data)
            except Exception:
                allow_and_exit()
                raise SystemExit(0)

            tool_name = incoming.get("tool_name")
            event_name = incoming.get("hook_event_name", "Notification")

            title = "Gemini CLI"
            body = "Action Required"
            subtitle = ""
            should_notify = False

            if event_name == "Notification" and incoming.get("notification_type") == "ToolPermission":
                should_notify = True
                details = incoming.get("details") or {}
                subtitle = "Permission Requested"

                command = details.get("command")
                file_path = details.get("filePath")
                message = incoming.get("message")

                if command:
                    body = f"Run: {command}"
                elif file_path:
                    action = "Edit" if details.get("type") == "edit" else "Write"
                    body = f"{action}: {os.path.basename(file_path)}"
                    directory = os.path.dirname(file_path)
                    if directory and directory != ".":
                        subtitle = directory.replace(os.environ.get("HOME", ""), "~")
                elif message:
                    body = re.sub(r" requires (editing|execution)$", "", re.sub(r"^Tool ", "", message))

            elif tool_name == "ask_user":
                should_notify = True
                questions = ((incoming.get("tool_input") or {}).get("questions")) or []
                first_question = questions[0] if questions else {}
                body = first_question.get("question") or "The agent has a question for you."
                header = first_question.get("header")
                subtitle = f"Question: {header}" if header else "User Choice Requested"

            if should_notify:
                pid = None
                if len(sys.argv) > 1:
                    try:
                        pid = int(sys.argv[1])
                    except ValueError:
                        pid = None

                try:
                    send_notification({
                        "title": title,
                        "body": body,
                        "subtitle": subtitle,
                        "pid": pid,
                    })
                except Exception:
                    pass

        except Exception:
            pass

        allow_and_exit()
        """#
    }
}

private enum CLIIntegrationInstallerError: LocalizedError {
    case invalidRootObject(String)
    case invalidHooksField
    case invalidHookEvent(String)
    case scriptEncodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidRootObject(let path):
            return "Expected a JSON object in \(path)."
        case .invalidHooksField:
            return "The config file has a non-object 'hooks' field."
        case .invalidHookEvent(let event):
            return "The config file has an invalid '\(event)' hook entry."
        case .scriptEncodingFailed:
            return "Failed to encode Gemini integration script."
        }
    }
}

private extension Data {
    func trimmingPrefixAndSuffixWhitespaceAndNewlines() -> Data {
        guard let content = String(data: self, encoding: .utf8) else {
            return self
        }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return Data(trimmed.utf8)
    }
}

private enum PatchTarget {
    case claudeCode
    case geminiCLI
}

private enum IntegrationStatusLevel {
    case none
    case success
    case warning
    case error
}

private enum IntegrationAlertMode {
    case confirmation
    case result
}
