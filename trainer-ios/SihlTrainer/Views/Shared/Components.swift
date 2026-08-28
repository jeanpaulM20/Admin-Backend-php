import SwiftUI

/// Wiederkehrende Bausteine — hier zentral, damit die Screens beim Portieren
/// nicht jeder ihre eigene Karte und ihren eigenen Ladezustand erfinden.

/// Karte auf Surface-Fläche mit Rahmen — das Grundelement aller Listen.
struct Card<Content: View>: View {
    var padding: CGFloat = AppSpacing.card
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .stroke(AppColor.border, lineWidth: 1)
            )
    }
}

/// Rundes Initialen-Emblem; zeigt das Foto, sobald eine URL vorhanden ist.
struct Avatar: View {
    let initials: String
    var photo: String?
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle().fill(AppColor.surface2)
            if let url = photoURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    initialsText
                }
                .clipShape(Circle())
            } else {
                initialsText
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(AppColor.border, lineWidth: 1))
    }

    private var initialsText: some View {
        Text(initials)
            .font(.app(size * 0.36, weight: .semibold))
            .foregroundStyle(AppColor.primary)
    }

    private var photoURL: URL? {
        guard let photo, !photo.isEmpty else { return nil }
        if photo.hasPrefix("http") { return URL(string: photo) }
        return URL(string: photo, relativeTo: APIConfig.baseURL)
    }
}

/// Ladezustand, Fehlerzustand und Leerzustand einer Liste — in der Flutter-App
/// baut das jeder Screen selbst, hier einmal.
struct LoadingState: View {
    var body: some View {
        ProgressView()
            .tint(AppColor.primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MessageState: View {
    let icon: String
    let title: String
    var message: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: AppSpacing.stack) {
            Image(systemName: icon)
                .font(.app(34))
                .foregroundStyle(AppColor.muted)
            Text(title)
                .font(.app(16, weight: .semibold))
                .foregroundStyle(AppColor.text)
            if let message {
                Text(message)
                    .font(.app(14))
                    .foregroundStyle(AppColor.muted)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.app(14, weight: .semibold))
                    .foregroundStyle(AppColor.primary)
                    .padding(.top, 4)
            }
        }
        .padding(AppSpacing.screen)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Suchfeld im Stil der App (statt `.searchable`, damit Farbe und Rahmen
/// zur Marken-Palette passen).
struct SearchField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppColor.muted)
            TextField(placeholder, text: $text)
                .foregroundStyle(AppColor.text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppColor.muted)
                }
                .accessibilityLabel("Suche löschen")
            }
        }
        .font(.app(15))
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.control)
                .stroke(AppColor.border, lineWidth: 1)
        )
    }
}

/// Kennzahl-Kachel (Home: „Heute", „Diese Woche").
struct StatTile: View {
    let value: String
    let label: String
    var accent: Color = AppColor.primary

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.app(26, weight: .bold))
                    .foregroundStyle(accent)
                Text(label)
                    .font(.app(13))
                    .foregroundStyle(AppColor.muted)
            }
        }
    }
}
