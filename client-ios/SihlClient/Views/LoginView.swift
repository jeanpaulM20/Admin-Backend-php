import SwiftUI

/// Pendant zu Flutter `login_screen.dart`.
struct LoginView: View {
    @Environment(AuthViewModel.self) private var auth

    @State private var email = ""
    @State private var password = ""
    @State private var obscurePassword = true
    @State private var showEmptyHint = false

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    logo
                    // Wortmarke SIHLMOVE (Schrift und Laufweite des SIHLTRAINING-Logos)
                    Image("SihlmoveWordmark")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 26)
                        .padding(.top, 24)
                        .accessibilityLabel("SIHLMOVE")
                    // Anbieter wie im UID-Register
                    Text("Jean Paul Mvongo, Personal Training")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.brass)
                        .padding(.top, 8)
                    Text("Melde dich mit deinem Konto an")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.muted)
                        .padding(.top, 8)

                    InputField(text: $email, label: "E-Mail", systemIcon: "envelope")
                        .keyboardType(.emailAddress)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.top, 40)

                    InputField(text: $password, label: "Passwort", systemIcon: "lock",
                               secure: obscurePassword,
                               trailing: {
                        Button {
                            obscurePassword.toggle()
                        } label: {
                            Image(systemName: obscurePassword ? "eye.slash" : "eye")
                                .foregroundStyle(AppColor.muted)
                        }
                        .accessibilityLabel(obscurePassword ? "Passwort anzeigen" : "Passwort verbergen")
                    })
                    .textContentType(.password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.top, 16)
                    .onSubmit(submit)

                    if let message = auth.error {
                        InlineErrorBanner(message: message)
                            .padding(.top, 16)
                            .accessibilityAddTraits(.isStaticText)
                    }

                    loginButton
                        .padding(.top, 28)

                    Button("Demo ansehen") {
                        auth.loginDemo()
                    }
                    .font(.footnote)
                    .foregroundStyle(AppColor.muted)
                    .padding(.top, 16)

                    footer
                        .padding(.top, 40)
                        .padding(.bottom, 24)
                }
                .frame(maxWidth: 400)
                .padding(.horizontal, AppSpacing.screen)
                .frame(maxWidth: .infinity)
            }
        }
        .alert("Bitte E-Mail und Passwort eingeben", isPresented: $showEmptyHint) {
            Button("OK", role: .cancel) {}
        }
        // Fehlermeldung verschwindet, sobald neu getippt wird
        .onChange(of: email) { _, _ in clearErrorIfNeeded() }
        .onChange(of: password) { _, _ in clearErrorIfNeeded() }
    }

    /// Hinweis zum Konto + Datenschutz
    private var footer: some View {
        VStack(spacing: 10) {
            Text("Dein Konto erhältst du von Jean Paul Mvongo, Personal Training.")
                .font(.footnote)
                .foregroundStyle(AppColor.muted)
            if let mail = AppLinks.supportMail() {
                Link(AppLinks.supportEmail, destination: mail)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppColor.primary)
            }
            Link("Datenschutz", destination: AppLinks.privacy)
                .font(.footnote)
                .foregroundStyle(AppColor.muted)
                .underline()
                .padding(.top, 6)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private func clearErrorIfNeeded() {
        if auth.error != nil { auth.clearError() }
    }

    /// App-Marke: das S des App-Icons (Times New Roman auf Olive) — 1:1
    /// dieselbe Grafik wie das Icon, nur mit abgerundeten Ecken.
    private var logo: some View {
        Image("SihlmoveMark")
            .resizable()
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.hero))
            .accessibilityHidden(true)
    }

    private var loginButton: some View {
        Button(action: submit) {
            if auth.isLoading {
                ProgressView().tint(AppColor.white)
            } else {
                Text("Anmelden")
            }
        }
        .buttonStyle(PrimaryButtonStyle(fill: AppColor.cta.opacity(auth.isLoading ? 0.5 : 1)))
        .disabled(auth.isLoading)
    }

    private func submit() {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !password.isEmpty else {
            showEmptyHint = true
            return
        }
        Task { await auth.login(email: trimmed, password: password) }
    }
}

/// Pendant zum privaten `_InputField` in Flutter.
private struct InputField<Trailing: View>: View {
    @Binding var text: String
    let label: String
    let systemIcon: String
    var secure: Bool = false
    @ViewBuilder var trailing: () -> Trailing

    init(text: Binding<String>, label: String, systemIcon: String,
         secure: Bool = false,
         @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self._text = text
        self.label = label
        self.systemIcon = systemIcon
        self.secure = secure
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemIcon)
                .foregroundStyle(AppColor.muted)
                .frame(width: 20)
            Group {
                if secure {
                    SecureField(label, text: $text)
                } else {
                    TextField(label, text: $text)
                }
            }
            .foregroundStyle(AppColor.text)
            trailing()
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColor.border, lineWidth: 1)
        )
    }
}

#Preview {
    LoginView()
        .environment(AuthViewModel())
}
