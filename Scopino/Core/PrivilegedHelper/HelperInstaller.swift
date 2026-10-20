//
//  HelperInstaller.swift
//  Scopino
//
//  Created by Alessandro Micieli on 04/05/2026.
//

import Foundation
import ServiceManagement

/// Gestisce installazione e comunicazione con ScopinoHelper.
final class HelperInstaller {

    static let shared = HelperInstaller()
    private init() {}

    private let helperBundleID = "com.alemicieli.Scopino.helper"
    private var connection: NSXPCConnection?

    private var service: SMAppService {
        SMAppService.daemon(plistName: "com.alemicieli.Scopino.helper.plist")
    }

    // MARK: - Registration

    /// Registra il daemon solo in risposta a un'azione dell'utente che richiede
    /// la rimozione di elementi privilegiati. Non apre mai Impostazioni.
    @discardableResult
    func registerWhenNeeded() throws -> SMAppService.Status {
        guard Bundle.main.bundleURL.standardizedFileURL.path.hasPrefix("/Applications/") else {
            throw HelperInstallerError.appMustBeInstalled
        }

        switch service.status {
        case .notRegistered, .notFound:
            try service.register()
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        @unknown default:
            return service.status
        }
        return service.status
    }

    func openApprovalSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    // MARK: - Connection

    private func makeConnection() -> NSXPCConnection {
        let conn = NSXPCConnection(
            machServiceName: helperBundleID,
            options: .privileged
        )
        conn.remoteObjectInterface = NSXPCInterface(
            with: ScopinoHelperProtocol.self
        )
        conn.invalidationHandler = { [weak self] in
            print("[HelperInstaller] Connessione invalidata.")
            self?.connection = nil
        }
        conn.interruptionHandler = { [weak self] in
            print("[HelperInstaller] Connessione interrotta.")
            self?.connection = nil
        }
        conn.resume()
        return conn
    }

    private func getConnection() -> NSXPCConnection {
        if let existing = connection { return existing }
        let conn = makeConnection()
        connection = conn
        return conn
    }

    func disconnect() {
        connection?.invalidate()
        connection = nil
    }

    // MARK: - Remove items

    func removeItems(atPaths paths: [String]) async -> [String] {
        guard service.status == .enabled else {
            return Array(
                repeating: "Helper non autorizzato nelle Impostazioni di Sistema",
                count: paths.count
            )
        }

        return await withCheckedContinuation { continuation in
            let conn = getConnection()

            guard let helper = conn.remoteObjectProxyWithErrorHandler({ error in
                print("[HelperInstaller] Proxy error: \(error)")
                let errors = Array(repeating: error.localizedDescription, count: paths.count)
                continuation.resume(returning: errors)
            }) as? ScopinoHelperProtocol else {
                continuation.resume(returning: ["Impossibile connettersi all'helper"])
                return
            }

            helper.getVersion { version in
                guard version == "2.0.0" else {
                    continuation.resume(returning: Array(
                        repeating: "Helper da aggiornare: la versione installata non supporta il Cestino recuperabile",
                        count: paths.count
                    ))
                    return
                }
                helper.trashItems(atPaths: paths) { errors in
                    continuation.resume(returning: errors)
                }
            }
        }
    }

    // MARK: - Ping

    func ping() async -> Bool {
        await withCheckedContinuation { continuation in
            let conn = getConnection()
            guard let helper = conn.remoteObjectProxyWithErrorHandler({ _ in
                continuation.resume(returning: false)
            }) as? ScopinoHelperProtocol else {
                continuation.resume(returning: false)
                return
            }
            helper.getVersion { _ in
                continuation.resume(returning: true)
            }
        }
    }
}

enum HelperInstallerError: LocalizedError {
    case appMustBeInstalled

    var errorDescription: String? {
        "Per autorizzare la pulizia dei file di sistema, installa prima Scopino nella cartella Applicazioni."
    }
}
