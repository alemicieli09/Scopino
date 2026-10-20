import Foundation
import AppKit

nonisolated struct InstalledApplication: Sendable {
    let name: String
    let bundleID: String
    let path: String
}

nonisolated struct ApplicationInventory: Sendable {
    var apps: [InstalledApplication] = []
    var unreadablePaths: [String] = []

    static func collect(roots: [String]? = nil) -> ApplicationInventory {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        var result = ApplicationInventory()
        let roots = roots ?? ["/Applications", "\(home)/Applications", "/System/Applications",
                              "/System/Library/CoreServices", "/Users/Shared", "\(home)/Library/Application Support"]
        for root in roots where fm.fileExists(atPath: root) {
            guard let enumerator = fm.enumerator(at: URL(fileURLWithPath: root),
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles], errorHandler: { url, _ in
                    result.unreadablePaths.append(url.path); return true
                }) else { result.unreadablePaths.append(root); continue }
            while let url = enumerator.nextObject() as? URL {
                if url.pathExtension == "app" {
                    enumerator.skipDescendants()
                    let plist = url.appendingPathComponent("Contents/Info.plist")
                    do {
                        let data = try Data(contentsOf: plist)
                        let dict = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
                        if let id = dict?["CFBundleIdentifier"] as? String {
                            result.apps.append(InstalledApplication(name: url.deletingPathExtension().lastPathComponent,
                                                                    bundleID: id, path: url.path))
                        }
                    } catch { result.unreadablePaths.append(plist.path) }
                }
            }
        }
        return result
    }

    func contains(_ id: String) -> Bool {
        apps.contains { ResidualAssociation.belongs(identifier: id, to: $0.bundleID) }
    }
}

nonisolated enum ResidualAssociation {
    static let suffixes = [".binarycookies", ".savedState", ".plist"]
    static func identifier(from filename: String) -> String? {
        var value = filename
        if value.hasPrefix("group.") { value = String(value.dropFirst(6)) }
        let first = value.split(separator: ".").first.map(String.init) ?? ""
        if first.count == 10, first.allSatisfy({ $0.isASCII && ($0.isUppercase || $0.isNumber) }), value.contains(".") {
            value = String(value.dropFirst(11))
        }
        for suffix in suffixes where value.hasSuffix(suffix) { value = String(value.dropLast(suffix.count)); break }
        let parts = value.split(separator: ".")
        guard parts.count >= 2,
              ["com", "org", "net", "io", "app", "co", "de", "fr", "eu", "me", "dev", "us", "notion", "developer"].contains(String(parts[0])),
              !value.contains(" ") else { return nil }
        return value
    }

    static func belongs(identifier: String, to owner: String) -> Bool {
        let candidate = identifier.lowercased(), owner = owner.lowercased()
        return candidate == owner || candidate.hasPrefix(owner + ".")
    }

    static func matches(filename: String, bundleID: String?, appName: String) -> Bool {
        if let id = identifier(from: filename), let owner = bundleID {
            let value = id.lowercased(), owner = owner.lowercased()
            let suffixes = [".shipit", ".helper", ".helper.renderer", ".helper.gpu", ".helper.plugin", ".updater"]
            if value == owner || suffixes.contains(where: { value == owner + $0 }) { return true }
        }
        // Human-readable support directories require an exact app name.
        return !appName.isEmpty && filename.caseInsensitiveCompare(appName) == .orderedSame
    }
}

nonisolated struct ResidualScanReport: Sendable {
    var items: [ResidualItem] = []
    var unreadablePaths: [String] = []
}

/// Shared disk enumeration and ownership policy for automatic and manual scans.
nonisolated final class ResidualScanEngine: Sendable {
    private let home: String
    private let targetOverrides: [(String, ResidualCategory)]?
    private let knownOverrides: [String: [String]]?
    init(home: String = FileManager.default.homeDirectoryForCurrentUser.path,
         targets: [(String, ResidualCategory)]? = nil, knownPaths: [String: [String]]? = nil) {
        self.home = home; self.targetOverrides = targets; self.knownOverrides = knownPaths
    }

    var targets: [(String, ResidualCategory)] {
        if let targetOverrides { return targetOverrides }
        let userTargets: [(String, ResidualCategory)] = [("Preferences", .preferences), ("Application Support", .applicationSupport),
         ("Caches", .cache), ("Logs", .logs), ("Containers", .container),
         ("Group Containers", .groupContainer), ("LaunchAgents", .launchAgent),
         ("Saved Application State", .savedState), ("HTTPStorages", .other),
         ("WebKit", .other), ("Cookies", .other)]
        return userTargets.map { ("\(home)/Library/\($0.0)", $0.1) }
        + [("/Library/LaunchAgents", .launchAgent), ("/Library/LaunchDaemons", .launchDaemon),
           ("/Library/PrivilegedHelperTools", .other), ("/Library/Application Support", .applicationSupport),
           ("/Library/Preferences", .preferences)]
    }

    @concurrent func scan(app: DetectedApp? = nil, inventory: ApplicationInventory) async -> ResidualScanReport {
        let fm = FileManager.default
        var report = ResidualScanReport(unreadablePaths: inventory.unreadablePaths)
        var seen = Set<String>()
        var knownPaths: [String: String] = [:]
        let database = if let knownOverrides { knownOverrides } else { await MainActor.run { KnownResidualsDB.shared.allPaths } }
        for (owner, paths) in database {
            for path in paths { knownPaths[path] = owner }
        }
        for (directory, category) in targets {
            let urls: [URL]
            do { urls = try fm.contentsOfDirectory(at: URL(fileURLWithPath: directory),
                                                    includingPropertiesForKeys: [.isSymbolicLinkKey]) }
            catch {
                let code = (error as NSError).code
                if code != NSFileReadNoSuchFileError && code != NSFileNoSuchFileError {
                    report.unreadablePaths.append(directory)
                }
                continue
            }
            for url in urls {
                let name = url.lastPathComponent
                guard !name.hasPrefix("."),
                      (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == false else { continue }
                let id = ResidualAssociation.identifier(from: name)
                if id?.hasPrefix("com.apple.") == true || name.hasPrefix("group.com.apple.") { continue }
                let knownOwner = knownPaths[url.path]
                let owner = knownOwner ?? id
                if let app {
                    guard knownOwner == app.bundleID || ResidualAssociation.matches(filename: name, bundleID: app.bundleID, appName: app.name) else { continue }
                } else {
                    guard owner != nil else { continue }
                }
                let installedOwner = owner.map { inventory.contains($0) } ?? false
                let installedName = inventory.apps.contains { $0.name.caseInsensitiveCompare(name) == .orderedSame }
                if installedOwner || installedName { continue }
                if let owner, let installedURL = await MainActor.run(body: {
                    NSWorkspace.shared.urlForApplication(withBundleIdentifier: owner)
                }), !installedURL.path.contains("/.Trash/"), fm.fileExists(atPath: installedURL.path) { continue }
                guard seen.insert(url.path).inserted else { continue }
                let namespace = owner?.split(separator: ".").prefix(2).joined(separator: ".")
                let sharesVendor = namespace.map { vendor in
                    inventory.apps.contains { $0.bundleID.lowercased().hasPrefix(vendor.lowercased() + ".") }
                } ?? false
                let shared = category == .groupContainer || sharesVendor
                let confirmed = knownOwner != nil || (app != nil && id != nil)
                var item = ResidualItem(path: url.path, category: category, sizeBytes: 0,
                                        isSelected: false)
                item.confidence = shared ? .shared : (confirmed ? .confirmed : .review)
                item.associationReason = knownOwner.map { "Percorso documentato per \($0)" }
                    ?? id.map { "Identificativo completo: \($0)" }
                    ?? "Nome esatto dell’app: \(name)"
                if shared { item.associationReason += "; verificare gli altri utilizzatori" }
                report.items.append(item)
            }
        }
        // Documented paths can be nested and must be examined independently.
        for (path, owner) in knownPaths where fm.fileExists(atPath: path) && !seen.contains(path) {
            if let app { guard app.bundleID == owner else { continue } }
            guard !inventory.contains(owner), !owner.hasPrefix("com.apple."),
                  !inventory.apps.contains(where: { $0.path.hasPrefix(path + "/") }) else { continue }
            let url = URL(fileURLWithPath: path)
            guard (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == false else { continue }
            let category = targets.first { path.hasPrefix($0.0 + "/") }?.1 ?? .other
            var item = ResidualItem(path: path, category: category, sizeBytes: 0, isSelected: false)
            item.associationReason = "Percorso documentato per \(owner)"
            report.items.append(item); seen.insert(path)
        }
        // Prefer the most specific path only when no ancestor is already proposed.
        report.items = report.items.filter { item in
            !report.items.contains { other in other.path != item.path && item.path.hasPrefix(other.path + "/") }
        }
        for index in report.items.indices {
            let measurement = await Self.measure(report.items[index].path)
            report.items[index].sizeBytes = measurement.bytes
            report.unreadablePaths.append(contentsOf: measurement.errors)
        }
        report.items.sort { $0.path < $1.path }
        report.unreadablePaths = Array(Set(report.unreadablePaths)).sorted()
        return report
    }

    static func measure(_ path: String) async -> (bytes: Int64, errors: [String]) {
        await Task.detached(priority: .utility) {
            let fm = FileManager.default
            var errors: [String] = [], total: Int64 = 0
            let url = URL(fileURLWithPath: path)
            do {
                let values = try url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
                if values.isDirectory != true { return (Int64(values.fileSize ?? 0), []) }
            } catch { return (0, [path]) }
            guard let enumerator = fm.enumerator(at: url,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey],
                errorHandler: { url, _ in errors.append(url.path); return true }) else { return (0, [path]) }
            while let child = enumerator.nextObject() as? URL {
                do {
                    let values = try child.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey])
                    if values.isSymbolicLink == true { enumerator.skipDescendants(); continue }
                    if values.isRegularFile == true { total += Int64(values.fileSize ?? 0) }
                } catch { errors.append(child.path) }
            }
            return (total, errors)
        }.value
    }
}
