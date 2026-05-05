//
//  HelperProtocol.swift
//  Scopino
//
//  Created by Alessandro Micieli on 04/05/2026.
//

import Foundation

/// Protocollo XPC condiviso tra app principale e helper.
@objc protocol ScopinoHelperProtocol {

    /// Elimina i file ai path specificati.
    /// - Parameters:
    ///   - paths: array di path assoluti da eliminare
    ///   - reply: callback con array di errori (stringa vuota = successo)
    func removeItems(
        atPaths paths: [String],
        withReply reply: @escaping ([String]) -> Void
    )

    /// Verifica che l'helper sia raggiungibile.
    func getVersion(withReply reply: @escaping (String) -> Void)
}
