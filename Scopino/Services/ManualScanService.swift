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

    /// BundleID prefix che non vengono mai toccati.
    private let blockedPrefixes: [String] = [
        // Apple e sistema
        "com.apple",
        "com.apple.",
        // Tool di sviluppo
        "org.swift",
        "com.llvm",
        "org.llvm",
        "org.gnu",
        "com.jetbrains",
        "org.chromium",
        // Framework e runtime
        "com.adobe.acc",
        "com.adobe.adobeupdate",
        "com.adobe.armdc",
        // macOS internals
        "com.smileonmymac",
        "com.objective-see",
        // Scopino stesso
        "com.alemicieli",
    ]

    /// App che potrebbero non essere in /Applications ma sono attive.
    private let knownActiveApps: Set<String> = [
        "com.microsoft.rdc",
        "com.microsoft.autoupdate2",
        "com.microsoft.office",
        "com.openai",
        "net.whatsapp",
        "com.canva",
        "com.notion",
        "com.figma",
        "com.electron",
    ]

    // MARK: - Scan

    func scan() async -> [CleanupSession] {
        var sessions: [CleanupSession] = []

        // 1. App attualmente installate in /Applications (bundleID completi)
        let installedBundleIDs = installedApps()

        // 2. Cerca residui
        let candidates = await findOrphanedResiduals(
            excludingBundleIDs: installedBundleIDs
        )

        // 3. Raggruppa per app
        let grouped = groupByApp(candidates)

        // 4. Crea sessioni — filtra gruppi con pochi elementi sospetti
        for (appInfo, residuals) in grouped {
            guard !residuals.isEmpty else { continue }

            // Minimo 1 elemento con dimensione > 1KB per essere considerato
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

    /// Legge i bundleID di tutte le app in /Applications ricorsivamente.
    private func installedApps() -> Set<String> {
        var bundleIDs = Set<String>()
        let fm = FileManager.default

        // /Applications standard
        addApps(in: "/Applications", to: &bundleIDs, fm: fm)

        // /Applications/Utilities
        addApps(in: "/Applications/Utilities", to: &bundleIDs, fm: fm)

        // ~/Applications
        let home = fm.homeDirectoryForCurrentUser.path
        addApps(in: "\(home)/Applications", to: &bundleIDs, fm: fm)

        // Aggiungi app note come attive
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
                // Aggiungi anche prefisso (es. "com.spotify" da "com.spotify.client")
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

                // Blocklist prefissi
                if isBlocked(bundleID) { continue }

                // App ancora installata
                if installed.contains(bundleID) { continue }

                // Controlla anche il prefisso (com.spotify da com.spotify.client)
                let prefix = bundleID.split(separator: ".")
                    .prefix(2).joined(separator: ".")
                if installed.contains(prefix) { continue }

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
            // Filtra file troppo piccoli (< 1 byte) o non trovati
            return sized.filter { $0.sizeBytes > 0 }
        }
    }

    // MARK: - Blocked check

    private func isBlocked(_ bundleID: String) -> Bool {
        return blockedPrefixes.contains(where: { bundleID.hasPrefix($0) })
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

            // Usa solo prime 3 componenti come chiave gruppo
            let components = bundleID.split(separator: ".")
            let groupID = components.prefix(3).joined(separator: ".")

            // Nome display: ultima componente significativa
            let appName: String = {
                if components.count >= 3 {
                    return String(components[2]).capitalized
                } else if components.count >= 2 {
                    return String(components[1]).capitalized
                }
                return bundleID
            }()

            let appInfo = AppInfo(name: appName, bundleID: groupID)
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

        // Max 3 componenti
        let components = parts.prefix(3)
        return components.joined(separator: ".")
    }
}
