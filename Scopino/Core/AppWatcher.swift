//
//  AppWatcher.swift
//  Scopino
//
//  Created by Alessandro Micieli on 04/05/2026.
//

import Foundation

/// Monitora /Applications con FSEvents e notifica quando un'app viene rimossa o aggiunta.
final class AppWatcher {

    // MARK: - Public callbacks
    var onAppRemoved: ((_ appName: String, _ bundleID: String?) -> Void)?
    var onAppAdded:   ((_ appName: String, _ bundleID: String?) -> Void)?

    // MARK: - Private
    private var eventStream: FSEventStreamRef?
    private let watchedPath = "/Applications"
    private var knownApps: [String: String?] = [:] // [appName: bundleID?]
    private let queue = DispatchQueue(label: "com.scopino.appwatcher", qos: .utility)

    // MARK: - Start / Stop

    func start() {
        // Snapshot iniziale delle app presenti
        knownApps = currentApps()

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passRetained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, clientCallBackInfo, _, _, _, _ in
            guard let info = clientCallBackInfo else { return }
            let watcher = Unmanaged<AppWatcher>.fromOpaque(info).takeUnretainedValue()
            watcher.handleFSEvent()
        }

        eventStream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            [watchedPath] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5, // latenza secondi
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagNone)
        )

        if let stream = eventStream {
            FSEventStreamSetDispatchQueue(stream, queue)
            FSEventStreamStart(stream)
        }
    }

    func stop() {
        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            eventStream = nil
        }
    }

    // MARK: - FSEvent handler

    private func handleFSEvent() {
        let current = currentApps()

        // App rimosse (erano in knownApps, non sono più in current)
        for (name, bundleID) in knownApps {
            if current[name] == nil {
                DispatchQueue.main.async {
                    self.onAppRemoved?(name, bundleID)
                }
            }
        }

        // App aggiunte (sono in current, non erano in knownApps)
        for (name, bundleID) in current {
            if knownApps[name] == nil {
                DispatchQueue.main.async {
                    self.onAppAdded?(name, bundleID)
                }
            }
        }

        knownApps = current
    }

    // MARK: - Snapshot /Applications

    private func currentApps() -> [String: String?] {
        var result: [String: String?] = [:]
        let fm = FileManager.default

        guard let items = try? fm.contentsOfDirectory(atPath: watchedPath) else {
            return result
        }

        for item in items where item.hasSuffix(".app") {
            let appName = (item as NSString).deletingPathExtension
            let plistPath = "\(watchedPath)/\(item)/Contents/Info.plist"
            let bundleID = NSDictionary(contentsOfFile: plistPath)?["CFBundleIdentifier"] as? String
            result[appName] = bundleID
        }

        return result
    }
}
