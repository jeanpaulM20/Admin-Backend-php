import SwiftUI

/// Gemeinsam genutzte kleine View-Bausteine, die in mehreren Screens vorkommen.

// MARK: - ToastView

/// Kurze Status-Meldung unten am Bildschirm, auto-dismiss nach 3 s.
struct ToastView: View {
    let message: String
    var body: some View {
        Text(message)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(AppColor.text)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppColor.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 2)
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
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(accentColor)
                    }
                }
            )
    }
}
