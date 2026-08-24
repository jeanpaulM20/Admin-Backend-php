import SwiftUI

// MARK: - GlucoseView
// Pendant zu `screens/glucose_screen.dart`.
// Tab 5 — FreeStyle Libre CGM-Daten (Blutzucker-Verlauf).

struct GlucoseView: View {
    @Environment(LibreViewModel.self) private var libre

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()

            if !libre.isLoggedIn {
                LibreLoginView()
            } else {
                glucoseContent
            }
        }
    }

    // MARK: - Hauptinhalt (eingeloggt)

    private var glucoseContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Fehler-Banner
                if let err = libre.error {
                    InlineErrorBanner(message: err)
                }

                // Aktuelle Messung
                if let reading = libre.latestReading {
                    CurrentValueCard(reading: reading)
                } else if libre.isLoading {
                    ProgressView()
                        .tint(AppColor.primary)
                        .padding(.top, 40)
                } else {
                    EmptyStateView(
                        icon:    "waveform.path.ecg",
                        message: "Keine Messung verfügbar. Sensor prüfen oder manuell aktualisieren."
                    )
                }

                // Sync-Info
                if let sync = libre.lastSync {
                    SyncInfoRow(lastSync: sync, fromCache: libre.fromCache)
                }

                // Verlauf
                if !libre.readings.isEmpty {
                    ReadingsHistoryCard(readings: libre.readings)
                }

                // Abmelden
                logoutButton
                    .padding(.top, 8)
            }
            .padding(AppSpacing.screen)
            .padding(.bottom, AppSpacing.bottomInset)
        }
        .refreshable {
            await libre.loadReadings(forceRefresh: true)
        }
        .task {
            if libre.readings.isEmpty {
                await libre.loadReadings()
            }
        }
    }

    // MARK: - Logout

    private var logoutButton: some View {
        Button {
            Task { await libre.logout() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("LibreView trennen")
                    .font(.app(14, weight: .semibold))
            }
            .foregroundStyle(AppColor.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.control)
                    .stroke(AppColor.red.opacity(0.4), lineWidth: 1)
            )
        }
    }
}

// MARK: - CurrentValueCard

private struct CurrentValueCard: View {
    let reading: GlucoseReading

    private var valueColor: Color {
        if reading.isHigh { return AppColor.orange }
        if reading.isLow  { return AppColor.red }
        return AppColor.green
    }

    private var statusLabel: String {
        if reading.isHigh { return "Zu hoch" }
        if reading.isLow  { return "Zu tief" }
        return "Im Bereich"
    }

    var body: some View {
        VStack(spacing: 6) {
            // Großer Zahlenwert
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "%.1f", reading.valueMmol))
                    .font(.app(64, weight: .heavy, design: .rounded))
                    .foregroundStyle(valueColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("mmol/L")
                        .font(.app(18, weight: .semibold))
                        .foregroundStyle(AppColor.muted)
                    Text(reading.trendIcon)
                        .font(.app(28))
                        .foregroundStyle(valueColor)
                }
            }

            // mg/dL Zusatz
            Text("\(reading.valueMgDl) mg/dL")
                .font(.app(14))
                .foregroundStyle(AppColor.muted)

            // Status-Chip
            Text(statusLabel)
                .font(.app(12, weight: .semibold))
                .foregroundStyle(valueColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(valueColor.opacity(0.15))
                .clipShape(Capsule())
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.hero)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.hero))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.hero).stroke(AppColor.border, lineWidth: 1))
    }
}

// MARK: - SyncInfoRow

private struct SyncInfoRow: View {
    let lastSync: Date
    let fromCache: Bool

    private var label: String {
        let diff = Int(Date().timeIntervalSince(lastSync) / 60)
        return diff < 1 ? "Gerade synchronisiert" : "Vor \(diff) Min. synchronisiert"
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: fromCache ? "arrow.clockwise.circle" : "checkmark.circle")
                .font(.app(12))
                .foregroundStyle(AppColor.muted)
            Text(label)
                .font(.app(11))
                .foregroundStyle(AppColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - ReadingsHistoryCard

private struct ReadingsHistoryCard: View {
    let readings: [GlucoseReading]

    private var recent: [GlucoseReading] {
        Array(readings.reversed().prefix(20))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Verlauf (letzte \(recent.count) Messungen)")
                .font(.app(12, weight: .semibold))
                .foregroundStyle(AppColor.muted)

            VStack(spacing: 0) {
                ForEach(Array(recent.enumerated()), id: \.element.id) { idx, reading in
                    ReadingRow(reading: reading)
                    if idx < recent.count - 1 {
                        Divider()
                            .background(AppColor.border)
                            .padding(.leading, 4)
                    }
                }
            }
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.border, lineWidth: 1))
        }
    }
}

// MARK: - ReadingRow

private struct ReadingRow: View {
    let reading: GlucoseReading

    private var valueColor: Color {
        if reading.isHigh { return AppColor.orange }
        if reading.isLow  { return AppColor.red }
        return AppColor.text
    }

    private var timeLabel: String {
        let cal = Calendar.current
        let h = cal.component(.hour,   from: reading.timestamp)
        let m = cal.component(.minute, from: reading.timestamp)
        return String(format: "%02d:%02d", h, m)
    }

    var body: some View {
        HStack {
            Text(timeLabel)
                .font(.app(13, design: .monospaced))
                .foregroundStyle(AppColor.muted)
                .frame(width: 48, alignment: .leading)

            Text(reading.displayValue)
                .font(.app(15, weight: .semibold))
                .foregroundStyle(valueColor)

            Text(reading.trendIcon)
                .font(.app(14))
                .foregroundStyle(AppColor.muted)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - LibreLoginView

/// Wird angezeigt, solange `libre.isLoggedIn == false`.
/// Pendant zu `_LoginView` in `glucose_screen.dart`.
struct LibreLoginView: View {
    @Environment(LibreViewModel.self) private var libre

    @State private var email    = ""
    @State private var password = ""
    @State private var region   = LibreRegion.eu
    @State private var showError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 60)

                // Header
                VStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg.rectangle.fill")
                        .font(.app(48))
                        .foregroundStyle(AppColor.primary)
                    Text("FreeStyle Libre Login")
                        .font(.title2.bold())
                        .foregroundStyle(AppColor.text)
                    Text("LibreView-Zugangsdaten eingeben")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.muted)
                }
                .padding(.bottom, 36)

                // Form
                VStack(spacing: 14) {
                    // E-Mail
                    LibreField(
                        value:       $email,
                        label:       "E-Mail",
                        icon:        "envelope",
                        keyboardType: .emailAddress
                    )

                    // Passwort
                    LibreSecureField(value: $password, label: "Passwort")

                    // Region
                    HStack(spacing: 12) {
                        Image(systemName: "globe")
                            .font(.app(16))
                            .foregroundStyle(AppColor.muted)
                            .frame(width: 20)
                        Picker("Region", selection: $region) {
                            ForEach(LibreRegion.allCases, id: \.self) { r in
                                Text(r.displayName).tag(r)
                            }
                        }
                        .tint(AppColor.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, AppSpacing.card)
                    .padding(.vertical, 14)
                    .background(AppColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.border, lineWidth: 1))

                    // Fehler
                    if let err = showError ?? libre.error {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(AppColor.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }

                    // Login-Button
                    Button {
                        Task { await doLogin() }
                    } label: {
                        if libre.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Verbinden")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(libre.isLoading || email.isEmpty || password.isEmpty)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 40)
            }
        }
        .background(AppColor.background)
        .scrollBounceBehavior(.basedOnSize)
    }

    private func doLogin() async {
        showError = nil
        let ok = await libre.login(email: email, password: password, region: region)
        if !ok {
            showError = libre.error ?? "Login fehlgeschlagen"
        }
    }
}

// MARK: - LibreField / LibreSecureField

private struct LibreField: View {
    @Binding var value: String
    let label: String
    let icon:  String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.app(16))
                .foregroundStyle(AppColor.muted)
                .frame(width: 20)
            TextField(label, text: $value)
                .keyboardType(keyboardType)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .foregroundStyle(AppColor.text)
        }
        .padding(.horizontal, AppSpacing.card)
        .padding(.vertical, 14)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.border, lineWidth: 1))
    }
}

private struct LibreSecureField: View {
    @Binding var value: String
    let label: String
    @State private var visible = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock")
                .font(.app(16))
                .foregroundStyle(AppColor.muted)
                .frame(width: 20)
            if visible {
                TextField(label, text: $value)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .foregroundStyle(AppColor.text)
            } else {
                SecureField(label, text: $value)
                    .foregroundStyle(AppColor.text)
            }
            Button {
                visible.toggle()
            } label: {
                Image(systemName: visible ? "eye.slash" : "eye")
                    .font(.app(14))
                    .foregroundStyle(AppColor.muted)
            }
        }
        .padding(.horizontal, AppSpacing.card)
        .padding(.vertical, 14)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.border, lineWidth: 1))
    }
}
