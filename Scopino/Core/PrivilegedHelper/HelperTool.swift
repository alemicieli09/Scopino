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
            guard !isProtectedPath(path) else {
                errors.append("\(path)|protetto")
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

    private func isProtectedPath(_ path: String) -> Bool {
        let forbidden = ["/System/", "/usr/", "/bin/", "/sbin/",
                        "/private/etc/", "/Users/", "/var/", "/Applications/"]
        return forbidden.contains(where: { path.hasPrefix($0) })
    }
}
