//
//  main.swift
//  ScopinoHelper
//
//  Created by Alessandro Micieli on 05/05/2026.
//

import Foundation

/// Entry point dell'XPC Helper.
final class HelperDelegate: NSObject, NSXPCListenerDelegate {

    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection connection: NSXPCConnection
    ) -> Bool {

        // Verifica che il chiamante sia Scopino.app
        guard isCallerTrusted(connection) else {
            print("[Helper] Connessione rifiutata — chiamante non fidato")
            return false
        }

        connection.exportedInterface = NSXPCInterface(
            with: ScopinoHelperProtocol.self
        )
        connection.exportedObject = HelperTool()
        connection.resume()
        return true
    }

    private func isCallerTrusted(_ connection: NSXPCConnection) -> Bool {
        // In produzione verificare con SecCodeCopyGuestWithAttributes
        // Per ora accetta connessioni locali
        return true
    }
}

let delegate = HelperDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()
