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
                    Text("Sihl Training")
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(AppColor.text)
                        .padding(.top, 24)
                    Text("Melde dich mit deinem Konto an")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.muted)
                        .padding(.top, 8)

                    InputField(text: $email, label: "E-Mail", systemIcon: "envelope")
                        .keyboardType(.emailAddress)
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
                    })
                    .padding(.top, 16)
                    .onSubmit(submit)

                    loginButton
                        .padding(.top, 28)

                    Button("Demo ansehen") {
                        auth.loginDemo()
                    }
                    .font(.footnote)
                    .foregroundStyle(AppColor.muted)
                    .padding(.top, 16)
                }
                .frame(maxWidth: 400)
                .padding(.horizontal, AppSpacing.screen)
                .frame(maxWidth: .infinity)
            }
        }
        .alert("Bitte E-Mail und Passwort eingeben", isPresented: $showEmptyHint) {
            Button("OK", role: .cancel) {}
        }
    }

    private var logo: some View {
        RoundedRectangle(cornerRadius: AppRadius.hero)
            .fill(AppColor.primary)
            .frame(width: 72, height: 72)
            .overlay(
                Text("ST")
                    .font(.app(28, weight: .black))
                    .foregroundStyle(AppColor.white)
                    .kerning(1)
            )
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
