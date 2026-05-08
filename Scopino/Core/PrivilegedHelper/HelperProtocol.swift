//
//  HelperProtocol.swift
//  Scopino
//
//  Created by Alessandro Micieli on 04/05/2026.
//

import Foundation

/// Protocollo XPC condiviso tra Scopino.app e ScopinoHelper.
@objc protocol ScopinoHelperProtocol {

    /// Elimina i file ai path specificati con privilegi root.
    func removeItems(
        atPaths paths: [String],
        withReply reply: @escaping (_ errors: [String]) -> Void
    )

    /// Verifica che l'helper sia raggiungibile.
    func getVersion(
        withReply reply: @escaping (_ version: String) -> Void
    )
}
