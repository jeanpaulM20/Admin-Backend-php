import SwiftUI

/// Pendant zu `screens/login_screen.dart`: ein Passcode-Feld, ein Knopf.
struct LoginView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var passcode = ""
    @State private var isRevealed = false
    @FocusState private var focused: Bool

    var body: some View {
        // GeometryReader + minHeight zentriert den Block vertikal, lässt ihn
        // bei eingeblendeter Tastatur aber weiterhin scrollen.
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: AppSpacing.stack) {
                    Spacer(minLength: 24)

                    BrandMark()

                    Text("SIHL TRAINING")
                        .font(.app(22, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(AppColor.text)

                    Text("Trainer App")
                        .font(.app(14))
                        .foregroundStyle(AppColor.muted)

                    passcodeField
                        .padding(.top, 24)

                    if let error = auth.error {
                        Text(error)
                            .font(.app(13))
                            .foregroundStyle(AppColor.red)
                            .multilineTextAlignment(.center)
                    }

                    submitButton

                    #if DEBUG
                    Button("Vorschau ohne Anmeldung") {
                        auth.startPreview()
                    }
                    .font(.app(13))
                    .foregroundStyle(AppColor.muted)
                    .padding(.top, 4)
                    #endif

                    Text("© \(String(Calendar.current.component(.year, from: Date()))) Sihl Training")
                        .font(.app(12))
                        .foregroundStyle(AppColor.muted)
                        .padding(.top, 8)

                    Spacer(minLength: 24)
                }
                .frame(maxWidth: 420)
                .padding(.horizontal, AppSpacing.screen)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(AppColor.background)
    }

    private var passcodeField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Passcode")
                .font(.app(13))
                .foregroundStyle(AppColor.muted)
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(AppColor.muted)
                Group {
                    if isRevealed {
                        TextField("", text: $passcode)
                    } else {
                        SecureField("", text: $passcode)
                    }
                }
                .textContentType(.password)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .foregroundStyle(AppColor.text)
                .focused($focused)
                .onSubmit(submit)
                .submitLabel(.go)

                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .foregroundStyle(AppColor.muted)
                }
                .accessibilityLabel(isRevealed ? "Passcode verbergen" : "Passcode anzeigen")
            }
            .font(.app(16))
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.control)
                    .stroke(AppColor.border, lineWidth: 1)
            )
        }
    }

    /// Der eine dominante CTA dieses Screens — darum Marken-Olive als Fläche.
    private var submitButton: some View {
        Button(action: submit) {
            HStack {
                if auth.isLoading {
                    ProgressView().tint(AppColor.white)
                } else {
                    Text("Anmelden").font(.app(16, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppColor.cta)
            .foregroundStyle(AppColor.white)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
        }
        .disabled(auth.isLoading)
    }

    private func submit() {
        focused = false
        Task { await auth.login(passcode: passcode) }
    }
}
