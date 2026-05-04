//
//  KnownResidualsDB.swift
//  Scopino
//
//  Created by Alessandro Micieli on 04/05/2026.
//

import Foundation

/// Carica KnownResiduals.json e fornisce path extra
/// per app popolari note, oltre a quelli trovati dalla scansione generica.
final class KnownResidualsDB {

    static let shared = KnownResidualsDB()
    private init() { load() }

    // MARK: - Model

    private struct Entry: Decodable {
        let bundleID: String
        let extraPaths: [String]
    }

    private struct DB: Decodable {
        let entries: [Entry]
    }

    // MARK: - Storage

    private var db: [String: [String]] = [:] // [bundleID: [paths]]

    // MARK: - Load

    private func load() {
        guard let url = Bundle.main.url(
            forResource: "KnownResiduals",
            withExtension: "json"
        ) else {
            print("[KnownResidualsDB] KnownResiduals.json non trovato nel bundle.")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(DB.self, from: data)
            for entry in decoded.entries {
                db[entry.bundleID] = entry.extraPaths
            }
            print("[KnownResidualsDB] Caricate \(db.count) entry.")
        } catch {
            print("[KnownResidualsDB] Errore parsing JSON: \(error)")
        }
    }

    // MARK: - Query

    /// Ritorna i path extra noti per un bundleID.
    /// I path con ~ vengono espansi con la home reale.
    func extraPaths(for bundleID: String) -> [String] {
        guard let raw = db[bundleID] else { return [] }
        return raw.map { expandTilde($0) }
    }

    /// Ritorna true se il bundleID è nel database.
    func isKnown(_ bundleID: String) -> Bool {
        db[bundleID] != nil
    }

    // MARK: - Tilde expansion

    private func expandTilde(_ path: String) -> String {
        if path.hasPrefix("~/") {
            return NSHomeDirectory() + path.dropFirst(1)
        }
        if path.hasPrefix("~") {
            return NSHomeDirectory() + path.dropFirst()
        }
        return path
    }
}
