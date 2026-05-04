//
//  AppRemovalDetector.swift
//  Scopino
//
//  Created by Alessandro Micieli on 04/05/2026.
//

import Foundation
import AppKit

/// Riceve gli eventi da AppWatcher e costruisce un oggetto DetectedApp
/// pronto per essere passato alla UI per la proposta di pulizia.
final class AppRemovalDetector {

    // MARK: - Public callback
    var onAppReadyForCleanup: ((_ app: DetectedApp) -> Void)?

    // MARK: - Private
    private let watcher = AppWatcher()

    // MARK: - Init

    init() {
        watcher.onAppRemoved = { [weak self] appName, bundleID in
            self?.handleRemoval(appName: appName, bundleID: bundleID)
        }
    }

    // MARK: - Start / Stop

    func start() {
        watcher.start()
    }

    func stop() {
        watcher.stop()
    }

    // MARK: - Handler

    private func handleRemoval(appName: String, bundleID: String?) {
        // Ignora app di sistema Apple — non ha senso pulirle
        if let bid = bundleID, isAppleSystemApp(bid) {
            return
        }

        // Piccolo delay: lascia che il sistema finisca la rimozione
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            let app = DetectedApp(
                name: appName,
                bundleID: bundleID,
                icon: self?.iconForRemovedApp(appName: appName),
                removalDate: Date()
            )
            self?.onAppReadyForCleanup?(app)
        }
    }

    // MARK: - Helpers

    /// Cerca l'icona in NSWorkspace (potrebbe ancora essere in cache)
    private func iconForRemovedApp(appName: String) -> NSImage? {
        // Prova prima dalla cache di NSWorkspace
        let appPath = "/Applications/\(appName).app"
        let icon = NSWorkspace.shared.icon(forFile: appPath)

        // NSWorkspace restituisce sempre qualcosa (anche icona generica).
        // Usiamo la generica come fallback accettabile.
        return icon
    }

    /// Filtra le app Apple core per non proporle mai come "da pulire"
    private func isAppleSystemApp(_ bundleID: String) -> Bool {
        let applePrefix = [
            "com.apple.",
            "com.osxfuse.",
        ]
        return applePrefix.contains(where: { bundleID.hasPrefix($0) })
    }
}
