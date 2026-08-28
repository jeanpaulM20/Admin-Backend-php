import SwiftUI

/// Pendant zu `screens/new_client_screen.dart`: neuen Kunden anlegen.
struct NewClientView: View {
    let isPreview: Bool
    let onCreated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var surname = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var mobile = ""
    @State private var birthday: Date?
    @State private var showBirthdayPicker = false
    @State private var isSaving = false
    @State private var error: String?

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !surname.trimmingCharacters(in: .whitespaces).isEmpty
            && !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Person") {
                    labelledField("Vorname", text: $name)
                    labelledField("Nachname", text: $surname)
                    birthdayRow
                }
                Section("Kontakt") {
                    labelledField("E-Mail", text: $email, keyboard: .emailAddress)
                    labelledField("Telefon", text: $phone, keyboard: .phonePad)
                    labelledField("Mobil", text: $mobile, keyboard: .phonePad)
                }
                if let error {
                    Section {
                        Text(error)
                            .font(.app(13))
                            .foregroundStyle(AppColor.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColor.background)
            .navigationTitle("Neuer Kunde")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(AppColor.muted)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().tint(AppColor.primary)
                        } else {
                            Text("Sichern").font(.app(15, weight: .semibold))
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func labelledField(_ title: String, text: Binding<String>,
                               keyboard: UIKeyboardType = .default) -> some View {
        TextField(title, text: text)
            .font(.app(15))
            .foregroundStyle(AppColor.text)
            .keyboardType(keyboard)
            .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
            .autocorrectionDisabled()
            .listRowBackground(AppColor.surface)
    }

    private var birthdayRow: some View {
        Group {
            Button {
                if birthday == nil { birthday = Date() }
                showBirthdayPicker.toggle()
            } label: {
                HStack {
                    Text("Geburtstag")
                        .font(.app(15))
                        .foregroundStyle(AppColor.text)
                    Spacer()
                    Text(birthday.map { Self.dayFormatter.string(from: $0) } ?? "—")
                        .font(.app(15))
                        .foregroundStyle(AppColor.muted)
                }
            }
            if showBirthdayPicker, birthday != nil {
                DatePicker("", selection: Binding(
                    get: { birthday ?? Date() },
                    set: { birthday = $0 }
                ), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(AppColor.primary)
            }
        }
        .listRowBackground(AppColor.surface)
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        #if DEBUG
        if isPreview {
            onCreated()
            dismiss()
            return
        }
        #endif
        do {
            try await ClientRecordsService().createClient(
                surname: surname.trimmingCharacters(in: .whitespaces),
                name: name.trimmingCharacters(in: .whitespaces),
                email: email, phone: phone, mobile: mobile,
                birthday: birthday.map { SchedulingService.dayFormatter.string(from: $0) }
            )
            onCreated()
            dismiss()
        } catch let apiError as APIError {
            error = apiError.message
        } catch {
            self.error = "Kunde konnte nicht angelegt werden"
        }
    }

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_CH")
        f.dateStyle = .medium
        return f
    }()
}
