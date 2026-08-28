import SwiftUI

/// Platzhalter — der Nachrichten-Bereich aus `nachrichten_screen.dart`
/// (Konversationen, Live-Aktualisierung über SSE) folgt.
struct ChatView: View {
    var body: some View {
        MessageState(icon: "bubble.left.and.bubble.right",
                     title: "Nachrichten folgen",
                     message: "Konversationen und Live-Aktualisierung werden als Nächstes portiert.")
            .background(AppColor.background)
            .sectionChrome("Nachrichten")
    }
}
