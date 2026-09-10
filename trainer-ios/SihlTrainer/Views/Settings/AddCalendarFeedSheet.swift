import SwiftUI

/// Einen Fremdkalender abonnieren.
///
/// Gebraucht wird die iCal-Adresse des anderen Studios — bei Google steht sie
/// unter Einstellungen → Kalender auswählen → „Geheime Adresse im iCal-Format".
struct AddCalendarFeedSheet: View {
    let trainerId: Int
    let onAdded: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var label = ""
    @State private var url = ""
    @State private var isSaving = false
    @State private var error: String?

    private var canSave: Bool {
        !url.trimmingCharacters(in: .whitespaces).isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Bezeichnung") {
                    TextField("z.B. Studio Enge", text: $label)
                        .font(.app(15))
                        .foregroundStyle(AppColor.text)
                        .listRowBackground(AppColor.surface)
                }

                Section("iCal-Adresse") {
                    TextField("https://…/basic.ics", text: $url, axis: .vertical)
                        .lineLimit(2...4)
                        .font(.app(13, design: .monospaced))
                        .foregroundStyle(AppColor.text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .listRowBackground(AppColor.surface)
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Wo finde ich die Adresse?")
                            .font(.app(12, weight: .semibold))
                            .foregroundStyle(AppColor.text)
                        Text("Google Kalender → Einstellungen → gewünschten Kalender wählen → „Geheime Adresse im iCal-Format“. Outlook, Apple und die meisten Studio-Systeme haben eine entsprechende Freigabe.")
                            .font(.app(12))
                            .foregroundStyle(AppColor.muted)
                        Text("Die Adresse ist ein Generalschlüssel zu diesem Kalender — gib sie nicht weiter. Übernommen werden nur Zeiten, keine Termintitel.")
                            .font(.app(12))
                            .foregroundStyle(AppColor.brass)
                    }
                    .listRowBackground(AppColor.surface)
                }

                if let error {
                    Section {
                        Text(error)
                            .font(.app(13))
                            .foregroundStyle(AppColor.red)
                            .listRowBackground(AppColor.surface)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColor.background)
            .navigationTitle("Kalender abonnieren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }.foregroundStyle(AppColor.muted)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().tint(AppColor.primary)
                        } else {
                            Text("Abonnieren").font(.app(15, weight: .semibold))
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            let feed = try await CalendarFeedService().add(
                trainerId: trainerId,
                label: label.trimmingCharacters(in: .whitespaces),
                url: url.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            // Das Backend liest sofort ein: ein Fehler hier bedeutet, dass die
            // Adresse zwar gespeichert ist, aber nichts liefert.
            if let problem = feed.lastError {
                error = problem
                onAdded()
                return
            }
            onAdded()
            dismiss()
        } catch let apiError as APIError {
            error = apiError.message
        } catch {
            self.error = "Der Kalender konnte nicht abonniert werden."
        }
    }
}
