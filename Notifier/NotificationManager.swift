//
//  NotificationManager.swift
//  Notifier
//
//  Created by Xueshi Qiao on 2/16/26.
//

import Foundation
import UserNotifications

/// Manages notification permissions and posting
@MainActor
@Observable
class NotificationManager {
    static let shared = NotificationManager()
    
    var isAuthorized = false
    
    private init() {}
    
    /// Request notification permissions from the user
    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            
            if granted {
                print("✅ Notification permission granted")
            } else {
                print("❌ Notification permission denied")
            }
        } catch {
            print("❌ Error requesting notification permission: \(error)")
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
        
        // Store PID and TTY in userInfo if provided
        var userInfo: [String: Any] = [:]
        if let pid = request.pid {
            userInfo["pid"] = pid
        }
        if let tty = request.tty {
            userInfo["tty"] = tty
        }
        if !userInfo.isEmpty {
            content.userInfo = userInfo
        }
        
        content.sound = .default
        
        // Create a request with a unique identifier
        let notificationRequest = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // nil means show immediately
        )
        
        try await UNUserNotificationCenter.current().add(notificationRequest)
        print("✅ Notification posted: \(request.title)")
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
