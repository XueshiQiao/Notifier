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

        let pid = userInfo["pid"] as? Int

        if let pid = pid {
            print("📱 Notification clicked - attempting to activate app with PID: \(pid)")
            activateApp(withPID: pid)
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
    private func activateApp(withPID pid: Int) {
        let runningApps = NSWorkspace.shared.runningApplications

        if let app = findAndActivateApp(forPID: pid_t(pid), in: runningApps, depth: 0, visited: []) {
            activateApplication(app, originalPID: pid)
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
    private func activateApplication(_ app: NSRunningApplication, originalPID: Int) {
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
}
