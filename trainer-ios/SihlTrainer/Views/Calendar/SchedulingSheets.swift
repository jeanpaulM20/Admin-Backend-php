import SwiftUI

/// Termin buchen. Pendant zu `screens/book_training_dialog.dart`.
struct BookTrainingSheet: View {
    let initialDate: Date
    let isPreview: Bool
    let onBooked: () -> Void

    @EnvironmentObject private var store: TrainerStore
    @Environment(\.dismiss) private var dismiss

    @State private var clientId: Int?
    @State private var date: Date
    @State private var locations: [(id: Int, name: String)] = []
    @State private var locationId: Int?
    @State private var isSaving = false
    @State private var error: String?

    init(initialDate: Date, isPreview: Bool, onBooked: @escaping () -> Void) {
        self.initialDate = initialDate
        self.isPreview = isPreview
        self.onBooked = onBooked
        // Vorbelegung auf die nächste volle Stunde des gewählten Tages.
        let calendar = Calendar.sihl
        let hour = calendar.component(.hour, from: Date()) + 1
        _date = State(initialValue: calendar.date(bySettingHour: min(hour, 20), minute: 0,
                                                  second: 0, of: initialDate) ?? initialDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Kunde") {
                    Picker("Kunde", selection: $clientId) {
                        Text("Bitte wählen").tag(Int?.none)
                        ForEach(store.clients) { client in
                            Text(client.name).tag(Int?.some(client.id))
                        }
                    }
                    .listRowBackground(AppColor.surface)
                }
                Section("Termin") {
                    DatePicker("Datum und Zeit", selection: $date)
                        .font(.app(15))
                        .listRowBackground(AppColor.surface)
                    if !locations.isEmpty {
                        Picker("Standort", selection: $locationId) {
                            Text("Ohne").tag(Int?.none)
                            ForEach(locations, id: \.id) { location in
                                Text(location.name).tag(Int?.some(location.id))
                            }
                        }
                        .listRowBackground(AppColor.surface)
                    }
                }
                if let error {
                    Section {
                        Text(error).font(.app(13)).foregroundStyle(AppColor.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColor.background)
            .navigationTitle("Training buchen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }.foregroundStyle(AppColor.muted)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await book() }
                    } label: {
                        if isSaving {
                            ProgressView().tint(AppColor.primary)
                        } else {
                            Text("Buchen").font(.app(15, weight: .semibold))
                        }
                    }
                    .disabled(clientId == nil || isSaving)
                }
            }
            .task { await loadLocations() }
        }
    }

    private func loadLocations() async {
        #if DEBUG
        if isPreview {
            locations = [(id: 1, name: "Studio Sihlcity"), (id: 2, name: "Studio Wiedikon")]
            return
        }
        #endif
        locations = (try? await SchedulingService().locations()) ?? []
    }

    private func book() async {
        guard let clientId else { return }
        isSaving = true
        defer { isSaving = false }
        #if DEBUG
        if isPreview {
            onBooked()
            dismiss()
            return
        }
        #endif
        do {
            try await SchedulingService().bookTraining(clientId: clientId, date: date, locationId: locationId)
            onBooked()
            dismiss()
        } catch let apiError as APIError {
            error = apiError.message
        } catch {
            self.error = "Termin konnte nicht gebucht werden"
        }
    }
}

/// Einzelnes Zeitfenster anlegen — Ergänzung zur Serie für spontane
/// Zusatztermine. Mit `day` (Kalender) steht das Datum fest, ohne `day`
/// (Einstellungen) wählt man es im Sheet.
struct SingleSlotSheet: View {
    let trainerId: Int
    let isPreview: Bool
    var day: Date? = nil
    let onCreated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    @State private var from: Date
    @State private var to: Date
    @State private var isSaving = false
    @State private var error: String?

    private let datePickable: Bool

    init(trainerId: Int, isPreview: Bool, day: Date? = nil, onCreated: @escaping () -> Void) {
        self.trainerId = trainerId
        self.isPreview = isPreview
        self.day = day
        self.onCreated = onCreated
        let base = day ?? Date()
        _date = State(initialValue: base)
        _from = State(initialValue: Calendar.sihl.date(bySettingHour: 9, minute: 0, second: 0, of: base) ?? base)
        _to   = State(initialValue: Calendar.sihl.date(bySettingHour: 10, minute: 0, second: 0, of: base) ?? base)
        datePickable = (day == nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tag") {
                    if datePickable {
                        DatePicker("Datum", selection: $date, displayedComponents: .date)
                            .listRowBackground(AppColor.surface)
                    } else {
                        Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                            .font(.app(15))
                            .foregroundStyle(AppColor.text)
                            .listRowBackground(AppColor.surface)
                    }
                }
                Section("Uhrzeit") {
                    DatePicker("Von", selection: $from, displayedComponents: .hourAndMinute)
                        .listRowBackground(AppColor.surface)
                    DatePicker("Bis", selection: $to, displayedComponents: .hourAndMinute)
                        .listRowBackground(AppColor.surface)
                }
                if let error {
                    Section {
                        Text(error).font(.app(13)).foregroundStyle(AppColor.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColor.background)
            .navigationTitle("Zeitfenster")
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
                            Text("Anlegen").font(.app(15, weight: .semibold))
                        }
                    }
                    .disabled(isSaving || !endAfterStart)
                }
            }
        }
    }

    /// Nur die Uhrzeit zählt — die Datumsanteile der Picker können differieren.
    private var endAfterStart: Bool {
        let cal = Calendar.sihl
        let f = cal.dateComponents([.hour, .minute], from: from)
        let t = cal.dateComponents([.hour, .minute], from: to)
        return (t.hour ?? 0) * 60 + (t.minute ?? 0) > (f.hour ?? 0) * 60 + (f.minute ?? 0)
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
            try await SchedulingService().createAvailability(
                trainerId: trainerId, day: date, from: from, to: to)
            onCreated()
            dismiss()
        } catch let apiError as APIError {
            error = apiError.message
        } catch {
            self.error = "Zeitfenster konnte nicht angelegt werden"
        }
    }
}

/// Serienverfügbarkeit anlegen.
/// Pendant zu `screens/availability_serial_screen.dart`.
struct AvailabilitySerialSheet: View {
    let trainerId: Int
    let isPreview: Bool
    let onCreated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var from = Calendar.sihl.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var to = Calendar.sihl.date(bySettingHour: 12, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var rangeStart = Date()
    @State private var rangeEnd = Calendar.sihl.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    /// 1 = Montag … 7 = Sonntag, wie es das Backend erwartet.
    @State private var weekdays: Set<Int> = [1, 3, 5]
    @State private var isSaving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Wochentage") {
                    HStack(spacing: 6) {
                        ForEach(1...7, id: \.self) { day in
                            FilterChip(title: TrainingStats.weekdayNames[day - 1],
                                       isActive: weekdays.contains(day)) {
                                if weekdays.contains(day) { weekdays.remove(day) } else { weekdays.insert(day) }
                            }
                        }
                    }
                    .listRowBackground(AppColor.surface)
                }
                Section("Uhrzeit") {
                    DatePicker("Von", selection: $from, displayedComponents: .hourAndMinute)
                        .listRowBackground(AppColor.surface)
                    DatePicker("Bis", selection: $to, displayedComponents: .hourAndMinute)
                        .listRowBackground(AppColor.surface)
                }
                Section("Zeitraum") {
                    DatePicker("Start", selection: $rangeStart, displayedComponents: .date)
                        .listRowBackground(AppColor.surface)
                    DatePicker("Ende", selection: $rangeEnd, in: rangeStart..., displayedComponents: .date)
                        .listRowBackground(AppColor.surface)
                }
                if let error {
                    Section {
                        Text(error).font(.app(13)).foregroundStyle(AppColor.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColor.background)
            .navigationTitle("Serie anlegen")
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
                            Text("Anlegen").font(.app(15, weight: .semibold))
                        }
                    }
                    .disabled(weekdays.isEmpty || isSaving || to <= from)
                }
            }
        }
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
            try await SchedulingService().createSerialAvailability(
                trainerId: trainerId, from: from, to: to,
                rangeStart: rangeStart, rangeEnd: rangeEnd,
                weekdays: Array(weekdays)
            )
            onCreated()
            dismiss()
        } catch let apiError as APIError {
            error = apiError.message
        } catch {
            self.error = "Serie konnte nicht angelegt werden"
        }
    }
}
