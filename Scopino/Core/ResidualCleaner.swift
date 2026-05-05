//
//  ResidualCleaner.swift
//  Scopino
//
//  Created by Alessandro Micieli on 04/05/2026.
//

import Foundation
import AppKit

/// Risultato dell'operazione di pulizia per un singolo item.
enum CleanupResult {
    case success(path: String)
    case skipped(path: String, reason: String)
    case failed(path: String, error: Error)
}

/// Esegue la rimozione dei residui selezionati, spostando nel Trash.
final class ResidualCleaner {

    // MARK: - Public callback (progress)
    var onProgress: ((_ completed: Int, _ total: Int, _ current: ResidualItem) -> Void)?

    // MARK: - Clean

    /// Pulisce tutti gli item selezionati. Ritorna il riepilogo.
    func clean(items: [ResidualItem]) async -> [CleanupResult] {
        let selected = items.filter { $0.isSelected }
        var results: [CleanupResult] = []

        for (index, item) in selected.enumerated() {
            await MainActor.run {
                onProgress?(index, selected.count, item)
            }

            let result = await moveToTrash(item: item)
            results.append(result)
        }

        // Notifica completamento
        await MainActor.run {
            onProgress?(selected.count, selected.count, selected.last ?? selected[0])
        }

        return results
    }

    // MARK: - Trash

    private func moveToTrash(item: ResidualItem) async -> CleanupResult {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let fm = FileManager.default
                let url = URL(fileURLWithPath: item.path)

                guard fm.fileExists(atPath: item.path) else {
                    continuation.resume(returning: .skipped(
                        path: item.path,
                        reason: "File non trovato"
                    ))
                    return
                }

                if self.isProtectedPath(item.path) {
                    continuation.resume(returning: .skipped(
                        path: item.path,
                        reason: "Path protetto"
                    ))
                    return
                }

                // File privilegiati → delega all'XPC Helper
                if item.requiresPrivileges {
                    Task {
                        let errors = await HelperInstaller.shared.removeItems(
                            atPaths: [item.path]
                        )
                        if errors.first?.isEmpty == true {
                            continuation.resume(returning: .success(path: item.path))
                        } else {
                            continuation.resume(returning: .skipped(
                                path: item.path,
                                reason: errors.first ?? "Errore helper"
                            ))
                        }
                    }
                    return
                }

                // File normali → Trash
                do {
                    var resultURL: NSURL?
                    try fm.trashItem(at: url, resultingItemURL: &resultURL)
                    continuation.resume(returning: .success(path: item.path))
                } catch {
                    continuation.resume(returning: .failed(
                        path: item.path,
                        error: error
                    ))
                }
            }
        }
    }

    // MARK: - Safety guard

    /// Blocklist assoluta — questi path non vengono mai toccati.
    private func isProtectedPath(_ path: String) -> Bool {
        let protected = [
            "/System/",
            "/usr/",
            "/bin/",
            "/sbin/",
            "/private/etc/",
            NSHomeDirectory() + "/Library/Keychains/",
            NSHomeDirectory() + "/Library/Mail/",
            NSHomeDirectory() + "/Documents/",
            NSHomeDirectory() + "/Desktop/",
            NSHomeDirectory() + "/Downloads/",
        ]
        return protected.contains(where: { path.hasPrefix($0) })
    }
}
