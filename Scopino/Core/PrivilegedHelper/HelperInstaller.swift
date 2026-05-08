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

    // MARK: - Install

    func installIfNeeded() {
        let service = SMAppService.daemon(
            plistName: "com.alemicieli.Scopino.helper.plist"
        )

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
            print("[HelperInstaller] Richiede approvazione.")
            SMAppService.openSystemSettingsLoginItems()
        @unknown default:
            break
        }
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
        await withCheckedContinuation { continuation in
            let conn = getConnection()

            guard let helper = conn.remoteObjectProxyWithErrorHandler({ error in
                print("[HelperInstaller] Proxy error: \(error)")
                let errors = Array(repeating: error.localizedDescription, count: paths.count)
                continuation.resume(returning: errors)
            }) as? ScopinoHelperProtocol else {
                continuation.resume(returning: ["Impossibile connettersi all'helper"])
                return
            }

            helper.removeItems(atPaths: paths) { errors in
                continuation.resume(returning: errors)
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
