//
//  PlistReader.swift
//  Scopino
//
//  Created by Alessandro Micieli on 04/05/2026.
//

import Foundation

/// Legge Info.plist delle app e ne estrae i metadata utili.
final class PlistReader {

    // MARK: - Bundle info

    struct AppInfo {
        let bundleID: String?
        let displayName: String?
        let version: String?
        let minimumOSVersion: String?
        let executableName: String?
    }

    /// Legge Info.plist da un path .app e ritorna AppInfo.
    static func readAppInfo(at appPath: String) -> AppInfo {
        let plistPath = "\(appPath)/Contents/Info.plist"

        guard let dict = NSDictionary(contentsOfFile: plistPath) else {
            return AppInfo(
                bundleID: nil,
                displayName: nil,
                version: nil,
                minimumOSVersion: nil,
                executableName: nil
            )
        }

        return AppInfo(
            bundleID:         dict["CFBundleIdentifier"] as? String,
            displayName:      dict["CFBundleDisplayName"] as? String
                              ?? dict["CFBundleName"] as? String,
            version:          dict["CFBundleShortVersionString"] as? String,
            minimumOSVersion: dict["LSMinimumSystemVersion"] as? String,
            executableName:   dict["CFBundleExecutable"] as? String
        )
    }

    /// Estrae solo il bundleID da un .app path.
    static func bundleID(at appPath: String) -> String? {
        let plistPath = "\(appPath)/Contents/Info.plist"
        return NSDictionary(contentsOfFile: plistPath)?["CFBundleIdentifier"] as? String
    }

    // MARK: - LaunchAgent / Daemon plist

    struct LaunchInfo {
        let label: String?
        let programPath: String?
        let runAtLoad: Bool
    }

    /// Legge un LaunchAgent/Daemon plist e ne estrae le info rilevanti.
    static func readLaunchInfo(at plistPath: String) -> LaunchInfo {
        guard let dict = NSDictionary(contentsOfFile: plistPath) else {
            return LaunchInfo(label: nil, programPath: nil, runAtLoad: false)
        }

        let programArgs = dict["ProgramArguments"] as? [String]
        let program = dict["Program"] as? String
                      ?? programArgs?.first

        return LaunchInfo(
            label:       dict["Label"] as? String,
            programPath: program,
            runAtLoad:   dict["RunAtLoad"] as? Bool ?? false
        )
    }

    // MARK: - Generic plist

    /// Legge un plist generico e ritorna il dizionario raw.
    static func readRaw(at path: String) -> [String: Any]? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let obj = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
              ) as? [String: Any]
        else { return nil }
        return obj
    }
}
