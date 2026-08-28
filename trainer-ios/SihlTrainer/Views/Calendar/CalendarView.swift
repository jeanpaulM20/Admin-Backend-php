import SwiftUI

/// Platzhalter — der Kalender aus `calendar_screen.dart` (1'081 Zeilen:
/// Monatsraster, Verfügbarkeiten, Buchungsdialog) ist für die nächste Etappe
/// vorgesehen.
struct CalendarView: View {
    var body: some View {
        MessageState(icon: "calendar",
                     title: "Kalender folgt",
                     message: "Monatsansicht, Verfügbarkeiten und Buchung werden als Nächstes portiert.")
            .background(AppColor.background)
            .sectionChrome("Kalender")
    }
}
