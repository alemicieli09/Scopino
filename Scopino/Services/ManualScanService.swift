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

    // MARK: - Scan

    /// Scansiona il disco cercando residui di app non più presenti.
    /// Ritorna un array di sessioni pronte per la pulizia.
    func scan() async -> [CleanupSession] {
        var sessions: [CleanupSession] = []

        // 1. App attualmente installate in /Applications
        let installedBundleIDs = installedApps()

        // 2. Cerca residui in tutti i path noti
        let candidates = await findOrphanedResiduals(
            excludingBundleIDs: installedBundleIDs
        )

        // 3. Raggruppa per app
        let grouped = groupByApp(candidates)

        // 4. Crea sessioni
        for (appInfo, residuals) in grouped {
            guard !residuals.isEmpty else { continue }

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

        guard let items = try? fm.contentsOfDirectory(atPath: "/Applications") else {
            return bundleIDs
        }

        for item in items where item.hasSuffix(".app") {
            let plistPath = "/Applications/\(item)/Contents/Info.plist"
            if let bid = NSDictionary(contentsOfFile: plistPath)?["CFBundleIdentifier"] as? String {
                bundleIDs.insert(bid)
            }
        }
        return bundleIDs
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
            ("\(home)/Library/Preferences",              .preferences),
            ("\(home)/Library/Application Support",      .applicationSupport),
            ("\(home)/Library/Caches",                   .cache),
            ("\(home)/Library/Logs",                     .logs),
            ("\(home)/Library/Containers",               .container),
            ("\(home)/Library/Group Containers",         .groupContainer),
            ("\(home)/Library/LaunchAgents",             .launchAgent),
            ("\(home)/Library/Saved Application State",  .savedState),
            ("/Library/LaunchAgents",                    .launchAgent),
            ("/Library/LaunchDaemons",                   .launchDaemon),
            ("/Library/Application Support",             .applicationSupport),
            ("/Library/Preferences",                     .preferences),
        ]

        var results: [ResidualItem] = []

        for target in scanPaths {
            guard let items = try? fm.contentsOfDirectory(atPath: target.path) else { continue }

            for item in items {
                // Estrai possibile bundleID dal nome file
                guard let bundleID = extractBundleID(from: item) else { continue }

                // Se l'app è ancora installata → salta
                if installed.contains(bundleID) { continue }

                // Ignora app Apple
                if bundleID.hasPrefix("com.apple.") { continue }

                // Ignora Scopino stesso
                if bundleID.hasPrefix("com.alemicieli.Scopino") { continue }

                let fullPath = "\(target.path)/\(item)"
                results.append(ResidualItem(
                    path: fullPath,
                    category: target.category,
                    sizeBytes: 0
                ))
            }
        }

        // Calcola dimensioni in parallelo
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

    // MARK: - Group by app

    private func groupByApp(
        _ items: [ResidualItem]
    ) -> [AppInfo: [ResidualItem]] {
        var grouped: [AppInfo: [ResidualItem]] = [:]

        for item in items {
            guard let bundleID = extractBundleID(
                from: (item.path as NSString).lastPathComponent
            ) else { continue }

            let appName = bundleID.split(separator: ".").last
                .map(String.init) ?? bundleID
            let appInfo = AppInfo(
                name: appName.capitalized,
                bundleID: bundleID
            )

            grouped[appInfo, default: []].append(item)
        }

        return grouped
    }

    // MARK: - BundleID extraction

    /// Estrae un bundleID da un nome file tipo "com.spotify.client.plist"
    private func extractBundleID(from filename: String) -> String? {
        // Rimuovi estensione
        let name = (filename as NSString).deletingPathExtension

        // Deve avere almeno due componenti separati da punto
        let parts = name.split(separator: ".")
        guard parts.count >= 2 else { return nil }

        // Deve iniziare con un TLD noto
        let knownTLDs = ["com", "org", "net", "io", "app", "co", "it",
                        "de", "fr", "eu", "me", "dev"]
        guard let first = parts.first,
              knownTLDs.contains(String(first).lowercased()) else { return nil }

        // Ricostruisci bundleID (max 3 componenti per evitare falsi positivi)
        let components = parts.prefix(3)
        return components.joined(separator: ".")
    }
}
