import SwiftUI

/// Gemeinsam genutzte kleine View-Bausteine, die in mehreren Screens vorkommen.

// MARK: - Toast

/// Zustand einer Toast-Meldung; `id` erzwingt einen frischen Auto-Dismiss-Timer
/// auch bei identischem Text.
struct AppToast: Equatable {
    enum Style { case neutral, success, error }
    let message: String
    var style: Style = .neutral
    private let id = UUID()
}

/// Kurze Status-Meldung unten am Bildschirm.
/// Präsentation + Auto-Dismiss übernimmt der `.appToast(_:)`-Modifier.
struct ToastView: View {
    let message: String
    var style: AppToast.Style = .neutral

    var body: some View {
        HStack(spacing: 8) {
            switch style {
            case .success:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(AppColor.green)
            case .error:
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(AppColor.red)
            case .neutral:
                EmptyView()
            }
            Text(message)
                .foregroundStyle(AppColor.text)
        }
        .font(.footnote.weight(.medium))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppColor.surface2)
        .clipShape(Capsule())
    }
}

extension View {
    /// Einheitliche Toast-Präsentation: Overlay unten, Auto-Dismiss nach 3 s.
    /// Pro Toast ein eigener, automatisch gecancelter Timer (`.task(id:)`).
    func appToast(_ toast: Binding<AppToast?>, bottomPadding: CGFloat = AppSpacing.toastBottom) -> some View {
        overlay(alignment: .bottom) {
            if let t = toast.wrappedValue {
                ToastView(message: t.message, style: t.style)
                    .padding(.bottom, bottomPadding)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: t) {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        withAnimation { toast.wrappedValue = nil }
                    }
            }
        }
    }
}

// MARK: - Button-Styles

/// Primär-CTA: volle Breite, 50 pt Höhe, Dynamic-Type-fähig.
/// Erdton-Orange als Default — die CTA-Farbe ist exklusiv für die
/// EINE dominante Aktion pro Screen reserviert (Marken-Palette).
struct PrimaryButtonStyle: ButtonStyle {
    var fill: Color = AppColor.cta

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(AppColor.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(fill.opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
    }
}

/// Sekundär-Aktion als Outline (Empty-/Error-States, "Erneut versuchen").
struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(AppColor.primary.opacity(configuration.isPressed ? 0.6 : 1))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.control)
                    .stroke(AppColor.primary, lineWidth: 1)
            )
    }
}

// MARK: - Zustands-Views (Gute-Form-Kanon: schlichtes Icon, EINE Muted-Zeile)

/// Leerzustand — kein Container, keine Überschrift, keine Statusfarbe.
struct EmptyStateView: View {
    let icon: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(AppColor.muted)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppColor.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(OutlineButtonStyle())
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

/// Fehler-Anzeige mit Retry — Pendant zu `widgets/error_view.dart`.
struct ErrorStateView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(AppColor.muted)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppColor.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Erneut versuchen", action: onRetry)
                .buttonStyle(OutlineButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Einfache Ladeanimation — Pendant zu `widgets/loading_indicator.dart`.
struct LoadingView: View {
    var message: String = "Laden…"
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(AppColor.primary)
                .scaleEffect(1.3)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppColor.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Inline-Fehlerbanner innerhalb eines Screens (nicht blockierend).
struct InlineErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(AppColor.red)
            Text(message)
                .font(.footnote)
                .foregroundStyle(AppColor.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(AppColor.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.control)
                .stroke(AppColor.red.opacity(0.3), lineWidth: 1)
        )
    }
}

/// Overline-Sektionsheader für Listenabschnitte (Versalien, muted).
struct OverlineHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.caption.bold())
            .foregroundStyle(AppColor.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
    }
}

// MARK: - TokenImage

/// Lädt ein Bild per URLSession mit X-Auth-Token-Header.
/// Fallback: übergebenes `placeholder`-ViewBuilder.
struct TokenImage<Placeholder: View>: View {
    let urlString: String
    let token: String?
    let size: CGFloat
    let cornerRadius: CGFloat
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            } else {
                placeholder()
                    .frame(width: size, height: size)
            }
        }
        .task(id: urlString) { await load() }
    }

    private func load() async {
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        if let t = token, !t.isEmpty {
            request.setValue(t, forHTTPHeaderField: APIConfig.authHeader)
        }
        guard let (data, resp) = try? await URLSession.shared.data(for: request),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let img = UIImage(data: data) else { return }
        await MainActor.run { self.image = img }
    }
}

// MARK: - ExerciseBadge

/// 72×72 Übungsbild (mit Auth) oder nummerierter Fallback.
struct ExerciseBadge: View {
    let exerciseName: String?
    let exerciseIdMap: [String: Int]
    let color: Color
    let index: Int?
    let liked: Bool
    let disliked: Bool
    var size: CGFloat = 72
    var fallbackIcon: String = "dumbbell.fill"

    @Environment(AuthViewModel.self) private var auth

    private var accentColor: Color {
        liked ? AppColor.green : disliked ? AppColor.red : color
    }

    var body: some View {
        let r: CGFloat = 10
        if let name = exerciseName, let eid = exerciseIdMap[name] {
            let base = APIConfig.baseURL.absoluteString
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let url = "\(base)/api/exercise/\(eid)/icon.png"
            TokenImage(urlString: url, token: auth.token, size: size, cornerRadius: r) {
                fallback(r: r)
            }
        } else {
            fallback(r: r).frame(width: size, height: size)
        }
    }

    @ViewBuilder
    private func fallback(r: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: r)
            .fill(accentColor.opacity(0.18))
            .overlay(
                Group {
                    if let i = index {
                        Text("\(i + 1)")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(accentColor)
                    } else {
                        Image(systemName: fallbackIcon)
                            .font(.system(size: 20))
                            .foregroundStyle(accentColor)
                    }
                }
            )
    }
}
