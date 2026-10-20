import Foundation

final class ManualScanService {
    private(set) var unreadablePaths: [String] = []

    func scan() async -> [CleanupSession] {
        let inventory = await Task.detached(priority: .utility) { ApplicationInventory.collect() }.value
        let report = await ResidualScanEngine().scan(inventory: inventory)
        unreadablePaths = report.unreadablePaths
        var groups: [String: [ResidualItem]] = [:]
        let known = KnownResidualsDB.shared.allPaths
        for item in report.items {
            let identifier = ResidualAssociation.identifier(from: item.displayName)
            let namespaceOwner = identifier.flatMap { id in
                known.keys.filter { ResidualAssociation.belongs(identifier: id, to: $0) }
                    .max { $0.count < $1.count }
            }
            let owner = known.first { $0.value.contains(item.path) }?.key
                ?? namespaceOwner ?? identifier ?? item.displayName
            groups[owner, default: []].append(item)
        }
        return groups.map { owner, items in
            let session = CleanupSession(app: DetectedApp(name: owner, bundleID: owner,
                                                         icon: nil, removalDate: Date()))
            session.residuals = Self.reviewItems(from: items)
            return session
        }.sorted { $0.detectedSizeBytes > $1.detectedSizeBytes }
    }

    static func reviewItems(from residuals: [ResidualItem]) -> [ResidualItem] {
        residuals.map { item in
            var copy = item
            copy.isSelected = false
            return copy
        }
    }
}
