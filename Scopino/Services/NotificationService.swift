//
//  NotificationService.swift
//  Scopino
//
//  Created by Alessandro Micieli on 04/05/2026.
//

import Foundation
import UserNotifications
import AppKit

/// Gestisce le notifiche macOS per Scopino.
final class NotificationService {

    static let shared = NotificationService()
    private init() {}

    // MARK: - Authorization

    /// Richiede il permesso per le notifiche.
    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            print("[NotificationService] Autorizzazione notifiche: \(granted)")
        } catch {
            print("[NotificationService] Errore autorizzazione: \(error)")
        }
    }

    /// Verifica se le notifiche sono autorizzate.
    func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    // MARK: - Notifiche

    /// Notifica quando vengono trovati residui dopo la rimozione di un'app.
    func notifyResidualsFound(for app: DetectedApp, count: Int, totalSize: String) {
        let content = UNMutableNotificationContent()
        content.title = "Residui trovati — \(app.displayName)"
        content.body = "\(count) elementi · \(totalSize) liberabili"
        content.sound = .default
        content.categoryIdentifier = "RESIDUALS_FOUND"

        // Azione diretta dalla notifica
        content.userInfo = ["appName": app.name, "bundleID": app.bundleID ?? ""]

        deliver(content, identifier: "residuals-\(app.name)-\(Date().timeIntervalSince1970)")
    }

    /// Notifica quando la pulizia è completata.
    func notifyCleanupCompleted(for app: DetectedApp, removed: Int, totalSize: String) {
        let content = UNMutableNotificationContent()
        content.title = "Pulizia completata ✓"
        content.body = "\(app.displayName) — \(removed) elementi rimossi · \(totalSize)"
        content.sound = .default

        deliver(content, identifier: "cleanup-done-\(app.name)-\(Date().timeIntervalSince1970)")
    }

    /// Notifica di errore parziale.
    func notifyCleanupPartial(for app: DetectedApp, removed: Int, failed: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Pulizia parziale — \(app.displayName)"
        content.body = "\(removed) rimossi, \(failed) non rimovibili (richiedono privilegi)"
        content.sound = .defaultCritical

        deliver(content, identifier: "cleanup-partial-\(app.name)-\(Date().timeIntervalSince1970)")
    }

    // MARK: - Actions setup

    /// Registra le categorie di notifica con azioni interattive.
    func setupCategories() {
        let cleanAction = UNNotificationAction(
            identifier: "CLEAN_NOW",
            title: "Pulisci ora",
            options: [.foreground]
        )

        let ignoreAction = UNNotificationAction(
            identifier: "IGNORE",
            title: "Ignora",
            options: [.destructive]
        )

        let residualsCategory = UNNotificationCategory(
            identifier: "RESIDUALS_FOUND",
            actions: [cleanAction, ignoreAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([residualsCategory])
    }

    // MARK: - Private

    private func deliver(_ content: UNMutableNotificationContent, identifier: String) {
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // immediata
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[NotificationService] Errore invio notifica: \(error)")
            }
        }
    }
}
