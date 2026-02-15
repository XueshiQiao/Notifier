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
    
    /// Validates that the required fields are not empty
    var isValid: Bool {
        !title.isEmpty && !body.isEmpty
    }
}
