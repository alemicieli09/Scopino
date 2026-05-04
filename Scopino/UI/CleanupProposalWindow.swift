//
//  CleanupProposalWindow.swift
//  Scopino
//
//  Created by Alessandro Micieli on 04/05/2026.
//

import SwiftUI
import AppKit

struct CleanupProposalWindow: View {

    @ObservedObject var session: CleanupSession
    let onAction: (ProposalAction) -> Void

    @State private var showDetails = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // Sfondo sfumato
            LinearGradient(
                colors: [Color(.windowBackgroundColor), Color(.controlBackgroundColor)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            switch session.state {
            case .waitingForUser:
                proposalView
            case .inProgress:
                CleanupProgressView(session: session)
            case .completed:
                completedView
            case .cancelled:
                EmptyView()
            }
        }
        .frame(width: 520, height: 600)
    }

    // MARK: - Proposal View

    private var proposalView: some View {
        VStack(spacing: 0) {

            // Header app
            appHeader
                .padding(.top, 40)
                .padding(.bottom, 24)

            Divider()
                .padding(.horizontal, 24)

            // Lista residui
            ResidualListView(residuals: $session.residuals)
                .padding(.horizontal, 24)
                .padding(.top, 16)

            Divider()
                .padding(.horizontal, 24)
                .padding(.top, 16)

            // Footer con dimensione totale e bottoni
            footerView
                .padding(24)
        }
    }

    // MARK: - App Header

    private var appHeader: some View {
        VStack(spacing: 12) {
            // Icona app
            Group {
                if let icon = session.app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 64, height: 64)
                } else {
                    Image(systemName: "app.dashed")
                        .resizable()
                        .frame(width: 64, height: 64)
                        .foregroundStyle(.secondary)
                }
            }
            .shadow(radius: 4)

            // Titolo
            Text("Residui trovati per \(session.app.displayName)")
                .font(.title2)
                .fontWeight(.semibold)

            // Sottotitolo
            Text("\(session.residuals.count) elementi · \(session.displayTotalSize)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // BundleID se disponibile
            if let bid = session.app.bundleID {
                Text(bid)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            // Dimensione totale selezionata
            VStack(alignment: .leading, spacing: 2) {
                Text("Spazio liberabile")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(session.displayTotalSize)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }

            Spacer()

            // Bottoni
            HStack(spacing: 12) {
                Button("Ignora") {
                    onAction(.cancel)
                }
                .keyboardShortcut(.escape)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button {
                    onAction(.clean)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                        Text("Pulisci ora")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .keyboardShortcut(.return)
            }
        }
    }

    // MARK: - Completed View

    private var completedView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icona risultato
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .frame(width: 48, height: 48)
                    .foregroundStyle(.green)
            }

            // Testo risultato
            VStack(spacing: 8) {
                Text("Pulizia completata")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("\(session.successCount) elementi rimossi")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if session.failedCount > 0 {
                    Text("\(session.failedCount) elementi non rimovibili")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if session.skippedCount > 0 {
                    Text("\(session.skippedCount) elementi ignorati")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Riepilogo elementi nel Trash
            Text("Gli elementi sono stati spostati nel Cestino.\nPuoi recuperarli se necessario.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Spacer()

            // Bottone chiudi
            Button("Chiudi") {
                onAction(.close)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
            .keyboardShortcut(.return)
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 40)
    }
}
