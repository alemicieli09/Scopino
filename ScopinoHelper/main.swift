//
//  main.swift
//  ScopinoHelper
//
//  Created by Alessandro Micieli on 05/05/2026.
//

import Foundation
import Security

/// Entry point dell'XPC Helper.
final class HelperDelegate: NSObject, NSXPCListenerDelegate {

    private let clientRequirement = "anchor apple generic and identifier \"com.alemicieli.Scopino\" and certificate leaf[subject.OU] = \"E2BL3D4ETT\""

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
        let attributes = [
            kSecGuestAttributePid as String: NSNumber(value: connection.processIdentifier)
        ] as CFDictionary

        var guestCode: SecCode?
        guard SecCodeCopyGuestWithAttributes(
            nil,
            attributes,
            SecCSFlags(),
            &guestCode
        ) == errSecSuccess, let guestCode else {
            return false
        }

        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(
            clientRequirement as CFString,
            SecCSFlags(),
            &requirement
        ) == errSecSuccess, let requirement else {
            return false
        }

        return SecCodeCheckValidity(
            guestCode,
            SecCSFlags(),
            requirement
        ) == errSecSuccess
    }
}

let delegate = HelperDelegate()
let listener = NSXPCListener(machServiceName: "com.alemicieli.Scopino.helper")
listener.delegate = delegate
listener.resume()
RunLoop.current.run()
