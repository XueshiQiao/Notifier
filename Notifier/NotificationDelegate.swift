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
        
        // Extract PID from userInfo
        if let pid = userInfo["pid"] as? Int {
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
        // Try multiple activation strategies
        var success = false
        
        // Strategy 1: Try with activateIgnoringOtherApps (most forceful)
        success = app.activate(options: [.activateIgnoringOtherApps])
        
        if success {
            print("✅ Method1: Successfully activated app: \(app.localizedName ?? "Unknown") (PID: \(app.processIdentifier), Original PID: \(originalPID))")
            return
        }
        
        // Strategy 2: Try with activateAllWindows
        success = app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        
        if success {
            print("✅ Method2: Successfully activated app (with all windows): \(app.localizedName ?? "Unknown") (PID: \(app.processIdentifier), Original PID: \(originalPID))")
            return
        }
        
        // Strategy 3: Use NSWorkspace to activate by bundle identifier
        if let bundleID = app.bundleIdentifier {
            print("🔄 Method3: Trying to activate via bundle identifier: \(bundleID)")
            
            let workspace = NSWorkspace.shared
            let success = workspace.launchApplication(
                withBundleIdentifier: bundleID,
                options: [.andHide, .withoutActivation],
                additionalEventParamDescriptor: nil,
                launchIdentifier: nil
            )
            
            if success {
                // Now try to activate it
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    _ = app.activate(options: [.activateIgnoringOtherApps])
                }
                print("✅ Activated app via bundle ID: \(app.localizedName ?? "Unknown")")
                return
            }
        }
        
        // Strategy 4: Use AppleScript as last resort (especially good for VS Code)
        if let bundleID = app.bundleIdentifier {
            print("🔄 Trying AppleScript activation for: \(bundleID)")
            activateViaAppleScript(bundleID: bundleID, appName: app.localizedName ?? "Unknown")
        } else {
            print("⚠️ All activation strategies failed for: \(app.localizedName ?? "Unknown") (PID: \(app.processIdentifier))")
        }
    }
    
    /// Activate app using AppleScript (works well for Electron apps like VS Code)
    private func activateViaAppleScript(bundleID: String, appName: String) {
        let script = """
        tell application id "\(bundleID)"
            activate
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
            
            if let error = error {
                print("⚠️ AppleScript activation failed: \(error)")
            } else {
                print("✅ Successfully activated via AppleScript: \(appName)")
            }
        }
    }
}
