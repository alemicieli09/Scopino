//
//  LoginItemManager.swift
//  Scopino
//

import Foundation
import ServiceManagement

/// Gestisce l'avvio al login e ripara registrazioni create da vecchie build Xcode.
@MainActor
final class LoginItemManager {

    static let shared = LoginItemManager()

    private let registeredPathKey = "loginItem.registeredBundlePath"
    private let service = SMAppService.mainApp

    private init() {}

    var isEnabled: Bool {
        service.status == .enabled
    }

    var canRegisterCurrentCopy: Bool {
        Bundle.main.bundleURL.standardizedFileURL.path.hasPrefix("/Applications/")
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            guard canRegisterCurrentCopy else {
                throw LoginItemError.appMustBeInstalled
            }
            if service.status != .enabled {
                try service.register()
            }
            rememberCurrentPath()
        } else {
            if service.status != .notRegistered {
                try service.unregister()
            }
            UserDefaults.standard.removeObject(forKey: registeredPathKey)
        }
    }

    /// Le versioni precedenti potevano registrare una copia dentro DerivedData.
    /// Se l'utente aveva già abilitato l'avvio, conserva la sua scelta ma
    /// sostituisce la registrazione con la copia stabile in /Applications.
    func repairRegistrationIfNeeded() {
        guard canRegisterCurrentCopy else { return }

        let currentPath = Bundle.main.bundleURL.standardizedFileURL.path
        let rememberedPath = UserDefaults.standard.string(forKey: registeredPathKey)
        guard rememberedPath != currentPath else { return }

        do {
            switch service.status {
            case .enabled:
                try service.unregister()
                try service.register()
                rememberCurrentPath()
                print("[LoginItem] Registrazione migrata a \(currentPath)")
            case .requiresApproval:
                // Una registrazione vecchia e disabilitata non deve restare
                // associata a una build temporanea che non esiste più.
                try service.unregister()
                UserDefaults.standard.removeObject(forKey: registeredPathKey)
                print("[LoginItem] Registrazione obsoleta rimossa")
            case .notRegistered, .notFound:
                break
            @unknown default:
                break
            }
        } catch {
            print("[LoginItem] Migrazione non riuscita: \(error)")
        }
    }

    private func rememberCurrentPath() {
        UserDefaults.standard.set(
            Bundle.main.bundleURL.standardizedFileURL.path,
            forKey: registeredPathKey
        )
    }
}

enum LoginItemError: LocalizedError {
    case appMustBeInstalled

    var errorDescription: String? {
        switch self {
        case .appMustBeInstalled:
            return "Per avviare Scopino al login, sposta prima l’app nella cartella Applicazioni."
        }
    }
}
