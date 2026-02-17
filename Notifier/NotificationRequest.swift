//
//  NotificationRequest.swift
//  Notifier
//
//  Created by Xueshi Qiao on 2/16/26.
//

import Foundation

/// Model representing the expected POST request body
struct NotificationRequest: Codable {
    let title: String
    let body: String
    let subtitle: String?
    let pid: Int?  // Process ID to activate when notification is clicked
    let tty: String?  // TTY path for Terminal.app tab selection (e.g., "/dev/ttys003")
    let callbackUrl: String?  // URL scheme callback to open when notification is clicked

    enum CodingKeys: String, CodingKey {
        case title
        case body
        case subtitle
        case pid
        case tty
        case callbackUrl = "callback_url"
    }
    
    /// Validates that the required fields are not empty
    var isValid: Bool {
        !title.isEmpty && !body.isEmpty
    }
}
