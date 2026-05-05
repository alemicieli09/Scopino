//
//  HelperInstaller.swift
//  Scopino
//
//  Created by Alessandro Micieli on 04/05/2026.
//

import Foundation
import ServiceManagement

/// Installa e gestisce la connessione con l'XPC Helper.
final class HelperInstaller {

    static let shared = HelperInstaller()
    private init() {}

    private let helperBundleID = "com.alemicieli.Scopino.helper"
    private var connection: NSXPCConnection?

    // MARK: - Install

    /// Registra l'helper con SMAppService.
    func installIfNeeded() {
        let service = SMAppService.daemon(plistName: "com.alemicieli.Scopino.helper.plist")

        switch service.status {
        case .notRegistered, .notFound:
            do {
                try service.register()
                print("[HelperInstaller] Helper registrato.")
            } catch {
                print("[HelperInstaller] Errore registrazione: \(error)")
            }
        case .enabled:
            print("[HelperInstaller] Helper già attivo.")
        case .requiresApproval:
            print("[HelperInstaller] Richiede approvazione utente.")
            SMAppService.openSystemSettingsLoginItems()
        @unknown default:
            break
        }
    }

    // MARK: - Connection

    func connect() -> NSXPCConnection {
        if let existing = connection {
            return existing
        }

        let conn = NSXPCConnection(serviceName: helperBundleID)
        conn.remoteObjectInterface = NSXPCInterface(
            with: ScopinoHelperProtocol.self
        )
        conn.invalidationHandler = { [weak self] in
            print("[HelperInstaller] Connessione invalidata.")
            self?.connection = nil
        }
        conn.resume()
        connection = conn
        return conn
    }

    func disconnect() {
        connection?.invalidate()
        connection = nil
    }

    // MARK: - Remove items via Helper

    func removeItems(atPaths paths: [String]) async -> [String] {
        await withCheckedContinuation { continuation in
            let conn = connect()

            guard let helper = conn.remoteObjectProxyWithErrorHandler({ error in
                print("[HelperInstaller] Proxy error: \(error)")
                continuation.resume(returning: Array(repeating: error.localizedDescription, count: paths.count))
            }) as? ScopinoHelperProtocol else {
                continuation.resume(returning: ["Impossibile connettersi all'helper"])
                return
            }

            helper.removeItems(atPaths: paths) { errors in
                continuation.resume(returning: errors)
            }
        }
    }
}
