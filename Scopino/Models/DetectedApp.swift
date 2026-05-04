//
//  DetectedApp.swift
//  Scopino
//
//  Created by Alessandro Micieli on 04/05/2026.
//

import AppKit

/// Rappresenta un'app che è stata rimossa da /Applications.
struct DetectedApp: Identifiable {
    let id = UUID()
    let name: String
    let bundleID: String?
    let icon: NSImage?
    let removalDate: Date

    /// Stringa display-friendly per la UI
    var displayName: String { name }

    /// Tutti i possibili identificatori da usare per la ricerca dei residui
    var searchTokens: [String] {
        var tokens: [String] = [name]
        if let bid = bundleID {
            tokens.append(bid)
            // Aggiunge anche la parte finale del bundleID (es. "firefox" da "org.mozilla.firefox")
            if let last = bid.split(separator: ".").last {
                let lastStr = String(last)
                if lastStr != name.lowercased() {
                    tokens.append(lastStr)
                }
            }
        }
        return tokens
    }
}
