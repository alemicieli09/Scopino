//
//  CleanupProgressView.swift
//  Scopino
//
//  Created by Alessandro Micieli on 04/05/2026.
//

import SwiftUI

struct CleanupProgressView: View {

    @ObservedObject var session: CleanupSession

    // Animazione pulsante
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icona animata
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.08))
                    .frame(width: 100, height: 100)
                    .scaleEffect(isPulsing ? 1.15 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                        value: isPulsing
                    )

                Circle()
                    .fill(Color.red.opacity(0.12))
                    .frame(width: 78, height: 78)

                Image(systemName: "trash.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .foregroundStyle(.red)
            }
            .onAppear { isPulsing = true }
            .padding(.bottom, 28)

            // Titolo
            Text("Pulizia in corso…")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.bottom, 6)

            // App name
            Text(session.app.displayName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)

            // Progress bar
            progressBar
                .padding(.horizontal, 40)
                .padding(.bottom, 12)

            // Contatore
            Text("\(session.progress.completed) di \(session.progress.total) elementi")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .padding(.bottom, 24)

            // File corrente
            currentFileLabel
                .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        let total = Double(session.progress.total)
        let completed = Double(session.progress.completed)
        let fraction = total > 0 ? completed / total : 0.0

        return VStack(spacing: 6) {
            // Track
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.separatorColor).opacity(0.3))
                        .frame(height: 8)

                    // Fill
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [.red.opacity(0.8), .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * fraction, height: 8)
                        .animation(.spring(response: 0.4), value: fraction)
                }
            }
            .frame(height: 8)

            // Percentuale
            HStack {
                Spacer()
                Text("\(Int(fraction * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Current file label

    private var currentFileLabel: some View {
        let completed = session.progress.completed

        // Trova l'item corrente dalla lista residui
        let currentItem: ResidualItem? = {
            let selected = session.residuals.filter { $0.isSelected }
            guard completed < selected.count else { return selected.last }
            return selected[completed]
        }()

        return Group {
            if let item = currentItem {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.7))

                    Text(item.path)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: completed)
            } else {
                Text("Finalizzazione…")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
