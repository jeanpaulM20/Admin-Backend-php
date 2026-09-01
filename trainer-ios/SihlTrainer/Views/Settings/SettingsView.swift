import SwiftUI

/// Pendant zu `screens/settings_screen.dart` — als Sheet hinter dem Avatar.
struct SettingsView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showLogoutConfirm = false
    @State private var showSerialSheet = false
    @State private var showSingleSlotSheet = false
    @State private var slotToast: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.stack) {
                    if let trainer = auth.trainer {
                        trainerCard(trainer)
                    }
                    availabilitySection
                    qrSection
                    #if DEBUG
                    diagnosticsSection
                    #endif
                    accountSection
                }
                .padding(.horizontal, AppSpacing.screen)
                .padding(.top, AppSpacing.stack)
                .padding(.bottom, AppSpacing.bottomInset)
            }
            .background(AppColor.background)
            .sheet(isPresented: $showSerialSheet) {
                if let trainer = auth.trainer {
                    AvailabilitySerialSheet(trainerId: trainer.id, isPreview: auth.previewFlag) {
                        slotToast = "Serie angelegt"
                    }
                }
            }
            .sheet(isPresented: $showSingleSlotSheet) {
                if let trainer = auth.trainer {
                    SingleSlotSheet(trainerId: trainer.id, isPreview: auth.previewFlag) {
                        slotToast = "Zeitfenster hinzugefügt"
                    }
                }
            }
            .alert("Gespeichert", isPresented: Binding(
                get: { slotToast != nil }, set: { if !$0 { slotToast = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(slotToast ?? "")
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                        .foregroundStyle(AppColor.primary)
                }
            }
        }
    }

    private func trainerCard(_ trainer: Trainer) -> some View {
        Card(padding: AppSpacing.hero) {
            HStack(spacing: 14) {
                Avatar(initials: trainer.initials, photo: trainer.photo, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(trainer.name)
                        .font(.app(18, weight: .bold))
                        .foregroundStyle(AppColor.text)
                    if let email = trainer.email {
                        Text(email)
                            .font(.app(13))
                            .foregroundStyle(AppColor.muted)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    /// Verfügbarkeit — war bisher nur im Kalender erreichbar.
    @ViewBuilder private var availabilitySection: some View {
        if auth.trainer != nil {
            VStack(spacing: AppSpacing.stack) {
                availabilityRow(icon: "calendar.badge.clock",
                                title: "Wiederkehrende Zeiten",
                                subtitle: "Wochentage und Zeitraum als Serie") {
                    showSerialSheet = true
                }
                availabilityRow(icon: "clock.badge.plus",
                                title: "Einzelnes Zeitfenster",
                                subtitle: "Zusatztermin an einem bestimmten Tag") {
                    showSingleSlotSheet = true
                }
                calendarRow
            }
        }
    }

    /// Kalender-Zusammenführung (Phase 1): Outlook der Klinik sperrt die Website.
    @ViewBuilder private var calendarRow: some View {
        if let trainer = auth.trainer {
            NavigationLink {
                CalendarSyncView(trainerId: trainer.id)
            } label: {
                Card {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.app(15))
                            .foregroundStyle(AppColor.primary)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Kalender verbinden")
                                .font(.app(15, weight: .semibold))
                                .foregroundStyle(AppColor.text)
                            Text("Outlook und Google gegen Doppelbuchung")
                                .font(.app(12))
                                .foregroundStyle(AppColor.muted)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.app(13))
                            .foregroundStyle(AppColor.muted)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func availabilityRow(icon: String, title: String, subtitle: String,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Card {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.app(15))
                        .foregroundStyle(AppColor.primary)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.app(15, weight: .semibold))
                            .foregroundStyle(AppColor.text)
                        Text(subtitle)
                            .font(.app(12))
                            .foregroundStyle(AppColor.muted)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.app(13))
                        .foregroundStyle(AppColor.muted)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var qrSection: some View {
        if let trainer = auth.trainer {
            NavigationLink {
                QRCodeView(trainerId: trainer.id, isPreview: auth.previewFlag)
            } label: {
                Card {
                    HStack(spacing: 12) {
                        Image(systemName: "qrcode")
                            .font(.app(15))
                            .foregroundStyle(AppColor.primary)
                            .frame(width: 22)
                        Text("Mein QR-Code")
                            .font(.app(15, weight: .semibold))
                            .foregroundStyle(AppColor.text)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.app(13))
                            .foregroundStyle(AppColor.muted)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    #if DEBUG
    /// Nur in Debug-Builds: zeigt, was die Endpunkte tatsächlich antworten.
    @ViewBuilder private var diagnosticsSection: some View {
        if let trainer = auth.trainer {
            NavigationLink {
                DiagnosticsView(trainerId: trainer.id)
            } label: {
                Card {
                    HStack(spacing: 12) {
                        Image(systemName: "stethoscope")
                            .font(.app(15))
                            .foregroundStyle(AppColor.orange)
                            .frame(width: 22)
                        Text("Verbindungstest")
                            .font(.app(15, weight: .semibold))
                            .foregroundStyle(AppColor.text)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.app(13))
                            .foregroundStyle(AppColor.muted)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
    #endif

    private var accountSection: some View {
        Card(padding: 0) {
            VStack(spacing: 0) {
                // Passwort ändern und Präferenzen kommen mit der Portierung
                // der übrigen Einstellungen.
                Button {
                    showLogoutConfirm = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(AppColor.red)
                            .frame(width: 22)
                        Text("Abmelden")
                            .font(.app(15))
                            .foregroundStyle(AppColor.red)
                        Spacer(minLength: 0)
                    }
                    .padding(AppSpacing.card)
                }
            }
        }
        .confirmationDialog("Abmelden?", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button("Abmelden", role: .destructive) {
                Task {
                    await auth.logout()
                    dismiss()
                }
            }
            Button("Abbrechen", role: .cancel) {}
        }
    }
}
