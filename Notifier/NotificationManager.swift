//
//  NotificationManager.swift
//  Notifier
//
//  Created by Xueshi Qiao on 2/16/26.
//

import Foundation
import UserNotifications
import AppKit
import os

/// Manages notification permissions and posting
@MainActor
@Observable
class NotificationManager {
    static let shared = NotificationManager()
    private let logger = Logger(subsystem: "me.xueshi.Notifier", category: "Notification")

    var isAuthorized = false

    private init() {}
    
    /// Request notification permissions from the user
    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            
            if granted {
                logger.notice("Notification permission granted")
            } else {
                logger.notice("Notification permission denied")
            }
        } catch {
            logger.notice("Error requesting notification permission: \(error)")
            isAuthorized = false
        }
    }
    
    /// Post a notification based on the request
    func postNotification(from request: NotificationRequest) async throws {
        guard isAuthorized else {
            throw NotificationError.notAuthorized
        }
        
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        
        if let subtitle = request.subtitle {
            content.subtitle = subtitle
        }
        
        // Store activation metadata in userInfo if provided
        var userInfo: [String: Any] = [:]
        if let callbackUrl = request.callbackUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !callbackUrl.isEmpty {
            userInfo["callback_url"] = callbackUrl
        }
        if let pid = request.pid {
            userInfo["pid"] = pid
        }
        if let tty = request.tty {
            userInfo["tty"] = tty
        }
        if !userInfo.isEmpty {
            content.userInfo = userInfo
        }

        if let pid = request.pid {
            if let iconAttachment = createSourceAppIconAttachment(forPID: pid_t(pid)) {
                content.attachments = [iconAttachment]
            }
        }
        
        content.sound = .default
        
        // Create a request with a unique identifier
        let notificationRequest = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // nil means show immediately
        )
        
        try await UNUserNotificationCenter.current().add(notificationRequest)
        logger.notice("Notification posted: \(request.title)")
    }

    private func createSourceAppIconAttachment(forPID pid: pid_t) -> UNNotificationAttachment? {
        guard let app = findRunningApplication(forPID: pid) else {
            logger.notice("No running app found for PID \(pid); skipping icon attachment")
            return nil
        }

        guard let tiffData = app.icon?.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            logger.notice("Failed to convert source app icon to PNG; skipping attachment")
            return nil
        }

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("source-app-icon-\(UUID().uuidString).png")

        do {
            try pngData.write(to: fileURL, options: .atomic)
            return try UNNotificationAttachment(identifier: "source_app_icon", url: fileURL)
        } catch {
            logger.notice("Failed to create icon attachment: \(error.localizedDescription)")
            return nil
        }
    }

    private func findRunningApplication(forPID pid: pid_t) -> NSRunningApplication? {
        let runningApps = NSWorkspace.shared.runningApplications
        var currentPID: pid_t? = pid
        var visited = Set<pid_t>()

        while let candidatePID = currentPID, candidatePID > 1, !visited.contains(candidatePID) {
            if let app = runningApps.first(where: { $0.processIdentifier == candidatePID }) {
                return app
            }
            visited.insert(candidatePID)
            currentPID = parentPID(of: candidatePID)
        }

        return nil
    }

    private func parentPID(of pid: pid_t) -> pid_t? {
        var kinfo = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]

        let result = sysctl(&mib, u_int(mib.count), &kinfo, &size, nil, 0)
        guard result == 0 else {
            return nil
        }

        let parent = kinfo.kp_eproc.e_ppid
        return parent > 1 ? parent : nil
    }
    
    enum NotificationError: LocalizedError {
        case notAuthorized
        
        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Notification permission not granted"
            }
        }
    }
}
