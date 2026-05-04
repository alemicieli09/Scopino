//
//  SessionStore.swift
//  Scopino
//
//  Created by Alessandro Micieli on 04/05/2026.
//

import Foundation
import Combine

/// Persiste e gestisce lo storico delle sessioni di pulizia.
final class SessionStore: ObservableObject {

    static let shared = SessionStore()
    private init() { load() }

    // MARK: - Published

    @Published private(set) var sessions: [CleanupSession] = []

    // MARK: - Persistence

    private let fileName = "scopino_sessions.json"

    private var storageURL: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let dir = appSupport.appendingPathComponent("Scopino", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        return dir.appendingPathComponent(fileName)
    }

    // MARK: - Codable mirror
    // CleanupSession è ObservableObject e non Codable.
    // Usiamo un DTO leggero per la persistenza.

    private struct SessionDTO: Codable {
        let id: UUID
        let appName: String
        let bundleID: String?
        let startDate: Date
        let state: String
        let totalSizeBytes: Int64
        let successCount: Int
        let failedCount: Int
        let skippedCount: Int
        let residualPaths: [String]
    }

    // MARK: - Public API

    /// Aggiunge una sessione completata allo store.
    func save(_ session: CleanupSession) {
        // Aggiunge solo sessioni terminali
        guard session.state == .completed || session.state == .cancelled else { return }

        // Evita duplicati
        if sessions.contains(where: { $0.id == session.id }) { return }

        sessions.insert(session, at: 0) // più recente in cima
        persist()
    }

    /// Rimuove una sessione dallo storico.
    func remove(_ session: CleanupSession) {
        sessions.removeAll { $0.id == session.id }
        persist()
    }

    /// Svuota tutto lo storico.
    func clearAll() {
        sessions.removeAll()
        persist()
    }

    // MARK: - Computed

    var totalFreedBytes: Int64 {
        sessions
            .filter { $0.state == .completed }
            .reduce(0) { $0 + $1.totalSizeBytes }
    }

    var totalFreedDisplay: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalFreedBytes)
    }

    var completedCount: Int {
        sessions.filter { $0.state == .completed }.count
    }

    // MARK: - Persistence: save

    private func persist() {
        let dtos = sessions.map { session -> SessionDTO in
            SessionDTO(
                id:              session.id,
                appName:         session.app.name,
                bundleID:        session.app.bundleID,
                startDate:       session.startDate,
                state:           stateString(session.state),
                totalSizeBytes:  session.totalSizeBytes,
                successCount:    session.successCount,
                failedCount:     session.failedCount,
                skippedCount:    session.skippedCount,
                residualPaths:   session.residuals.map { $0.path }
            )
        }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(dtos)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("[SessionStore] Errore salvataggio: \(error)")
        }
    }

    // MARK: - Persistence: load

    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }

        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let dtos = try decoder.decode([SessionDTO].self, from: data)

            sessions = dtos.map { dto -> CleanupSession in
                let app = DetectedApp(
                    name:        dto.appName,
                    bundleID:    dto.bundleID,
                    icon:        nil,
                    removalDate: dto.startDate
                )
                let session = CleanupSession(app: app)
                session.state = stateFromString(dto.state)

                // Ricostruisce un singolo residuo placeholder con la dimensione totale
                // così totalSizeBytes è corretto nella cronologia
                session.residuals = [
                    ResidualItem(
                        path:      "[\(dto.residualPaths.count) elementi]",
                        category:  .other,
                        sizeBytes: dto.totalSizeBytes  // ← usa il totale salvato
                    )
                ]
                return session
            }

            print("[SessionStore] Caricate \(sessions.count) sessioni.")
        } catch {
            print("[SessionStore] Errore caricamento: \(error)")
        }
    }

    // MARK: - State serialization

    private func stateString(_ state: CleanupSessionState) -> String {
        switch state {
        case .waitingForUser: return "waitingForUser"
        case .inProgress:     return "inProgress"
        case .completed:      return "completed"
        case .cancelled:      return "cancelled"
        }
    }

    private func stateFromString(_ string: String) -> CleanupSessionState {
        switch string {
        case "waitingForUser": return .waitingForUser
        case "inProgress":     return .inProgress
        case "completed":      return .completed
        case "cancelled":      return .cancelled
        default:               return .completed
        }
    }
}
