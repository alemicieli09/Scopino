//
//  HelperTool.swift
//  Scopino
//
//  Created by Alessandro Micieli on 04/05/2026.
//

import Foundation

final class HelperTool: NSObject, ScopinoHelperProtocol {

    private let userID: uid_t

    init(userID: uid_t) { self.userID = userID }

    func trashItems(
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
                guard userID != 0, let account = getpwuid(userID) else {
                    throw NSError(domain: "ScopinoHelper", code: 1, userInfo: [NSLocalizedDescriptionKey: "Utente non valido"])
                }
                let home = String(cString: account.pointee.pw_dir)
                let trash = URL(fileURLWithPath: home).appendingPathComponent(".Trash")
                // Never follow user-controlled symlinks with root privileges.
                guard trash.resolvingSymlinksInPath().path == trash.path,
                      let attributes = try? fm.attributesOfItem(atPath: trash.path),
                      attributes[.type] as? FileAttributeType == .typeDirectory,
                      (attributes[.ownerAccountID] as? NSNumber)?.uint32Value == userID,
                      let permissions = attributes[.posixPermissions] as? NSNumber,
                      permissions.intValue & 0o022 == 0 else {
                    throw NSError(domain: "ScopinoHelper", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cestino non disponibile o non sicuro"])
                }
                let destination = trash.appendingPathComponent(UUID().uuidString + "-" + URL(fileURLWithPath: path).lastPathComponent)
                let descriptor = open(trash.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
                guard descriptor >= 0 else { throw POSIXError(.EACCES) }
                defer { close(descriptor) }
                var status = stat()
                guard fstat(descriptor, &status) == 0, status.st_uid == userID,
                      status.st_mode & 0o022 == 0 else { throw POSIXError(.EACCES) }
                // Pin the destination directory; do not follow a swapped .Trash symlink.
                guard renameat(AT_FDCWD, path, descriptor, destination.lastPathComponent) == 0 else {
                    throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
                }
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
        reply("2.0.0")
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
