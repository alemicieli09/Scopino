//
//  FileSystemService.swift
//  Scopino
//
//  Created by Alessandro Micieli on 04/05/2026.
//

import Foundation

/// Wrapper attorno a FileManager con utility per dimensioni,
/// attributi e operazioni sicure sul filesystem.
final class FileSystemService {

    static let shared = FileSystemService()
    private init() {}

    private let fm = FileManager.default

    // MARK: - Existence

    func exists(at path: String) -> Bool {
        fm.fileExists(atPath: path)
    }

    func isDirectory(at path: String) -> Bool {
        var isDir: ObjCBool = false
        fm.fileExists(atPath: path, isDirectory: &isDir)
        return isDir.boolValue
    }

    // MARK: - Size

    /// Calcola la dimensione ricorsiva di file o cartella.
    func size(at path: String) -> Int64 {
        let url = URL(fileURLWithPath: path)

        guard isDirectory(at: path) else {
            // File singolo
            let attrs = try? fm.attributesOfItem(atPath: path)
            return (attrs?[.size] as? Int64) ?? 0
        }

        // Directory — enumerazione ricorsiva
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(
                forKeys: [.fileSizeKey, .isRegularFileKey]
            ) else { continue }
            if values.isRegularFile == true {
                total += Int64(values.fileSize ?? 0)
            }
        }
        return total
    }

    /// Formatta bytes in stringa human-readable.
    func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    // MARK: - Directory contents

    /// Lista il contenuto di una directory (non ricorsivo).
    func contents(of path: String) -> [String] {
        (try? fm.contentsOfDirectory(atPath: path)) ?? []
    }

    /// Lista il contenuto con path completi.
    func fullPathContents(of path: String) -> [String] {
        contents(of: path).map { "\(path)/\($0)" }
    }

    // MARK: - Attributes

    func creationDate(at path: String) -> Date? {
        let attrs = try? fm.attributesOfItem(atPath: path)
        return attrs?[.creationDate] as? Date
    }

    func modificationDate(at path: String) -> Date? {
        let attrs = try? fm.attributesOfItem(atPath: path)
        return attrs?[.modificationDate] as? Date
    }

    // MARK: - Trash

    /// Sposta nel Cestino. Ritorna il nuovo path nel Cestino.
    @discardableResult
    func moveToTrash(path: String) throws -> String {
        let url = URL(fileURLWithPath: path)
        var resultURL: NSURL?
        try fm.trashItem(at: url, resultingItemURL: &resultURL)
        return resultURL?.path ?? path
    }

    // MARK: - Scan for tokens

    /// Scansiona una directory cercando item che contengono
    /// almeno uno dei token nel nome (case-insensitive).
    func scan(
        directory: String,
        matchingAnyOf tokens: [String]
    ) -> [String] {
        guard fm.fileExists(atPath: directory) else { return [] }

        return contents(of: directory).compactMap { item in
            let lower = item.lowercased()
            let matches = tokens.contains(where: { lower.contains($0.lowercased()) })
            return matches ? "\(directory)/\(item)" : nil
        }
    }
}
