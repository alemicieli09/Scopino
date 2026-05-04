//
//  CleanupSession.swift
//  Scopino
//
//  Created by Alessandro Micieli on 04/05/2026.
//

import Foundation
import Combine

/// Stato di una sessione di pulizia.
enum CleanupSessionState {
    case waitingForUser     // residui trovati, in attesa di conferma
    case inProgress         // pulizia in corso
    case completed          // terminata con successo
    case cancelled          // l'utente ha annullato
}

/// Tiene insieme app rilevata, residui trovati e risultati della pulizia.
final class CleanupSession: ObservableObject, Identifiable {
    let id = UUID()
    let app: DetectedApp
    let startDate: Date

    @Published var residuals: [ResidualItem] = []
    @Published var state: CleanupSessionState = .waitingForUser
    @Published var results: [CleanupResult] = []
    @Published var progress: (completed: Int, total: Int) = (0, 0)

    // MARK: - Computed

    var totalSizeBytes: Int64 {
        residuals.filter { $0.isSelected }.reduce(0) { $0 + $1.sizeBytes }
    }

    var displayTotalSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSizeBytes)
    }

    var successCount: Int {
        results.filter { if case .success = $0 { return true }; return false }.count
    }

    var failedCount: Int {
        results.filter { if case .failed = $0 { return true }; return false }.count
    }

    var skippedCount: Int {
        results.filter { if case .skipped = $0 { return true }; return false }.count
    }

    // MARK: - Init

    init(app: DetectedApp) {
        self.app = app
        self.startDate = Date()
    }
}
