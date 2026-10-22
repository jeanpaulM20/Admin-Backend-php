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
    /// true, wenn die Aktion DIE Hauptaktion des Screens ist (Ein-CTA-Prinzip) —
    /// dann trägt sie CTA-Orange statt des sekundären Outline-Stils.
    var prominentAction: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.app(32))
                .foregroundStyle(AppColor.muted)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppColor.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(prominentAction
                        ? AnyButtonStyle(PrimaryButtonStyle())
                        : AnyButtonStyle(OutlineButtonStyle()))
                    .padding(.top, 8)
                    .padding(.horizontal, prominentAction ? 32 : 0)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

/// Typ-Radierer, damit Button-Stile bedingt wählbar sind.
struct AnyButtonStyle: ButtonStyle {
    private let _makeBody: (Configuration) -> AnyView
    init<S: ButtonStyle>(_ style: S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

/// Fehler-Anzeige mit Retry — Pendant zu `widgets/error_view.dart`.
struct ErrorStateView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.app(40))
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

/// Lädt ein Bild per URLSession mit X-Auth-Token-Header und hält es im
/// gemeinsamen Speicher (`TokenImageStore`), damit Kachel, Vorschau und
/// Vollbild dasselbe Bild nutzen statt es dreimal zu laden.
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
        .task(id: urlString) {
            image = await TokenImageStore.shared.image(for: urlString, token: token)
        }
    }
}

/// Bild-Speicher für Token-geschützte Bilder: ein Download je URL,
/// danach aus dem Speicher (NSCache räumt bei Speicherdruck selbst auf).
actor TokenImageStore {
    static let shared = TokenImageStore()

    private let cache = NSCache<NSString, UIImage>()
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    func cached(_ urlString: String) -> UIImage? {
        cache.object(forKey: urlString as NSString)
    }

    func image(for urlString: String, token: String?) async -> UIImage? {
        if let hit = cache.object(forKey: urlString as NSString) { return hit }
        if let running = inFlight[urlString] { return await running.value }
        let task = Task<UIImage?, Never> {
            guard let url = URL(string: urlString) else { return nil }
            var request = URLRequest(url: url)
            if let t = token, !t.isEmpty {
                request.setValue(t, forHTTPHeaderField: APIConfig.authHeader)
            }
            guard let (data, resp) = try? await URLSession.shared.data(for: request),
                  let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  let img = UIImage(data: data) else { return nil }
            return img
        }
        inFlight[urlString] = task
        let result = await task.value
        inFlight[urlString] = nil
        if let result { cache.setObject(result, forKey: urlString as NSString) }
        return result
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

    /// Bild-URL einer Übung — das Backend liefert unter icon.png das Bild in
    /// voller Grösse (1024 px bei KI-Bildern), also dieselbe Quelle für
    /// Kachel, Vorschau und Vollbild.
    static func imageURL(exerciseId: Int) -> String {
        let base = APIConfig.baseURL.absoluteString
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return "\(base)/api/exercise/\(exerciseId)/icon.png"
    }

    var body: some View {
        let r: CGFloat = 10
        if let name = exerciseName, let eid = exerciseIdMap[name] {
            TokenImage(urlString: Self.imageURL(exerciseId: eid), token: auth.token,
                       size: size, cornerRadius: r) {
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
                            .font(.app(13, weight: .heavy))
                            .foregroundStyle(accentColor)
                    } else {
                        Image(systemName: fallbackIcon)
                            .font(.app(20))
                            .foregroundStyle(accentColor)
                    }
                }
            )
    }
}


// MARK: - DemoUnavailableView

/// Ehrlicher Demo-Zustand: Dieser Bereich zeigt persönliche Daten und ist
/// darum erst mit echtem Konto verfügbar — statt eines Server-Fehlers.
struct DemoUnavailableView: View {
    let message: String

    var body: some View {
        VStack(spacing: AppSpacing.stack) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.app(40))
                .foregroundStyle(AppColor.muted)
            Text("Im Demo-Modus nicht verfügbar")
                .font(.headline)
                .foregroundStyle(AppColor.text)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppColor.muted)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, AppSpacing.screen * 2)
    }
}

// MARK: - NavRow

/// Einheitliche Navigations-Zeile (Icon-Kachel, Titel, Untertitel,
/// Chevron) — eine Definition statt Kopien je Screen.
struct NavRow<Destination: View>: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: AppRadius.control)
                    .fill(tint.opacity(0.14))
                    .frame(width: 36, height: 36)
                    .overlay(Image(systemName: icon)
                        .font(.app(16))
                        .foregroundStyle(tint))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.app(15, weight: .bold))
                        .foregroundStyle(AppColor.text)
                    Text(subtitle)
                        .font(.app(12))
                        .foregroundStyle(AppColor.muted)
                }
                // NavigationLink-Labels zentrieren mehrzeiligen Text — bei
                // grosser Schrift bricht der Untertitel um und stand dann mittig
                .multilineTextAlignment(.leading)

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.app(14))
                    .foregroundStyle(AppColor.muted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.border, lineWidth: 1))
        }
    }
}
