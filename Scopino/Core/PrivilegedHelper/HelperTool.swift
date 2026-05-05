//
//  HelperTool.swift
//  Scopino
//
//  Created by Alessandro Micieli on 04/05/2026.
//

import Foundation

/// Processo helper privilegiato — gira come root via XPC.
final class HelperTool: NSObject, ScopinoHelperProtocol {

    // MARK: - ScopinoHelperProtocol

    func removeItems(
        atPaths paths: [String],
        withReply reply: @escaping ([String]) -> Void
    ) {
        var errors: [String] = []
        let fm = FileManager.default

        for path in paths {
            // Protezione assoluta — non toccare mai path critici
            guard !isProtectedPath(path) else {
                errors.append("\(path): path protetto")
                continue
            }

            guard fm.fileExists(atPath: path) else {
                errors.append("") // già rimosso, ok
                continue
            }

            do {
                try fm.removeItem(atPath: path)
                errors.append("") // successo
                print("[Helper] Rimosso: \(path)")
            } catch {
                errors.append("\(path): \(error.localizedDescription)")
                print("[Helper] Errore: \(path) — \(error)")
            }
        }

        reply(errors)
    }

    func getVersion(withReply reply: @escaping (String) -> Void) {
        reply("1.0.0")
    }

    // MARK: - Safety

    private func isProtectedPath(_ path: String) -> Bool {
        let forbidden = [
            "/System/",
            "/usr/",
            "/bin/",
            "/sbin/",
            "/private/etc/",
            "/Users/",
            "/var/",
        ]
        return forbidden.contains(where: { path.hasPrefix($0) })
    }
}
