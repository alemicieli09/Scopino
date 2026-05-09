//
//  ManualScanView.swift
//  Scopino
//
//  Created by Alessandro Micieli on 08/05/2026.
//

import SwiftUI

struct ManualScanView: View {

    let onClose: () -> Void

    @State private var sessions: [CleanupSession] = []
    @State private var isScanning = false
    @State private var scanDone = false

    private let service = ManualScanService()

    var body: some View {
        VStack(spacing: 0) {
            toolbar
                .padding(.horizontal, 24)
                .padding(.vertical, 16)

            Divider()

            if isScanning {
                scanningView
            } else if scanDone && sessions.isEmpty {
                emptyView
            } else if !sessions.isEmpty {
                resultsList
            } else {
                startView
            }
        }
        .frame(width: 560, height: 520)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Scansione manuale")
                    .font(.headline)
                Text("Cerca residui di app già rimosse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Start view

    private var startView: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.08))
                    .frame(width: 88, height: 88)
                Image(systemName: "magnifyingglass.circle.fill")
                    .resizable()
                    .frame(width: 48, height: 48)
                    .foregroundStyle(.blue)
            }
            VStack(spacing: 8) {
                Text("Cerca residui sul disco")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Scopino analizzerà la libreria di sistema cercando file\ndi app che non sono più installate.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                startScan()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    Text("Avvia scansione")
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            Spacer()
        }
        .padding(40)
    }

    // MARK: - Scanning view

    private var scanningView: some View {
        VStack(spacing: 24) {
            Spacer()
            ProgressView()
                .scaleEffect(1.4)
                .tint(.blue)
            Text("Scansione in corso…")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Analisi dei path di sistema")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Empty view

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .resizable()
                .frame(width: 52, height: 52)
                .foregroundStyle(.green)
            Text("Nessun residuo trovato")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Il tuo Mac è pulito — nessun file orfano rilevato.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Chiudi") { onClose() }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .padding(.bottom, 32)
        }
    }

    // MARK: - Results list

    private var resultsList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(sessions.count) app con residui · \(totalSizeDisplay)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Pulisci tutto") {
                    cleanAll()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.small)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color(.controlBackgroundColor))

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(sessions) { session in
                        sessionRow(session)
                        Divider()
                            .padding(.leading, 60)
                    }
                }
            }
        }
    }

    // MARK: - Session row

    private func sessionRow(_ session: CleanupSession) -> some View {
        HStack(spacing: 14) {

            // Icona Finder — al posto del quadratino
            Button {
                showInFinder(session)
            } label: {
                Group {
                    if let img = NSImage(named: "FinderIcon") {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                    } else {
                        // Fallback SF Symbol se immagine non trovata
                        Image(systemName: "folder.badge.magnifyingglass")
                            .font(.title2)
                            .foregroundStyle(.blue)
                            .frame(width: 32, height: 32)
                    }
                }
            }
            .buttonStyle(.plain)
            .help("Mostra nel Finder")
            .cursor(.pointingHand)

            // Info app
            VStack(alignment: .leading, spacing: 3) {
                Text(session.app.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                if let bid = session.app.bundleID {
                    Text(bid)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Dimensione + contatore
            VStack(alignment: .trailing, spacing: 2) {
                Text(session.displayTotalSize)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.red)
                Text("\(session.residuals.count) elementi")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Bottone Pulisci
            Button("Pulisci") {
                cleanSession(session)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .controlSize(.small)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    // MARK: - Finder

    private func showInFinder(_ session: CleanupSession) {
        guard let firstPath = session.residuals.first?.path else { return }
        let url = URL(fileURLWithPath: firstPath)

        if session.residuals.count == 1 {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            let parent = url.deletingLastPathComponent()
            NSWorkspace.shared.selectFile(
                firstPath,
                inFileViewerRootedAtPath: parent.path
            )
        }
    }

    // MARK: - Actions

    private func startScan() {
        isScanning = true
        scanDone = false
        sessions = []
        Task {
            let found = await service.scan()
            await MainActor.run {
                sessions = found
                isScanning = false
                scanDone = true
            }
        }
    }

    private func cleanSession(_ session: CleanupSession) {
        NotificationCenter.default.post(
            name: .scopinoStartCleanup,
            object: session
        )
        onClose()
    }

    private func cleanAll() {
        for session in sessions {
            NotificationCenter.default.post(
                name: .scopinoStartCleanup,
                object: session
            )
        }
        onClose()
    }

    // MARK: - Computed

    private var totalSizeDisplay: String {
        let total = sessions.reduce(Int64(0)) { $0 + $1.totalSizeBytes }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: total)
    }
}

// MARK: - Cursor modifier

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { inside in
            if inside { cursor.push() } else { NSCursor.pop() }
        }
    }
}

// MARK: - Notification name

extension Notification.Name {
    static let scopinoStartCleanup = Notification.Name("scopinoStartCleanup")
}
