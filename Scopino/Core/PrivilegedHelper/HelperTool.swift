//
//  HelperTool.swift
//  Scopino
//
//  Created by Alessandro Micieli on 04/05/2026.
//

import Foundation

final class HelperTool: NSObject, ScopinoHelperProtocol {

    func removeItems(
        atPaths paths: [String],
        withReply reply: @escaping ([String]) -> Void
    ) {
        var errors: [String] = []
        let fm = FileManager.default

        for path in paths {
            guard isAllowedPath(path) else {
                errors.append("\(path)|path non autorizzato")
                continue
            }
            guard fm.fileExists(atPath: path) else {
                errors.append("")
                continue
            }
            do {
                try fm.removeItem(atPath: path)
                errors.append("")
                NSLog("[ScopinoHelper] Rimosso: \(path)")
            } catch {
                errors.append("\(path)|\(error.localizedDescription)")
                NSLog("[ScopinoHelper] Errore: \(path) — \(error)")
            }
        }
        reply(errors)
    }

    func getVersion(withReply reply: @escaping (String) -> Void) {
        reply("1.0.0")
    }

    /// Il daemon accetta esclusivamente figli diretti delle directory
    /// di sistema che Scopino analizza. Standardizzazione e risoluzione dei
    /// symlink impediscono traversal e reindirizzamenti verso altri volumi.
    private func isAllowedPath(_ path: String) -> Bool {
        let allowedRoots = [
            "/Library/Application Support",
            "/Library/Preferences",
            "/Library/LaunchAgents",
            "/Library/LaunchDaemons",
            "/Library/PrivilegedHelperTools",
        ]

        let originalURL = URL(fileURLWithPath: path).standardizedFileURL
        let resolvedURL = originalURL.resolvingSymlinksInPath().standardizedFileURL

        guard originalURL.path == resolvedURL.path,
              !originalURL.lastPathComponent.isEmpty,
              originalURL.lastPathComponent != ".",
              originalURL.lastPathComponent != ".." else {
            return false
        }

        let parent = originalURL.deletingLastPathComponent().path
        guard allowedRoots.contains(parent) else { return false }

        let values = try? originalURL.resourceValues(forKeys: [.isSymbolicLinkKey])
        return values?.isSymbolicLink != true
    }
}
