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

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.path, "/tmp/review")
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
