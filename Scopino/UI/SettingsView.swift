//
//  SettingsView.swift
//  Scopino
//
//  Created by Alessandro Micieli on 04/05/2026.
//

import SwiftUI
import ServiceManagement

struct SettingsView: View {

    @State private var hasFullDiskAccess = PermissionChecker.hasFDAPermission()
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var notificationsEnabled = false
    @State private var checkTimer: Timer?

    var body: some View {
        VStack(spacing: 0) {

            header
                .padding(.top, 28)
                .padding(.horizontal, 28)
                .padding(.bottom, 20)

            Divider()
                .padding(.horizontal, 20)

            ScrollView {
                VStack(spacing: 12) {
                    launchAtLoginSection
                    notificationsSection
                    fdaSection
                    aboutSection
                }
                .padding(20)
            }
        }
        .frame(width: 480, height: 500)
        .onAppear { startPolling() }
        .onDisappear { stopPolling() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "trash.slash.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.red)

            VStack(alignment: .leading, spacing: 3) {
                Text("Scopino")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Pulizia automatica residui app")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Launch at Login

    private var launchAtLoginSection: some View {
        VStack(alignment: .leading, spacing: 0) {

            Text("AVVIO")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.bottom, 6)

            HStack(spacing: 14) {

                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "power")
                        .font(.system(size: 20))
                        .foregroundStyle(.blue)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Avvia al login")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Scopino si avvia automaticamente all'accesso.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Toggle("", isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .onChange(of: launchAtLogin) { _, newValue in
                        toggleLaunchAtLogin(newValue)
                    }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
            )
        }
    }

    private func toggleLaunchAtLogin(_ enable: Bool) {
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("[LaunchAtLogin] Errore: \(error)")
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 0) {

            Text("NOTIFICHE")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.bottom, 6)

            HStack(spacing: 14) {

                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "bell.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Notifiche")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(notificationsEnabled
                         ? "Attive — ricevi avvisi quando vengono trovati residui."
                         : "Disattivate — abilita per ricevere avvisi.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if notificationsEnabled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                } else {
                    Button("Abilita") {
                        Task { await NotificationService.shared.requestAuthorization() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.small)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
            )
        }
        .task {
            notificationsEnabled = await NotificationService.shared.isAuthorized()
        }
    }

    // MARK: - FDA Section

    private var fdaSection: some View {
        VStack(alignment: .leading, spacing: 0) {

            Text("PERMESSI")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.bottom, 6)

            HStack(spacing: 14) {

                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(hasFullDiskAccess ? Color.green.opacity(0.12) : Color.red.opacity(0.10))
                        .frame(width: 44, height: 44)

                    Image(systemName: hasFullDiskAccess ? "checkmark.shield.fill" : "lock.shield.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(hasFullDiskAccess ? .green : .red)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Accesso completo al disco")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(hasFullDiskAccess
                         ? "Concesso — Scopino può trovare tutti i residui."
                         : "Non concesso — alcuni residui potrebbero non essere rilevati.")
                        .font(.caption)
                        .foregroundStyle(hasFullDiskAccess ? Color.secondary : Color.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if hasFullDiskAccess {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                } else {
                    Button("Concedi") {
                        PermissionChecker.openFDASettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.small)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
            )
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 0) {

            Text("INFORMAZIONI")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.bottom, 6)

            VStack(spacing: 0) {
                infoRow(label: "Versione", value: appVersion)
                Divider().padding(.leading, 14)
                infoRow(label: "Monitoraggio", value: "/Applications")
                Divider().padding(.leading, 14)
                infoRow(label: "Sessioni salvate", value: "\(SessionStore.shared.completedCount)")
                Divider().padding(.leading, 14)
                infoRow(label: "Spazio totale liberato", value: SessionStore.shared.totalFreedDisplay)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
            )
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Polling FDA

    private func startPolling() {
        checkTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            let granted = PermissionChecker.hasFDAPermission()
            withAnimation(.easeInOut(duration: 0.3)) {
                hasFullDiskAccess = granted
            }
            // Notifiche — aggiorna su MainActor esplicitamente
            Task { @MainActor in
                notificationsEnabled = await NotificationService.shared.isAuthorized()
            }
        }
    }

    private func stopPolling() {
        checkTimer?.invalidate()
        checkTimer = nil
    }

    // MARK: - App version

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
