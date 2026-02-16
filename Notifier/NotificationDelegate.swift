//
//  NotificationDelegate.swift
//  Notifier
//
//  Created by Xueshi Qiao on 2/16/26.
//

import Foundation
import UserNotifications
import AppKit

/// Handles notification interactions and activates apps based on PID
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    /// Called when user interacts with a notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Extract PID and TTY from userInfo
        let pid = userInfo["pid"] as? Int
        let tty = userInfo["tty"] as? String

        if let pid = pid {
            print("📱 Notification clicked - attempting to activate app with PID: \(pid)")
            if let tty = tty {
                print("📱 TTY specified: \(tty)")
            }
            activateApp(withPID: pid, tty: tty)
        } else {
            print("ℹ️ Notification clicked - no PID provided")
        }

        completionHandler()
    }
    
    /// Called when a notification is delivered while app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    /// Activates (brings to front) the application with the given PID
    private func activateApp(withPID pid: Int, tty: String?) {
        let runningApps = NSWorkspace.shared.runningApplications
        
        if let app = findAndActivateApp(forPID: pid_t(pid), in: runningApps, depth: 0, visited: []) {
            activateApplication(app, originalPID: pid, tty: tty)
        } else {
            print("❌ No running application found with PID: \(pid) or its parents")
            
            // List available PIDs for debugging
            print("Available PIDs:")
            runningApps.prefix(10).forEach { app in
                print("  - \(app.localizedName ?? "Unknown"): PID \(app.processIdentifier)")
            }
        }
    }
    
    /// Recursively find the application by checking current PID and traversing up the process tree
    private func findAndActivateApp(
        forPID pid: pid_t,
        in runningApps: [NSRunningApplication],
        depth: Int,
        visited: Set<pid_t>
    ) -> NSRunningApplication? {
        // Safety: Stop at maximum depth
        guard depth < 20 else {
            print("⚠️ Reached maximum depth (20) in process tree")
            return nil
        }
        
        // Safety: Prevent cycles
        guard !visited.contains(pid) else {
            print("⚠️ Cycle detected in process tree at PID: \(pid)")
            return nil
        }
        
        let indent = String(repeating: "  ", count: depth)
        
        // Check if current PID is a running application
        if let app = runningApps.first(where: { $0.processIdentifier == pid }) {
            if depth == 0 {
                print("\(indent)✅ Found app directly: \(app.localizedName ?? "Unknown") (PID: \(pid))")
            } else {
                print("\(indent)✅ Found parent app: \(app.localizedName ?? "Unknown") (PID: \(pid))")
            }
            return app
        }
        
        // Not found, get parent PID and recurse
        guard let parentPID = getParentPID(of: pid) else {
            print("\(indent)🔍 Reached top of process tree (no parent for PID: \(pid))")
            return nil
        }
        
        print("\(indent)🔍 PID \(pid) → Parent PID \(parentPID)")
        
        // Recurse with parent PID
        var newVisited = visited
        newVisited.insert(pid)
        
        return findAndActivateApp(
            forPID: parentPID,
            in: runningApps,
            depth: depth + 1,
            visited: newVisited
        )
    }
    
    /// Get the parent PID of a given process
    private func getParentPID(of pid: pid_t) -> pid_t? {
        var kinfo = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        
        let result = sysctl(&mib, u_int(mib.count), &kinfo, &size, nil, 0)
        
        guard result == 0 else {
            return nil
        }
        
        let parentPID = kinfo.kp_eproc.e_ppid
        
        // PID 0 or 1 means we've reached the top
        return parentPID > 1 ? parentPID : nil
    }
    
    /// Actually activate the application
    private func activateApplication(_ app: NSRunningApplication, originalPID: Int, tty: String?) {
        let appName = app.localizedName ?? "Unknown"

        // Unhide the app if it's hidden
        if app.isHidden {
            app.unhide()
            print("👁️ Unhid app: \(appName)")
        }

        // Unminimize any minimized windows via Accessibility API
        unminimizeWindows(forPID: app.processIdentifier)

        // Activate with all windows brought to front
        if app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps]) {
            print("✅ Successfully activated app: \(appName) (PID: \(app.processIdentifier), Original PID: \(originalPID))")
        } else {
            print("⚠️ Activation failed for: \(appName) (PID: \(app.processIdentifier))")
        }

        handleTerminalTabSwitchIfNeeded(app: app, tty: tty)
    }

    /// Unminimize all minimized windows for a given PID using Accessibility API
    private func unminimizeWindows(forPID pid: pid_t) {
        guard AXIsProcessTrusted() else {
            print("⚠️ Accessibility permission not granted, skipping unminimize")
            return
        }

        let appElement = AXUIElementCreateApplication(pid)

        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)

        guard result == .success, let windows = windowsRef as? [AXUIElement] else {
            print("🔍 Could not retrieve windows via Accessibility API (error: \(result.rawValue))")
            return
        }

        for window in windows {
            var minimizedRef: CFTypeRef?
            let minResult = AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimizedRef)

            if minResult == .success,
               let isMinimized = (minimizedRef as? NSNumber)?.boolValue,
               isMinimized {
                let setResult = AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
                if setResult == .success {
                    print("📤 Unminimized a window")
                } else {
                    print("⚠️ Failed to unminimize window (error: \(setResult.rawValue))")
                }
            }
        }
    }

    
    /// Handle Terminal.app tab switching if needed
    private func handleTerminalTabSwitchIfNeeded(app: NSRunningApplication, tty: String?) {
        return; //TODO don't switch tab now.
//        guard let bundleID = app.bundleIdentifier,
//              bundleID == "com.apple.Terminal",
//              let tty = tty else {
//            return
//        }
//        
//        switchTerminalTab(toTTY: tty)
    }
    
    /// Switch to specific Terminal.app tab by TTY (assumes Terminal is already activated)
    private func switchTerminalTab(toTTY tty: String) {
        print("🖥️ Switching to Terminal tab with TTY: \(tty)")
        
        // Simplified AppleScript that assumes Terminal is already running and activated
        let script = """
        tell application "Terminal"
            -- 🌟 1. 极其关键：强制唤醒 Terminal 应用，抢夺系统前台焦点！
            activate
            repeat with w in windows
                repeat with t in tabs of w
                    try
                        
                        if tty of t as string is "\(tty)" then
                            log "🎉 找到目标 Tab，准备拉起！"
                            
                            -- 🌟 2. 选中这个特定的 Tab
                            set selected of t to true
                            
                            -- 🌟 3. 兜底策略：如果该窗口被最小化到程序坞了（黄色的减号），把它放出来
                            if miniaturized of w is true then
                                set miniaturized of w to false
                            end if
                            
                            -- 🌟 4. 将包含该 Tab 的窗口提到所有 Terminal 窗口的最前面
                            set index of w to 1
                            
                            return "SUCCESS"
                        end if
                    on error errMsg
                        -- 💡 养成好习惯：加上错误捕获，以后代码就不会变“瞎子”了
                        return "❌ 发生底层报错: " & errMsg
                    end try
                end repeat
            end repeat
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
            
            if let error = error {
                print("⚠️ Terminal tab switch failed: \(error)")
                print("💡 Make sure Terminal.app has the specified TTY: \(tty)")
            } else {
                print("✅ Successfully switched to Terminal tab with TTY: \(tty)")
            }
        }
    }
    
}
