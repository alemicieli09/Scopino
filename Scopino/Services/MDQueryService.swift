//
//  MDQueryService.swift
//  Scopino
//
//  Created by Alessandro Micieli on 04/05/2026.
//

import Foundation
import CoreServices

/// Usa Spotlight (MDQuery) per trovare file associati a un bundleID
/// o nome app — utile per residui in path non standard.
final class MDQueryService {

    // MARK: - Search

    /// Cerca file sul disco associati ai token forniti.
    /// Ritorna i path trovati (esclusi path di sistema).
    func findFiles(
        matchingTokens tokens: [String],
        scope: [String] = [NSHomeDirectory()]
    ) async -> [String] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var results: [String] = []

                for token in tokens {
                    let found = self.runQuery(token: token, scope: scope)
                    results.append(contentsOf: found)
                }

                // Deduplicazione
                let unique = Array(Set(results)).sorted()
                continuation.resume(returning: unique)
            }
        }
    }

    // MARK: - MDQuery execution

    private func runQuery(token: String, scope: [String]) -> [String] {
        // Query Spotlight: cerca file con kMDItemDisplayName o path
        // che contengono il token
        let queryString = "kMDItemDisplayName == '*\(token)*'cd"

        guard let query = MDQueryCreate(
            nil,
            queryString as CFString,
            nil,
            nil
        ) else { return [] }

        // Imposta scope
        MDQuerySetSearchScope(
            query,
            scope as CFArray,
            0
        )

        // Esecuzione sincrona (siamo già su background thread)
        MDQuerySetMaxCount(query, 50)

        guard MDQueryExecute(query, CFOptionFlags(kMDQuerySynchronous.rawValue))
        else { return [] }

        var paths: [String] = []
        let count = MDQueryGetResultCount(query)

        for i in 0..<count {
            guard let rawPtr = MDQueryGetResultAtIndex(query, i) else { continue }
            let item = Unmanaged<MDItem>.fromOpaque(rawPtr).takeUnretainedValue()

            guard let path = MDItemCopyAttribute(
                item, kMDItemPath
            ) as? String else { continue }

            // Filtra path di sistema e l'app stessa
            if !isExcludedPath(path) {
                paths.append(path)
            }
        }

        return paths
    }

    // MARK: - Path filter

    private func isExcludedPath(_ path: String) -> Bool {
        let excluded = [
            "/System/",
            "/Applications/",
            "/usr/",
            "/bin/",
            "/sbin/",
        ]
        return excluded.contains(where: { path.hasPrefix($0) })
    }
}
