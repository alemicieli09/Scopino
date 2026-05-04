//
//  ResidualFinder.swift
//  Scopino
//
//  Created by Alessandro Micieli on 04/05/2026.
//

import Foundation

/// Trova tutti i residui sul disco per una DetectedApp.
final class ResidualFinder {

    // MARK: - Public

    /// Cerca tutti i residui in modo asincrono.
    /// Integra scansione standard + KnownResidualsDB.
    func findResiduals(for app: DetectedApp) async -> [ResidualItem] {
        var results: [ResidualItem] = []

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let tokens = app.searchTokens

        // 1. Scansione path standard
        let searchTargets: [(basePath: String, category: ResidualCategory)] = [
            ("\(home)/Library/Preferences",                 .preferences),
            ("\(home)/Library/Application Support",         .applicationSupport),
            ("\(home)/Library/Caches",                      .cache),
            ("\(home)/Library/Logs",                        .logs),
            ("\(home)/Library/Containers",                  .container),
            ("\(home)/Library/Group Containers",            .groupContainer),
            ("\(home)/Library/LaunchAgents",                .launchAgent),
            ("\(home)/Library/Saved Application State",     .savedState),
            ("/Library/LaunchAgents",                       .launchAgent),
            ("/Library/LaunchDaemons",                      .launchDaemon),
            ("/Library/Application Support",                .applicationSupport),
            ("/Library/Preferences",                        .preferences),
        ]

        for target in searchTargets {
            let found = scanDirectory(
                at: target.basePath,
                matchingTokens: tokens,
                category: target.category
            )
            results.append(contentsOf: found)
        }

        // 2. Path extra da KnownResidualsDB
        if let bundleID = app.bundleID {
            let extraPaths = KnownResidualsDB.shared.extraPaths(for: bundleID)
            for path in extraPaths {
                guard FileManager.default.fileExists(atPath: path) else { continue }
                results.append(ResidualItem(
                    path: path,
                    category: categoryForPath(path),
                    sizeBytes: 0
                ))
            }
        }

        // 3. Deduplicazione + calcolo dimensioni
        let unique = deduplicated(results)
        return await withSizeCalculated(unique)
    }

    // MARK: - Directory scan

    private func scanDirectory(
        at basePath: String,
        matchingTokens tokens: [String],
        category: ResidualCategory
    ) -> [ResidualItem] {
        let fm = FileManager.default
        var found: [ResidualItem] = []

        guard let items = try? fm.contentsOfDirectory(atPath: basePath) else {
            return found
        }

        for item in items {
            let itemLower = item.lowercased()
            let matches = tokens.contains(where: { token in
                itemLower.contains(token.lowercased())
            })

            if matches {
                let fullPath = "\(basePath)/\(item)"
                found.append(ResidualItem(
                    path: fullPath,
                    category: category,
                    sizeBytes: 0
                ))
            }
        }

        return found
    }

    // MARK: - Category inference

    private func categoryForPath(_ path: String) -> ResidualCategory {
        if path.contains("Preferences")         { return .preferences }
        if path.contains("Application Support") { return .applicationSupport }
        if path.contains("Caches")              { return .cache }
        if path.contains("Logs")                { return .logs }
        if path.contains("Group Containers")    { return .groupContainer }
        if path.contains("Containers")          { return .container }
        if path.contains("LaunchAgents")        { return .launchAgent }
        if path.contains("LaunchDaemons")       { return .launchDaemon }
        if path.contains("Saved Application")   { return .savedState }
        return .other
    }

    // MARK: - Deduplication

    private func deduplicated(_ items: [ResidualItem]) -> [ResidualItem] {
        var seen = Set<String>()
        return items.filter { item in
            guard !seen.contains(item.path) else { return false }
            seen.insert(item.path)
            return true
        }
    }

    // MARK: - Size calculation

    private func withSizeCalculated(_ items: [ResidualItem]) async -> [ResidualItem] {
        await withTaskGroup(of: ResidualItem.self) { group in
            for item in items {
                group.addTask {
                    var copy = item
                    copy.sizeBytes = await ResidualFinder.sizeOf(path: item.path)
                    return copy
                }
            }

            var result: [ResidualItem] = []
            for await item in group {
                result.append(item)
            }

            return result.sorted {
                if $0.category.rawValue != $1.category.rawValue {
                    return $0.category.rawValue < $1.category.rawValue
                }
                return $0.displayName < $1.displayName
            }
        }
    }

    /// Metodo statico nonisolated — chiamabile da qualsiasi Task senza actor.
    private static func sizeOf(path: String) async -> Int64 {
        return await Task.detached(priority: .utility) {
            let fm = FileManager.default
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: path, isDirectory: &isDir) else { return 0 }

            if !isDir.boolValue {
                let attrs = try? fm.attributesOfItem(atPath: path)
                return (attrs?[.size] as? Int64) ?? 0
            }

            guard let enumerator = fm.enumerator(
                at: URL(fileURLWithPath: path),
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else { return 0 }

            var total: Int64 = 0
            // Iterazione sincrona esplicita — evita il warning Swift 6
            while let fileURL = enumerator.nextObject() as? URL {
                let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                total += Int64(size)
            }
            return total
        }.value
    }

    // MARK: - Size helper

    private func calculateSize(at path: String) -> Int64 {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir) else { return 0 }

        if !isDir.boolValue {
            let attrs = try? fm.attributesOfItem(atPath: path)
            return (attrs?[.size] as? Int64) ?? 0
        }

        guard let enumerator = fm.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            total += Int64(size)
        }
        return total
    }
}
