//
//  PermissionRequestView.swift
//  Scopino
//
//  Created by Alessandro Micieli on 04/05/2026.
//

import SwiftUI

struct PermissionRequestView: View {

    let onDismiss: () -> Void

    @State private var accessGranted = false
    @State private var isChecking = false
    @State private var checkTimer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icona
            iconView
                .padding(.bottom, 28)

            // Titolo e descrizione
            textBlock
                .padding(.horizontal, 40)
                .padding(.bottom, 32)

            // Steps
            stepsBlock
                .padding(.horizontal, 32)
                .padding(.bottom, 36)

            // Bottone azione
            actionButton
                .padding(.horizontal, 40)
                .padding(.bottom, 16)

            // Link impostazioni
            settingsLink
                .padding(.bottom, 8)

            Spacer()
        }
        .frame(width: 520, height: 600)
        .onAppear { startPolling() }
        .onDisappear { stopPolling() }
    }

    // MARK: - Icon

    private var iconView: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.red.opacity(0.15), Color.orange.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 96, height: 96)

            Image(systemName: accessGranted ? "checkmark.shield.fill" : "lock.shield")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .foregroundStyle(accessGranted ? .green : .red)
                .animation(.spring(response: 0.4), value: accessGranted)
        }
    }

    // MARK: - Text block

    private var textBlock: some View {
        VStack(spacing: 10) {
            Text(accessGranted ? "Accesso concesso" : "Accesso al disco richiesto")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .animation(.easeInOut, value: accessGranted)

            Text(accessGranted
                 ? "Scopino può ora trovare e rimuovere tutti i residui delle app disinstallate."
                 : "Per trovare tutti i residui delle app, Scopino ha bisogno del permesso di accesso completo al disco.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .animation(.easeInOut, value: accessGranted)
        }
    }

    // MARK: - Steps

    private var stepsBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepRow(
                number: "1",
                icon: "apple.logo",
                title: "Apri Impostazioni di Sistema",
                description: "Menu Apple → Impostazioni di Sistema"
            )
            stepRow(
                number: "2",
                icon: "lock.shield",
                title: "Privacy e Sicurezza",
                description: "Seleziona \"Accesso completo al disco\" nel pannello"
            )
            stepRow(
                number: "3",
                icon: "plus.circle",
                title: "Aggiungi Scopino",
                description: "Clicca + e seleziona Scopino dalla cartella Applicazioni"
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
        )
    }

    private func stepRow(
        number: String,
        icon: String,
        title: String,
        description: String
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Numero step
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.12))
                    .frame(width: 28, height: 28)
                Text(number)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.red)
            }

            // Testo
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Action button

    private var actionButton: some View {
        Group {
            if accessGranted {
                Button {
                    stopPolling()
                    onDismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                        Text("Inizia a usare Scopino")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .keyboardShortcut(.return)
            } else {
                Button {
                    openPrivacySettings()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "gear")
                        Text("Apri Impostazioni di Sistema")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
    }

    // MARK: - Settings link

    private var settingsLink: some View {
        Group {
            if isChecking && !accessGranted {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Verifica accesso in corso…")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            } else if !accessGranted {
                Text("Scopino verificherà automaticamente quando il permesso viene concesso.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Polling

    /// Controlla ogni 2 secondi se il permesso è stato concesso.
    private func startPolling() {
        isChecking = true
        checkTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            let granted = PermissionChecker.hasFDAPermission()
            withAnimation {
                accessGranted = granted
            }
            if granted {
                stopPolling()
            }
        }
    }

    private func stopPolling() {
        isChecking = false
        checkTimer?.invalidate()
        checkTimer = nil
    }

    // MARK: - Open settings

    private func openPrivacySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }
}
