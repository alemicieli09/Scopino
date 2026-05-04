//
//  MenuBarView.swift
//  Scopino
//
//  Created by Alessandro Micieli on 04/05/2026.
//

import SwiftUI

struct MenuBarView: View {

    let activeSessions: [CleanupSession]
    let onShowHistory: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            header
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()

            // Sessioni attive
            if activeSessions.isEmpty {
                emptyState
            } else {
                activeSessionsList
            }

            Divider()

            // Footer actions
            footerActions
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
        }
        .frame(width: 300)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "trash.slash.circle.fill")
                .font(.title2)
                .foregroundStyle(.red)

            VStack(alignment: .leading, spacing: 2) {
                Text("Scopino")
                    .font(.headline)
                Text("Pulizia residui app")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Badge sessioni attive
            if !activeSessions.isEmpty {
                Text("\(activeSessions.count)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.red, in: Capsule())
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title)
                    .foregroundStyle(.green)
                Text("Nessun residuo rilevato")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Scopino monitora /Applications\nin background.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(.vertical, 24)
    }

    // MARK: - Active sessions list

    private var activeSessionsList: some View {
        VStack(spacing: 0) {
            ForEach(activeSessions) { session in
                sessionRow(session)
                Divider()
                    .padding(.leading, 44)
            }
        }
    }

    private func sessionRow(_ session: CleanupSession) -> some View {
        HStack(spacing: 10) {
            // Icona app
            Group {
                if let icon = session.app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 28, height: 28)
                } else {
                    Image(systemName: "app.dashed")
                        .frame(width: 28, height: 28)
                        .foregroundStyle(.secondary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(session.app.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(stateLabel(session.state))
                    .font(.caption)
                    .foregroundStyle(stateColor(session.state))
            }

            Spacer()

            // Dimensione
            Text(session.displayTotalSize)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Footer

    private var footerActions: some View {
        HStack {
            Button {
                onShowHistory()
            } label: {
                Label("Cronologia", systemImage: "clock")
                    .font(.subheadline)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            Button {
                onQuit()
            } label: {
                Label("Esci", systemImage: "power")
                    .font(.subheadline)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Helpers

    private func stateLabel(_ state: CleanupSessionState) -> String {
        switch state {
        case .waitingForUser: return "In attesa di conferma"
        case .inProgress:     return "Pulizia in corso…"
        case .completed:      return "Completata"
        case .cancelled:      return "Annullata"
        }
    }

    private func stateColor(_ state: CleanupSessionState) -> Color {
        switch state {
        case .waitingForUser: return .orange
        case .inProgress:     return .blue
        case .completed:      return .green
        case .cancelled:      return .secondary
        }
    }
}
