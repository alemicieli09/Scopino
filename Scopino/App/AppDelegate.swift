//
//  AppDelegate.swift
//  Scopino
//
//  Created by Alessandro Micieli on 04/05/2026.
//

import AppKit
import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Menu Bar
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    // MARK: - Core
    private let detector = AppRemovalDetector()
    private let finder   = ResidualFinder()
    private let cleaner  = ResidualCleaner()

    // MARK: - State
    private var activeSessions: [CleanupSession] = []
    private var proposalWindows: [NSWindow] = []
    private var settingsWindow: NSWindow?
    private var historyWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        setupDetector()

        // Triggera la comparsa di Scopino nella lista FDA
        PermissionChecker.requestFDAPermission()

        // Mostra onboarding se FDA non concessa
        if PermissionChecker.needsOnboarding() {
            showOnboarding()
        }
        
        // Notifiche
        UNUserNotificationCenter.current().delegate = self
        NotificationService.shared.setupCategories()
        Task { await NotificationService.shared.requestAuthorization() }

        // FDA
        PermissionChecker.requestFDAPermission()
        if PermissionChecker.needsOnboarding() {
            showOnboarding()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        detector.stop()
    }

    // MARK: - Menu Bar setup

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            if let icon = NSImage(named: "MenuBarIconTemplate") {
                icon.isTemplate = true
                button.image = icon
            } else {
                button.image = NSImage(systemSymbolName: "trash.slash.circle", accessibilityDescription: "Scopino")
            }
            button.action = #selector(togglePopover)
            button.target = self
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Cronologia", action: #selector(showHistory), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Impostazioni…", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Esci", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    // MARK: - Detector setup

    private func setupDetector() {
        detector.onAppReadyForCleanup = { [weak self] app in
            guard let self else { return }
            Task { await self.startCleanupFlow(for: app) }
        }
        detector.start()
    }

    // MARK: - Cleanup flow

    @MainActor
    private func startCleanupFlow(for app: DetectedApp) async {
        let session = CleanupSession(app: app)
        activeSessions.append(session)

        let residuals = await finder.findResiduals(for: app)

        guard !residuals.isEmpty else {
            activeSessions.removeAll { $0.id == session.id }
            return
        }

        session.residuals = residuals

        // Notifica residui trovati
        NotificationService.shared.notifyResidualsFound(
            for: app,
            count: residuals.count,
            totalSize: session.displayTotalSize
        )

        showProposalWindow(for: session)
    }

    // MARK: - Proposal Window

    @MainActor
    private func showProposalWindow(for session: CleanupSession) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 600),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "Scopino — \(session.app.displayName)"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.center()
        window.isReleasedWhenClosed = false

        let rootView = CleanupProposalWindow(session: session) { [weak self, weak window] action in
            guard let self, let window else { return }
            switch action {
            case .clean:
                Task { await self.runCleaner(session: session, window: window) }
            case .cancel:
                session.state = .cancelled
                window.close()
                self.removeSession(session)
            case .close:
                window.close()
                self.removeSession(session)
            }
        }

        window.contentView = NSHostingView(rootView: rootView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        proposalWindows.append(window)
    }

    // MARK: - Run cleaner

    @MainActor
    private func runCleaner(session: CleanupSession, window: NSWindow) async {
        session.state = .inProgress

        cleaner.onProgress = { completed, total, _ in
            DispatchQueue.main.async {
                session.progress = (completed, total)
            }
        }

        let results = await cleaner.clean(items: session.residuals)
        session.results = results
        session.state = .completed
        SessionStore.shared.save(session)

        // Notifica risultato
        if session.failedCount > 0 {
            NotificationService.shared.notifyCleanupPartial(
                for: session.app,
                removed: session.successCount,
                failed: session.failedCount
            )
        } else {
            NotificationService.shared.notifyCleanupCompleted(
                for: session.app,
                removed: session.successCount,
                totalSize: session.displayTotalSize
            )
        }
    }

    // MARK: - History Window

    @objc private func showHistory() {
        if let existing = historyWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Scopino — Cronologia"
        window.titlebarAppearsTransparent = true
        window.center()
        window.isReleasedWhenClosed = false

        let rootView = HistoryView(
            sessions: SessionStore.shared.sessions
        ) { [weak window] in
            window?.close()
        }

        window.contentView = NSHostingView(rootView: rootView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        historyWindow = window
    }

    // MARK: - Settings Window

    @objc private func showSettings() {
        if let existing = settingsWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 340),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Scopino — Impostazioni"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.center()
        window.isReleasedWhenClosed = false

        let rootView = SettingsView()
        window.contentView = NSHostingView(rootView: rootView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
    }

    // MARK: - Onboarding Window

    private func showOnboarding() {
        if let existing = onboardingWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 600),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Benvenuto in Scopino"
        window.titlebarAppearsTransparent = true
        window.center()
        window.isReleasedWhenClosed = false

        let rootView = PermissionRequestView {
            window.close()
        }

        window.contentView = NSHostingView(rootView: rootView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        onboardingWindow = window
    }

    // MARK: - Helpers

    private func removeSession(_ session: CleanupSession) {
        activeSessions.removeAll { $0.id == session.id }
    }

    @objc private func togglePopover() {
        // Placeholder — implementato con MenuBarView
    }
}

// MARK: - Proposal action

enum ProposalAction {
    case clean
    case cancel
    case close
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {

    /// Notifica ricevuta mentre l'app è in foreground — mostrala comunque.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]
    }

    /// L'utente ha tappato la notifica o un'azione.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let appName  = userInfo["appName"] as? String ?? ""

        switch response.actionIdentifier {
        case "CLEAN_NOW":
            // Porta in primo piano la finestra di proposta se ancora aperta
            await MainActor.run {
                NSApp.activate(ignoringOtherApps: true)
                if let window = proposalWindows.first(where: {
                    $0.title.contains(appName)
                }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }
        case "IGNORE":
            break
        default:
            // Tap sulla notifica → porta in primo piano
            await MainActor.run {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}
