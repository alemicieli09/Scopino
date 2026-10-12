//
//  PermissionChecker.swift
//  Scopino
//
//  Created by Alessandro Micieli on 04/05/2026.
//

import Foundation
import AppKit

final class PermissionChecker {

    private static let onboardingPresentedKey = "permissions.onboardingPresented"

    // MARK: - Full Disk Access

    static func hasFDAPermission() -> Bool {
        // macOS non espone un'API pubblica per interrogare direttamente FDA.
        // Il database TCC dell'utente esiste su ogni installazione ed è leggibile
        // solo dai processi ai quali è stato concesso Accesso completo al disco.
        let tccDatabase = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db")

        guard FileManager.default.fileExists(atPath: tccDatabase.path) else {
            return false
        }

        do {
            let handle = try FileHandle(forReadingFrom: tccDatabase)
            try handle.close()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Automation

    static func hasAutomationPermission() -> Bool {
        let target = NSAppleScript(source: "tell application \"Finder\" to return name")
        var error: NSDictionary?
        target?.executeAndReturnError(&error)
        return error == nil
    }

    // MARK: - Permission status

    enum PermissionStatus {
        case granted
        case denied
        case unknown
    }

    static func checkAll() -> [String: PermissionStatus] {
        return [
            "Full Disk Access": hasFDAPermission() ? .granted : .denied,
        ]
    }

    // MARK: - Open System Settings

    static func openFDASettings() {
        let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        )!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Onboarding gate

    static func needsOnboarding() -> Bool {
        !UserDefaults.standard.bool(forKey: onboardingPresentedKey)
            && !hasFDAPermission()
    }

    static func markOnboardingPresented() {
        UserDefaults.standard.set(true, forKey: onboardingPresentedKey)
    }
}
