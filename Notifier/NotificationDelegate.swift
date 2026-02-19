//
//  NotificationDelegate.swift
//  Notifier
//
//  Created by Xueshi Qiao on 2/16/26.
//

import Foundation
import UserNotifications
import AppKit
import os

/// Handles notification interactions and activates apps based on PID
private let delegateLogger = Logger(subsystem: "me.xueshi.Notifier", category: "NotificationDelegate")

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    /// Called when user interacts with a notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        let callbackUrl = userInfo["callback_url"] as? String
        let pid = userInfo["pid"] as? Int

        if let callbackUrl = callbackUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !callbackUrl.isEmpty {
            delegateLogger.notice("Notification clicked - opening callback URL: \(callbackUrl)")
            DispatchQueue.main.async { [weak self] in
                self?.openCallbackURL(callbackUrl) {
                    completionHandler()
                }
            }
            return
        }

        if let pid = pid {
            delegateLogger.notice("Notification clicked - attempting to activate app with PID: \(pid)")
            DispatchQueue.main.async { [weak self] in
                self?.activateApp(withPID: pid)
                completionHandler()
            }
        } else {
            delegateLogger.notice("Notification clicked - no callback URL or PID provided")
            completionHandler()
        }
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
            delegateLogger.notice("No running application found with PID: \(pid) or its parents")

            // List available PIDs for debugging
            delegateLogger.notice("Available PIDs:")
            runningApps.prefix(10).forEach { app in
                delegateLogger.notice("  - \(app.localizedName ?? "Unknown"): PID \(app.processIdentifier)")
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
            delegateLogger.notice("Reached maximum depth (20) in process tree")
            return nil
        }
        
        // Safety: Prevent cycles
        guard !visited.contains(pid) else {
            delegateLogger.notice("Cycle detected in process tree at PID: \(pid)")
            return nil
        }
        
        let indent = String(repeating: "  ", count: depth)
        
        // Check if current PID is a running application
        if let app = runningApps.first(where: { $0.processIdentifier == pid }) {
            if depth == 0 {
                delegateLogger.notice("\(indent)Found app directly: \(app.localizedName ?? "Unknown") (PID: \(pid))")
            } else {
                delegateLogger.notice("\(indent)Found parent app: \(app.localizedName ?? "Unknown") (PID: \(pid))")
            }
            return app
        }
        
        // Not found, get parent PID and recurse
        guard let parentPID = getParentPID(of: pid) else {
            delegateLogger.notice("\(indent)Reached top of process tree (no parent for PID: \(pid))")
            return nil
        }
        
        delegateLogger.notice("\(indent)PID \(pid) → Parent PID \(parentPID)")
        
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
            delegateLogger.notice("Unhid app: \(appName)")
        }

        // Unminimize any minimized windows via Accessibility API
        unminimizeWindows(forPID: app.processIdentifier)

        // Activate with all windows brought to front
        if app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps]) {
            delegateLogger.notice("Successfully activated app: \(appName) (PID: \(app.processIdentifier), Original PID: \(originalPID))")
        } else {
            delegateLogger.notice("Activation failed for: \(appName) (PID: \(app.processIdentifier))")
        }

        // Explicitly raise and focus non-minimized windows that may still be behind others.
        raiseAndFocusNonMinimizedWindows(forPID: app.processIdentifier)

    }

    /// Open callback URL directly (used for URL scheme callbacks)
    private func openCallbackURL(_ callbackUrl: String, handler: @escaping () -> Void) {
        guard let url = URL(string: callbackUrl) else {
            delegateLogger.notice("Invalid callback URL: \(callbackUrl)")
            handler()
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open(url, configuration: configuration) { _, error in
            if let error = error {
                delegateLogger.notice("Failed to open callback URL: \(error.localizedDescription)")
            } else {
                delegateLogger.notice("Opened callback URL successfully")
            }
            handler()
        }
    }

    /// Unminimize all minimized windows for a given PID using Accessibility API
    private func unminimizeWindows(forPID pid: pid_t) {
        guard AXIsProcessTrusted() else {
            delegateLogger.notice("Accessibility permission not granted, skipping unminimize")
            return
        }

        let appElement = AXUIElementCreateApplication(pid)

        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)

        guard result == .success, let windows = windowsRef as? [AXUIElement] else {
            delegateLogger.notice("Could not retrieve windows via Accessibility API (error: \(result.rawValue))")
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
                    delegateLogger.notice("Unminimized a window")
                } else {
                    delegateLogger.notice("Failed to unminimize window (error: \(setResult.rawValue))")
                }
            }
        }
    }

    /// Raise and focus non-minimized windows for a given PID via Accessibility API.
    private func raiseAndFocusNonMinimizedWindows(forPID pid: pid_t) {
        guard AXIsProcessTrusted() else {
            delegateLogger.notice("Accessibility permission not granted, skipping raise/focus")
            return
        }

        let appElement = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)

        guard result == .success, let windows = windowsRef as? [AXUIElement] else {
            delegateLogger.notice("Could not retrieve windows for raise/focus via Accessibility API (error: \(result.rawValue))")
            return
        }

        var raisedCount = 0
        for window in windows {
            var minimizedRef: CFTypeRef?
            let minResult = AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimizedRef)
            let isMinimized = (minimizedRef as? NSNumber)?.boolValue ?? false

            guard minResult == .success, !isMinimized else {
                continue
            }

            let raiseResult = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
            if raiseResult == .success {
                raisedCount += 1
            } else {
                delegateLogger.notice("Failed to raise window (error: \(raiseResult.rawValue))")
            }

            let mainResult = AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
            if mainResult != .success {
                delegateLogger.notice("Failed to mark window as main (error: \(mainResult.rawValue))")
            }

            let focusResult = AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
            if focusResult != .success {
                delegateLogger.notice("Failed to focus window (error: \(focusResult.rawValue))")
            }
        }

        if raisedCount > 0 {
            delegateLogger.notice("Raised/focused \(raisedCount) non-minimized window(s)")
        } else {
            delegateLogger.notice("No non-minimized windows were raised/focused")
        }
    }
}
