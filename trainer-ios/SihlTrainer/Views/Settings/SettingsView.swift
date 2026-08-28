import SwiftUI

/// Pendant zu `screens/settings_screen.dart` — als Sheet hinter dem Avatar.
struct SettingsView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showLogoutConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.stack) {
                    if let trainer = auth.trainer {
                        trainerCard(trainer)
                    }
                    accountSection
                }
                .padding(.horizontal, AppSpacing.screen)
                .padding(.top, AppSpacing.stack)
                .padding(.bottom, AppSpacing.bottomInset)
            }
            .background(AppColor.background)
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
