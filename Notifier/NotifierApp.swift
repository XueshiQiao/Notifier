//
//  NotifierApp.swift
//  Notifier
//
//  Created by Xueshi Qiao on 2/16/26.
//

import SwiftUI
import UserNotifications
import AppKit

@main
struct NotifierApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    let notificationDelegate = NotificationDelegate()
    private var statusItem: NSStatusItem?
    private var versionMenuItem: NSMenuItem?
    private var serverStatusMenuItem: NSMenuItem?
    private var checkUpdateMenuItem: NSMenuItem?
    private var menuRefreshTimer: Timer?
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        setupStatusItem()
        openNotifierWindow()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        if let button = item.button {
            button.image = NSImage(systemSymbolName: "bell.badge", accessibilityDescription: "Notifier")
            button.toolTip = "Notifier"
        }

        let menu = NSMenu()
        let versionItem = NSMenuItem(title: "Version: v\(UpdateChecker.shared.currentVersion)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        versionItem.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: "Version")
        versionMenuItem = versionItem
        menu.addItem(versionItem)

        let serverItem = NSMenuItem(title: serverStatusTitle(), action: #selector(toggleHTTPServer), keyEquivalent: "")
        serverItem.isEnabled = true
        serverItem.image = NSImage(systemSymbolName: serverStatusSymbolName(), accessibilityDescription: "HTTP Server Status")
        serverStatusMenuItem = serverItem
        menu.addItem(serverItem)

        menu.addItem(.separator())
        let openWindowItem = NSMenuItem(title: "Show App", action: #selector(openNotifierWindow), keyEquivalent: "o")
        openWindowItem.image = NSImage(systemSymbolName: "macwindow", accessibilityDescription: "Open Window")
        menu.addItem(openWindowItem)
        menu.addItem(.separator())

        let homepageItem = NSMenuItem(title: "Open Homepage on GitHub", action: #selector(openHomepage), keyEquivalent: "")
        homepageItem.image = NSImage(systemSymbolName: "globe", accessibilityDescription: "Open Homepage")
        menu.addItem(homepageItem)

        let updateItem = NSMenuItem(title: "Check Update", action: #selector(checkUpdate), keyEquivalent: "")
        updateItem.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "Check Update")
        updateItem.target = self
        checkUpdateMenuItem = updateItem
        menu.addItem(updateItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit Notifier", action: #selector(quitNotifier), keyEquivalent: "q")
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: "Quit")
        menu.addItem(quitItem)

        menu.items.forEach { $0.target = self }
        item.menu = menu

        refreshMenuItems()
        startMenuRefreshTimer()
    }

    @objc
    private func openNotifierWindow() {
        if window == nil {
            let contentView = ContentView()
            let hostingView = NSHostingView(rootView: contentView)
            hostingView.layoutSubtreeIfNeeded()

            let fittedSize = hostingView.fittingSize
            let initialWidth = max(420, fittedSize.width)
            let initialHeight = max(560, fittedSize.height)

            let createdWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: initialWidth, height: initialHeight),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            createdWindow.center()
            createdWindow.title = "Notifier"
            createdWindow.contentView = hostingView
            createdWindow.contentMinSize = NSSize(width: 400, height: 560)
            createdWindow.isReleasedWhenClosed = false
            createdWindow.collectionBehavior.insert(.moveToActiveSpace)
            window = createdWindow
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.orderFrontRegardless()
        window?.makeKey()
    }

    @objc
    private func quitNotifier() {
        NSApp.terminate(nil)
    }

    @objc
    private func checkUpdate() {
        checkUpdateMenuItem?.isEnabled = false
        checkUpdateMenuItem?.title = "Checking!"

        Task { @MainActor in
            await UpdateChecker.shared.checkForUpdate()
            refreshMenuItems()
            checkUpdateMenuItem?.isEnabled = true
        }
    }

    @objc
    private func toggleHTTPServer() {
        let server = HTTPServer.shared
        if server.isRunning {
            server.stop()
        } else {
            server.start()
        }
        refreshMenuItems()
    }

    @objc
    private func openHomepage() {
        guard let url = URL(string: "https://github.com/XueshiQiao/Notifier") else { return }
        NSWorkspace.shared.open(url)
    }

    private func startMenuRefreshTimer() {
        menuRefreshTimer?.invalidate()
        menuRefreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                self?.refreshMenuItems()
            }
        }
    }

    private func refreshMenuItems() {
        versionMenuItem?.title = "Version: v\(UpdateChecker.shared.currentVersion)"
        serverStatusMenuItem?.title = serverStatusTitle()
        serverStatusMenuItem?.image = NSImage(systemSymbolName: serverStatusSymbolName(), accessibilityDescription: "HTTP Server Status")

        guard let checkUpdateMenuItem = checkUpdateMenuItem, checkUpdateMenuItem.isEnabled else {
            return
        }
        if UpdateChecker.shared.updateAvailable, let latest = UpdateChecker.shared.latestVersion {
            checkUpdateMenuItem.title = "Check Update (v\(latest) available)"
        } else {
            checkUpdateMenuItem.title = "Check Update"
        }
    }

    private func serverStatusTitle() -> String {
        let server = HTTPServer.shared
        if server.isRunning {
            return "HTTP Server: Running (:\(server.port))"
        }
        return "HTTP Server: Stopped"
    }

    private func serverStatusSymbolName() -> String {
        HTTPServer.shared.isRunning ? "play.circle.fill" : "stop.circle.fill"
    }
}
