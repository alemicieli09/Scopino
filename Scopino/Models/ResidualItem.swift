//
//  ResidualItem.swift
//  Scopino
//
//  Created by Alessandro Micieli on 04/05/2026.
//

import Foundation

/// Categoria del residuo, usata per UI e ordinamento.
enum ResidualCategory: String, CaseIterable {
    case preferences     = "Preferenze"
    case applicationSupport = "Application Support"
    case cache           = "Cache"
    case logs            = "Log"
    case container       = "Container"
    case groupContainer  = "Group Container"
    case launchAgent     = "Launch Agent"
    case launchDaemon    = "Launch Daemon"
    case savedState      = "Stato Salvato"
    case other           = "Altro"

    var systemIcon: String {
        switch self {
        case .preferences:        return "gearshape"
        case .applicationSupport: return "folder"
        case .cache:              return "clock.arrow.circlepath"
        case .logs:               return "doc.text"
        case .container:          return "shippingbox"
        case .groupContainer:     return "shippingbox.fill"
        case .launchAgent:        return "bolt"
        case .launchDaemon:       return "bolt.fill"
        case .savedState:         return "tray.full"
        case .other:              return "questionmark.folder"
        }
    }
}

/// Rappresenta un singolo file/cartella residuo trovato sul disco.
struct ResidualItem: Identifiable {
    let id = UUID()
    let path: String
    let category: ResidualCategory
    var sizeBytes: Int64
    var isSelected: Bool = true  // selezionato per default → pulizia totale

    /// Nome display (ultima componente del path)
    var displayName: String {
        (path as NSString).lastPathComponent
    }

    /// Dimensione human-readable
    var displaySize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: sizeBytes)
    }

    /// Indica se è un file di sistema che richiede privilegi elevati
    var requiresPrivileges: Bool {
        path.hasPrefix("/Library/") ||
        path.hasPrefix("/System/")
    }
}
