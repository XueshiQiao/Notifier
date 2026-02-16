//
//  UpdateChecker.swift
//  Notifier
//

import Foundation

@MainActor
@Observable
class UpdateChecker {
    static let shared = UpdateChecker()

    var updateAvailable = false
    var latestVersion: String?

    private let versionURL = URL(string: "https://raw.githubusercontent.com/XueshiQiao/Notifier/main/version.json")!
    private let checkInterval: TimeInterval = 3600 // 1 hour

    private init() {}

    func checkForUpdate() async {
        do {
            let (data, _) = try await URLSession.shared.data(from: versionURL)
            let manifest = try JSONDecoder().decode(VersionManifest.self, from: data)

            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"

            if isVersion(manifest.version, newerThan: currentVersion) {
                latestVersion = manifest.version
                updateAvailable = true
            }
        } catch {
            // Silent failure on network errors
        }
    }

    func startPeriodicChecks() async {
        await checkForUpdate()
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(checkInterval))
            await checkForUpdate()
        }
    }

    private func isVersion(_ remote: String, newerThan local: String) -> Bool {
        let remoteParts = remote.split(separator: ".").compactMap { Int($0) }
        let localParts = local.split(separator: ".").compactMap { Int($0) }

        let maxLength = max(remoteParts.count, localParts.count)
        for i in 0..<maxLength {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let l = i < localParts.count ? localParts[i] : 0
            if r > l { return true }
            if r < l { return false }
        }
        return false
    }
}

private struct VersionManifest: Decodable {
    let version: String
    let download_url: String
    let release_notes: String
}
