import Foundation

final class ResidualFinder {
    private(set) var unreadablePaths: [String] = []

    func findResiduals(for app: DetectedApp) async -> [ResidualItem] {
        let inventory = await Task.detached(priority: .utility) { ApplicationInventory.collect() }.value
        let report = await ResidualScanEngine().scan(app: app, inventory: inventory)
        unreadablePaths = report.unreadablePaths
        return report.items
    }

    static func sizeOf(path: String) async -> Int64 {
        await ResidualScanEngine.measure(path).bytes
    }
}
