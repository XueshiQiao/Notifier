//
//  NotifierApp.swift
//  Notifier
//
//  Created by Xueshi Qiao on 2/16/26.
//

import SwiftUI
import UserNotifications

@main
struct NotifierApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
class AppDelegate: NSObject, NSApplicationDelegate {
    let notificationDelegate = NotificationDelegate()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }
}

