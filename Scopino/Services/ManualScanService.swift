//
//  ManualScanService.swift
//  Scopino
//
//  Created by Alessandro Micieli on 08/05/2026.
//

import Foundation
import AppKit

/// Cerca app che hanno lasciato residui sul disco
/// senza che Scopino fosse attivo al momento della rimozione.
final class ManualScanService {

    // MARK: - Blocklist

    private let blockedPrefixes: [String] = [
        // Apple e sistema
        "com.apple", "com.apple.",
        // Tool di sviluppo
        "org.swift", "com.llvm", "org.llvm", "org.gnu",
        "com.jetbrains", "org.chromium",
        // Framework e runtime
        "com.adobe.acc", "com.adobe.adobeupdate", "com.adobe.armdc",
        // SDK e framework usati da app attive
        "com.crashlytics",
        "com.bugsnag",
        "io.branch",
        "org.freedesktop",
        "net.java",
        // macOS internals
        "com.smileonmymac",
        "com.objective-see",
        // Scopino stesso
        "com.alemicieli",
    ]

    private let knownActiveApps: Set<String> = [
        "com.microsoft.rdc", "com.microsoft.autoupdate2", "com.microsoft.office",
        "com.openai", "net.whatsapp", "com.canva", "com.notion",
        "com.figma", "com.electron",
        // Adobe — file condivisi tra app
        "com.adobe",
        // Browser
        "com.brave.Browser",
        // Virtualizzazione
        "com.utmapp",
    ]

    // MARK: - Scan

    func scan() async -> [CleanupSession] {
        var sessions: [CleanupSession] = []
        let installedBundleIDs = installedApps()
        let candidates = await findOrphanedResiduals(excludingBundleIDs: installedBundleIDs)
        let grouped = groupByApp(candidates)

        for (appInfo, residuals) in grouped {
            guard !residuals.isEmpty else { continue }
            let significant = residuals.filter { $0.sizeBytes > 1024 }
            guard !significant.isEmpty else { continue }

            let app = DetectedApp(
                name: appInfo.name,
                bundleID: appInfo.bundleID,
                icon: nil,
                removalDate: Date()
            )
            let session = CleanupSession(app: app)
            session.residuals = residuals
            sessions.append(session)
        }

        return sessions.sorted { $0.totalSizeBytes > $1.totalSizeBytes }
    }

    // MARK: - Installed apps

    private func installedApps() -> Set<String> {
        var bundleIDs = Set<String>()
        let fm = FileManager.default
        addApps(in: "/Applications", to: &bundleIDs, fm: fm)
        addApps(in: "/Applications/Utilities", to: &bundleIDs, fm: fm)
        let home = fm.homeDirectoryForCurrentUser.path
        addApps(in: "\(home)/Applications", to: &bundleIDs, fm: fm)
        bundleIDs.formUnion(knownActiveApps)
        return bundleIDs
    }

    private func addApps(
        in directory: String,
        to bundleIDs: inout Set<String>,
        fm: FileManager
    ) {
        guard let items = try? fm.contentsOfDirectory(atPath: directory) else { return }
        for item in items where item.hasSuffix(".app") {
            let plistPath = "\(directory)/\(item)/Contents/Info.plist"
            if let bid = NSDictionary(contentsOfFile: plistPath)?["CFBundleIdentifier"] as? String {
                bundleIDs.insert(bid)
                let prefix = bid.split(separator: ".").prefix(2).joined(separator: ".")
                bundleIDs.insert(prefix)
            }
        }
    }

    // MARK: - Find orphaned residuals

    private struct AppInfo: Hashable {
        let name: String
        let bundleID: String?
    }

    private func findOrphanedResiduals(
        excludingBundleIDs installed: Set<String>
    ) async -> [ResidualItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let fm = FileManager.default

        let scanPaths: [(path: String, category: ResidualCategory)] = [
            ("\(home)/Library/Preferences",             .preferences),
            ("\(home)/Library/Application Support",     .applicationSupport),
            ("\(home)/Library/Caches",                  .cache),
            ("\(home)/Library/Logs",                    .logs),
            ("\(home)/Library/Containers",              .container),
            ("\(home)/Library/Group Containers",        .groupContainer),
            ("\(home)/Library/LaunchAgents",            .launchAgent),
            ("\(home)/Library/Saved Application State", .savedState),
            ("/Library/LaunchAgents",                   .launchAgent),
            ("/Library/LaunchDaemons",                  .launchDaemon),
            ("/Library/Application Support",            .applicationSupport),
            ("/Library/Preferences",                    .preferences),
        ]

        var results: [ResidualItem] = []

        for target in scanPaths {
            guard let items = try? fm.contentsOfDirectory(atPath: target.path) else { continue }

            for item in items {
                guard let bundleID = extractBundleID(from: item) else { continue }
                if isBlocked(bundleID) { continue }
                if installed.contains(bundleID) { continue }
                let prefix = bundleID.split(separator: ".").prefix(2).joined(separator: ".")
                if installed.contains(prefix) { continue }

                let fullPath = "\(target.path)/\(item)"
                results.append(ResidualItem(path: fullPath, category: target.category, sizeBytes: 0))
            }
        }

        return await withTaskGroup(of: ResidualItem.self) { group in
            for item in results {
                group.addTask {
                    var copy = item
                    copy.sizeBytes = await ResidualFinder.sizeOf(path: item.path)
                    return copy
                }
            }
            var sized: [ResidualItem] = []
            for await item in group { sized.append(item) }
            return sized.filter { $0.sizeBytes > 0 }
        }
    }

    // MARK: - Blocked check

    private func isBlocked(_ bundleID: String) -> Bool {
        blockedPrefixes.contains(where: { bundleID.hasPrefix($0) })
    }

    // MARK: - Display name resolution

    /// Cerca il nome human-readable dell'app in questo ordine:
    /// 1. NSWorkspace (app ancora in cache di sistema)
    /// 2. Cartella Application Support (spesso usa nome app)
    /// 3. Fallback al bundleID originale
    private func resolvedDisplayName(
        for bundleID: String,
        originalFilename: String
    ) -> String {
        // 1. NSWorkspace — se l'app è ancora in cache
        if let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleID
        ) {
            let name = url.deletingPathExtension().lastPathComponent
            if !name.isEmpty && !name.contains(".") {
                return name
            }
        }

        // 2. Application Support — cerca cartella con nome simile
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let appSupportPath = "\(home)/Library/Application Support"
        let lastComponent = bundleID.split(separator: ".").last.map(String.init) ?? ""

        if let items = try? FileManager.default.contentsOfDirectory(atPath: appSupportPath) {
            // Match esatto case-insensitive
            for item in items {
                if item.lowercased() == lastComponent.lowercased() {
                    return item
                }
            }
            // Match parziale — il nome contiene l'ultima componente
            for item in items {
                if item.lowercased().contains(lastComponent.lowercased())
                    && !item.contains(".") {
                    return item
                }
            }
        }

        // 3. Fallback — usa il filename originale senza estensione
        return (originalFilename as NSString).deletingPathExtension
    }

    // MARK: - Group by app

    private func groupByApp(
        _ items: [ResidualItem]
    ) -> [AppInfo: [ResidualItem]] {
        var grouped: [AppInfo: [ResidualItem]] = [:]

        for item in items {
            let filename = (item.path as NSString).lastPathComponent
            guard let bundleID = extractBundleID(from: filename) else { continue }

            let groupID = bundleID.split(separator: ".")
                .prefix(3).joined(separator: ".")

            // Risolvi nome human-readable
            let name = resolvedDisplayName(
                for: groupID,
                originalFilename: filename
            )

            let appInfo = AppInfo(name: name, bundleID: groupID)
            grouped[appInfo, default: []].append(item)
        }

        return grouped
    }

    // MARK: - BundleID extraction

    private func extractBundleID(from filename: String) -> String? {
        let name = (filename as NSString).deletingPathExtension
        let parts = name.split(separator: ".")
        guard parts.count >= 2 else { return nil }

        let knownTLDs = ["com", "org", "net", "io", "app", "co", "it",
                         "de", "fr", "eu", "me", "dev", "uk", "us"]
        guard let first = parts.first,
              knownTLDs.contains(String(first).lowercased()) else { return nil }

        return parts.prefix(3).joined(separator: ".")
    }
}
