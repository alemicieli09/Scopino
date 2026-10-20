import XCTest
@testable import Scopino

@MainActor
final class ScopinoTests: XCTestCase {
    func testDetectedAppAvoidsDuplicateSearchTokens() {
        let app = DetectedApp(
            name: "Firefox",
            bundleID: "org.mozilla.firefox",
            icon: nil,
            removalDate: .distantPast
        )

        XCTAssertEqual(app.searchTokens, ["Firefox", "org.mozilla.firefox"])
    }

    func testCleanupSessionCountsOnlySelectedBytes() {
        let session = makeSession()
        session.residuals = [
            ResidualItem(path: "/tmp/selected", category: .cache, sizeBytes: 4_096),
            ResidualItem(
                path: "/tmp/review-only",
                category: .logs,
                sizeBytes: 8_192,
                isSelected: false
            ),
        ]

        XCTAssertEqual(session.totalSizeBytes, 4_096)
        XCTAssertEqual(session.detectedSizeBytes, 12_288)
        XCTAssertTrue(session.hasSelectedItems)
    }

    func testManualScanRequiresExplicitSelection() {
        let candidates = [
            ResidualItem(path: "/tmp/tiny", category: .cache, sizeBytes: 1_024),
            ResidualItem(path: "/tmp/review", category: .cache, sizeBytes: 1_025),
        ]

        let results = ManualScanService.reviewItems(from: candidates)

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results.last?.path, "/tmp/review")
        XCTAssertEqual(results.first?.isSelected, false)
    }

    func testCleanerDoesNothingForEmptySelection() async {
        let cleaner = ResidualCleaner()
        var progressCalls = 0
        cleaner.onProgress = { _, _, _ in progressCalls += 1 }
        let items = [
            ResidualItem(
                path: "/tmp/must-not-be-touched",
                category: .cache,
                sizeBytes: 2_048,
                isSelected: false
            ),
        ]

        let results = await cleaner.clean(items: items)

        XCTAssertTrue(results.isEmpty)
        XCTAssertEqual(progressCalls, 0)
    }

    func testResidualPrivilegeClassificationUsesSystemLibraryOnly() {
        let privileged = ResidualItem(
            path: "/Library/LaunchDaemons/example.plist",
            category: .launchDaemon,
            sizeBytes: 100
        )
        let userLibrary = ResidualItem(
            path: "/Users/test/Library/Preferences/example.plist",
            category: .preferences,
            sizeBytes: 100
        )

        XCTAssertTrue(privileged.requiresPrivileges)
        XCTAssertFalse(userLibrary.requiresPrivileges)
    }

    func testNotionNeverMatchesGenericIDOrOtherApp() {
        for name in ["com.android.Emulator.plist", "com.apple.FileProvider.Domains.plist", "com.apple.HearingAids.plist", "Notion Calendar"] {
            XCTAssertFalse(ResidualAssociation.matches(filename: name, bundleID: "notion.id", appName: "Notion"))
        }
        XCTAssertTrue(ResidualAssociation.matches(filename: "notion.id.plist", bundleID: "notion.id", appName: "Notion"))
        XCTAssertTrue(ResidualAssociation.matches(filename: "notion.id.ShipIt", bundleID: "notion.id", appName: "Notion"))
    }

    func testCalendarDoesNotClaimOtherElectronApps() {
        XCTAssertFalse(ResidualAssociation.matches(filename: "com.electron.rekordboxagent.plist", bundleID: "com.cron.electron", appName: "Notion Calendar"))
        XCTAssertTrue(ResidualAssociation.matches(filename: "com.cron.electron.ShipIt", bundleID: "com.cron.electron", appName: "Notion Calendar"))
    }

    func testIdentifiersPreserveDotsAndVersionNumbers() {
        XCTAssertEqual(ResidualAssociation.identifier(from: "com.azureus.vuze"), "com.azureus.vuze")
        XCTAssertEqual(ResidualAssociation.identifier(from: "com.vercel.cli"), "com.vercel.cli")
        XCTAssertEqual(ResidualAssociation.identifier(from: "com.sketchup.SketchUp.2023.plist"), "com.sketchup.SketchUp.2023")
        XCTAssertEqual(ResidualAssociation.identifier(from: "notion.id.plist"), "notion.id")
    }

    func testInstalledMicrosoftAppDoesNotHideOtherProducts() {
        let inventory = ApplicationInventory(apps: [InstalledApplication(name: "Word", bundleID: "com.microsoft.Word", path: "/Applications/Word.app")])
        XCTAssertFalse(inventory.contains("com.microsoft.Outlook"))
        XCTAssertTrue(inventory.contains("com.microsoft.Word.helper"))
    }

    func testInventoryFindsNestedAppsAndProtectsUnreadableBundles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let contents = root.appendingPathComponent("Teams.localized/Teams.app/Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: ["CFBundleIdentifier": "com.microsoft.teams2"], format: .xml, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))
        let inventory = ApplicationInventory.collect(roots: [root.path])
        XCTAssertTrue(inventory.contains("com.microsoft.teams2.widgetextension"))
        XCTAssertTrue(inventory.unreadablePaths.isEmpty)
        try FileManager.default.removeItem(at: contents.appendingPathComponent("Info.plist"))
        XCTAssertFalse(ApplicationInventory.collect(roots: [root.path]).unreadablePaths.isEmpty)
    }

    func testEngineFindsSmallAndNamedResidualsButExcludesInstalledAndApple() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for name in ["com.example.removed.plist", "com.example.active.plist", "com.apple.HearingAids.plist", "GIMP"] {
            try Data([1]).write(to: root.appendingPathComponent(name))
        }
        let inventory = ApplicationInventory(apps: [InstalledApplication(name: "Active", bundleID: "com.example.active", path: "/Applications/Active.app")])
        let engine = ResidualScanEngine(targets: [(root.path, .preferences)],
            knownPaths: ["org.gimp.gimp-3.0": [root.appendingPathComponent("GIMP").path]])
        let report = await engine.scan(inventory: inventory)
        XCTAssertEqual(Set(report.items.map(\.displayName)), ["com.example.removed.plist", "GIMP"])
        XCTAssertTrue(report.items.allSatisfy { !$0.isSelected && !$0.associationReason.isEmpty })
        XCTAssertTrue(report.unreadablePaths.isEmpty)
        XCTAssertEqual(report.items.first(where: { $0.displayName == "com.example.removed.plist" })?.confidence, .shared)
    }

    func testEngineReportsDirectoryReadFailure() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        try Data([1]).write(to: file)
        let report = await ResidualScanEngine(targets: [(file.path, .cache)], knownPaths: [:])
            .scan(inventory: ApplicationInventory())
        XCTAssertTrue(report.items.isEmpty)
        XCTAssertEqual(report.unreadablePaths, [file.path])
    }

    func testAutomaticScanUsesSameOwnershipRules() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for name in ["notion.id.plist", "com.android.Emulator.plist", "Notion Calendar"] {
            try Data([1]).write(to: root.appendingPathComponent(name))
        }
        let engine = ResidualScanEngine(targets: [(root.path, .preferences)], knownPaths: [:])
        let app = DetectedApp(name: "Notion", bundleID: "notion.id", icon: nil, removalDate: .distantPast)
        let report = await engine.scan(app: app, inventory: ApplicationInventory())
        XCTAssertEqual(report.items.map(\.displayName), ["notion.id.plist"])
        XCTAssertEqual(report.items.first?.confidence, .confirmed)
        XCTAssertFalse(report.items.first?.isSelected ?? true)
        let installed = ApplicationInventory(apps: [InstalledApplication(name: "Notion", bundleID: "notion.id", path: "/Applications/Notion.app")])
        let protected = await engine.scan(app: app, inventory: installed)
        XCTAssertTrue(protected.items.isEmpty)
    }

    private func makeSession() -> CleanupSession {
        CleanupSession(
            app: DetectedApp(
                name: "Test App",
                bundleID: "com.example.test",
                icon: nil,
                removalDate: .distantPast
            )
        )
    }
}
