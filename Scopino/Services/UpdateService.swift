//
//  UpdateService.swift
//  Scopino
//
//  Created by Alessandro Micieli on 05/05/2026.
//

import Foundation
import Sparkle

/// Gestisce gli aggiornamenti automatici via Sparkle.
final class UpdateService: NSObject {

    static let shared = UpdateService()

    private var updaterController: SPUStandardUpdaterController?

    private override init() {
        super.init()
    }

    // MARK: - Setup

    func setup() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
    }

    // MARK: - Manual check

    func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }

    // MARK: - Updater reference

    var updater: SPUUpdater? {
        updaterController?.updater
    }
}

// MARK: - SPUUpdaterDelegate

extension UpdateService: SPUUpdaterDelegate {

    func feedURLString(for updater: SPUUpdater) -> String? {
        return "https://alemicieli09.github.io/Scopino/appcast/appcast.xml"
    }

    func updater(
        _ updater: SPUUpdater,
        didFinishLoading appcast: SUAppcast
    ) {
        print("[UpdateService] Appcast caricato — \(appcast.items.count) versioni")
    }

    func updater(
        _ updater: SPUUpdater,
        didFindValidUpdate item: SUAppcastItem
    ) {
        print("[UpdateService] Aggiornamento disponibile: \(item.displayVersionString)")
    }
}
