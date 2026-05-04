//
//  PermissionChecker.swift
//  Scopino
//
//  Created by Alessandro Micieli on 04/05/2026.
//

import Foundation
import AppKit

final class PermissionChecker {

    // MARK: - Full Disk Access

    static func hasFDAPermission() -> Bool {
        let testPaths = [
            "\(NSHomeDirectory())/Library/Safari/History.db",
            "/Library/Application Support/com.apple.TCC/TCC.db",
        ]
        for path in testPaths {
            if FileManager.default.isReadableFile(atPath: path) {
                return true
            }
        }
        return false
    }

    // MARK: - Request FDA

    static func requestFDAPermission() {
        let path = "/Library/Application Support/com.apple.TCC/TCC.db"
        _ = FileManager.default.fileExists(atPath: path)
        _ = try? Data(contentsOf: URL(fileURLWithPath: path))
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
        return !hasFDAPermission()
    }
}
