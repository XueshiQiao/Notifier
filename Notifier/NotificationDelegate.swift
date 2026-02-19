//
//  NotificationDelegate.swift
//  Notifier
//
//  Created by Xueshi Qiao on 2/16/26.
//

import Foundation
import UserNotifications
import AppKit
import CoreGraphics
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
        let bundleID = app.bundleIdentifier ?? "Unknown"
        let axTrusted = AXIsProcessTrusted()
        delegateLogger.notice("Activation context: app=\(appName) bundle=\(bundleID) pid=\(app.processIdentifier) axTrusted=\(axTrusted)")

        // Unhide the app if it's hidden
        if app.isHidden {
            app.unhide()
            delegateLogger.notice("Unhid app: \(appName)")
        }

        // Unminimize any minimized windows via Accessibility API
        unminimizeWindows(forPID: app.processIdentifier)

        // Ordered activation sequence:
        // 1) app.activate
        // 2) wait briefly for run-loop/state propagation
        // 3) AX app-frontmost + AX window raise/focus
        // 4) verify and retry once
        performActivationAttempt(app, appName: appName, originalPID: originalPID, attempt: 1)
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

    /// Attempt to mark the app process itself as frontmost via Accessibility API.
    private func setAppFrontmostViaAccessibility(forPID pid: pid_t) {
        guard AXIsProcessTrusted() else {
            delegateLogger.notice("Accessibility permission not granted, skipping app-frontmost request")
            return
        }

        let appElement = AXUIElementCreateApplication(pid)
        let result = AXUIElementSetAttributeValue(appElement, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        if result == .success {
            delegateLogger.notice("Requested app frontmost via Accessibility API")
        } else {
            delegateLogger.notice("Failed to request app frontmost via Accessibility API (error: \(result.rawValue))")
        }
    }

    /// Check whether the target app is currently the frontmost app.
    private func isApplicationFrontmost(_ app: NSRunningApplication) -> Bool {
        NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier
    }

    /// Execute one activation attempt, then verify after a short delay and escalate if needed.
    private func performActivationAttempt(
        _ app: NSRunningApplication,
        appName: String,
        originalPID: Int,
        attempt: Int
    ) {
        let activated = app.activate(options: [.activateAllWindows])
        if activated {
            delegateLogger.notice("Activation attempt \(attempt) sent for: \(appName) (PID: \(app.processIdentifier), Original PID: \(originalPID))")
        } else {
            delegateLogger.notice("Activation attempt \(attempt) could not be sent for: \(appName) (PID: \(app.processIdentifier), Original PID: \(originalPID))")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(150)) { [weak self] in
            guard let self = self else { return }

            if self.isActivationVisiblySuccessful(app) {
                delegateLogger.notice("Activation attempt \(attempt) reached visible success for: \(appName) (PID: \(app.processIdentifier))")
                return
            }

            self.setAppFrontmostViaAccessibility(forPID: app.processIdentifier)
            self.raiseAndFocusNonMinimizedWindows(forPID: app.processIdentifier)

            if self.isActivationVisiblySuccessful(app) {
                delegateLogger.notice("AX actions reached visible success on attempt \(attempt): \(appName) (PID: \(app.processIdentifier))")
                return
            }

            if attempt == 1 {
                delegateLogger.notice("App not frontmost after attempt 1; scheduling attempt 2: \(appName) (PID: \(app.processIdentifier))")
                self.performActivationAttempt(app, appName: appName, originalPID: originalPID, attempt: 2)
                return
            }

            self.fallbackOpenApplication(app, appName: appName)
        }
    }

    /// Final fallback: ask LaunchServices/NSWorkspace to (re)open and activate the target app.
    private func fallbackOpenApplication(_ app: NSRunningApplication, appName: String) {
        guard let bundleURL = app.bundleURL else {
            logFrontmostMismatch(for: app, appName: appName, context: "No bundle URL for fallback open")
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.promptsUserIfNeeded = false

        delegateLogger.notice("Attempting NSWorkspace fallback open for: \(appName) (PID: \(app.processIdentifier))")
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { [weak self] _, error in
            guard let self = self else { return }
            if let error = error {
                delegateLogger.notice("NSWorkspace fallback open failed for \(appName): \(error.localizedDescription)")
                self.logFrontmostMismatch(for: app, appName: appName, context: "Fallback open error")
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(150)) {
                self.setAppFrontmostViaAccessibility(forPID: app.processIdentifier)
                self.raiseAndFocusNonMinimizedWindows(forPID: app.processIdentifier)

                if self.isActivationVisiblySuccessful(app) {
                    delegateLogger.notice("NSWorkspace fallback reached visible success: \(appName) (PID: \(app.processIdentifier))")
                } else {
                    self.logFrontmostMismatch(for: app, appName: appName, context: "After NSWorkspace fallback")
                }
            }
        }
    }

    private func logFrontmostMismatch(for app: NSRunningApplication, appName: String, context: String) {
        let frontmost = NSWorkspace.shared.frontmostApplication
        let frontmostName = frontmost?.localizedName ?? "Unknown"
        let frontmostPID = frontmost?.processIdentifier ?? 0
        let visible = hasLikelyVisibleWindow(forPID: app.processIdentifier)
        delegateLogger.notice(
            "\(context): target \(appName) (PID: \(app.processIdentifier)); frontmost is \(frontmostName) (PID: \(frontmostPID)); targetHasVisibleWindow=\(visible)"
        )
    }

    /// Success means the app is frontmost and (for regular apps) has a visible window on-screen.
    private func isActivationVisiblySuccessful(_ app: NSRunningApplication) -> Bool {
        guard isApplicationFrontmost(app) else {
            return false
        }

        // Accessory/background apps may not own a regular app window.
        guard app.activationPolicy == .regular else {
            return true
        }

        return hasLikelyVisibleWindow(forPID: app.processIdentifier)
    }

    /// Heuristic based on CoreGraphics window list; does not depend on Accessibility permission.
    private func hasLikelyVisibleWindow(forPID pid: pid_t) -> Bool {
        guard let raw = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else {
            delegateLogger.notice("Could not query on-screen windows for PID \(pid)")
            return false
        }

        for info in raw {
            guard let owner = info[kCGWindowOwnerPID as String] as? NSNumber,
                  owner.int32Value == pid else {
                continue
            }

            let layer = (info[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
            if layer != 0 {
                continue
            }

            let alpha = (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1.0
            if alpha <= 0.01 {
                continue
            }

            if let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
               let bounds = CGRect(dictionaryRepresentation: boundsDict),
               (bounds.width < 2 || bounds.height < 2) {
                continue
            }

            return true
        }

        return false
    }
}
