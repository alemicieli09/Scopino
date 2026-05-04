//
//  HistoryView.swift
//  Scopino
//
//  Created by Alessandro Micieli on 04/05/2026.
//

import SwiftUI

struct HistoryView: View {

    let sessions: [CleanupSession]
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {

            // Toolbar
            toolbar
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

            Divider()

            if sessions.isEmpty {
                emptyState
            } else {
                sessionList
            }
        }
        .frame(width: 480, height: 520)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            Text("Cronologia pulizie")
                .font(.headline)

            Spacer()

            // Totale spazio liberato
            VStack(alignment: .trailing, spacing: 2) {
                Text("Totale liberato")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(totalFreedDisplay)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
            }

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Nessuna pulizia effettuata")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("La cronologia apparirà qui dopo la prima pulizia.")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }

    // MARK: - Session list

    private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(sessions) { session in
                    sessionRow(session)
                    Divider()
                        .padding(.leading, 56)
                }
            }
        }
    }

    private func sessionRow(_ session: CleanupSession) -> some View {
        HStack(spacing: 14) {
            // Icona app
            Group {
                if let icon = session.app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 36, height: 36)
                } else {
                    Image(systemName: "app.dashed")
                        .frame(width: 36, height: 36)
                        .foregroundStyle(.secondary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(session.app.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    // Data
                    Label(
                        session.startDate.formatted(date: .abbreviated, time: .shortened),
                        systemImage: "calendar"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    // Elementi rimossi
                    Label(
                        "\(session.successCount) rimossi",
                        systemImage: "trash"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Badge stato + dimensione
            VStack(alignment: .trailing, spacing: 4) {
                stateBadge(session.state)

                Text(session.displayTotalSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - State badge

    private func stateBadge(_ state: CleanupSessionState) -> some View {
        let (label, color): (String, Color) = {
            switch state {
            case .completed:      return ("Completata", .green)
            case .cancelled:      return ("Annullata", .secondary)
            case .inProgress:     return ("In corso", .blue)
            case .waitingForUser: return ("In attesa", .orange)
            }
        }()

        return Text(label)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }

    // MARK: - Total freed

    private var totalFreedDisplay: String {
        let total = sessions
            .filter { $0.state == .completed }
            .reduce(Int64(0)) { $0 + $1.totalSizeBytes }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: total)
    }
}
