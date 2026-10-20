//
//  DetectedApp.swift
//  Scopino
//
//  Created by Alessandro Micieli on 04/05/2026.
//

import AppKit

/// Rappresenta un'app che è stata rimossa da /Applications.
nonisolated struct DetectedApp: Identifiable {
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
        if let bid = bundleID { tokens.append(bid) }
        return tokens
    }
}
