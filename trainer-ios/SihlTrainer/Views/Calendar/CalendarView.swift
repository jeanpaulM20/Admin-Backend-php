import SwiftUI

/// Pendant zu `screens/calendar_screen.dart`: Monatsraster mit Markierungen,
/// darunter die Einträge des gewählten Tages (Termine + Verfügbarkeiten).
/// Das Bearbeiten von Verfügbarkeiten und der Buchungsdialog folgen später.
struct CalendarView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var store: TrainerStore
    @EnvironmentObject private var calendarStore: CalendarStore

    @State private var showBooking = false
    @State private var showSerial = false
    @State private var visibleMonth = Date()
    @State private var selectedDay = Calendar.sihl.startOfDay(for: Date())

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.stack) {
                monthCard
                dayDetail
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.bottom, AppSpacing.bottomInset)
        }
        .background(AppColor.background)
        .refreshable { await reload() }
        .sectionChrome("Kalender")
        .toolbar {
            ToolbarItemGroup(placement: .topBarLeading) {
                Button {
                    showBooking = true
                } label: {
                    Image(systemName: "calendar.badge.plus")
                }
                .accessibilityLabel("Training buchen")

                Button {
                    showSerial = true
                } label: {
                    Image(systemName: "clock.badge.checkmark")
                }
                .accessibilityLabel("Serienverfügbarkeit anlegen")
            }
        }
        .sheet(isPresented: $showBooking) {
            BookTrainingSheet(initialDate: selectedDay, isPreview: auth.previewFlag) {
                Task { await reload() }
            }
        }
        .sheet(isPresented: $showSerial) {
            if let trainer = auth.trainer {
                AvailabilitySerialSheet(trainerId: trainer.id, isPreview: auth.previewFlag) {
                    Task { await reload() }
                }
            }
        }
    }

    // MARK: - Monatsraster

    private var monthCard: some View {
        Card {
            VStack(spacing: 12) {
                monthHeader
                weekdayHeader
                MonthGrid(month: visibleMonth,
                          selectedDay: selectedDay,
                          trainingDays: trainingDays,
                          availabilityDays: Set(calendarStore.slotsByDay.keys)) { day in
                    selectedDay = day
                }
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left").foregroundStyle(AppColor.muted)
            }
            .accessibilityLabel("Vorheriger Monat")

            Spacer()

            Text(Self.monthFormatter.string(from: visibleMonth))
                .font(.app(16, weight: .semibold))
                .foregroundStyle(AppColor.text)

            Spacer()

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right").foregroundStyle(AppColor.muted)
            }
            .accessibilityLabel("Nächster Monat")
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Calendar.sihl.shortWeekdaySymbolsMondayFirst, id: \.self) { symbol in
                Text(symbol)
                    .font(.app(11, weight: .semibold))
                    .foregroundStyle(AppColor.muted)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// Tage mit mindestens einem nicht abgesagten Termin.
    private var trainingDays: Set<Date> {
        Set(store.trainings.compactMap { training -> Date? in
            guard let start = training.startTime, !training.isCancelled else { return nil }
            return Calendar.sihl.startOfDay(for: start)
        })
    }

    private func shiftMonth(by months: Int) {
        guard let shifted = Calendar.sihl.date(byAdding: .month, value: months, to: visibleMonth) else { return }
        visibleMonth = shifted
    }

    // MARK: - Tagesdetail

    private var trainingsOfDay: [Training] {
        store.trainings
            .filter { training in
                guard let start = training.startTime else { return false }
                return Calendar.sihl.isDate(start, inSameDayAs: selectedDay)
            }
            .sorted { ($0.startTime ?? .distantPast) < ($1.startTime ?? .distantPast) }
    }

    private var dayDetail: some View {
        Card {
            VStack(alignment: .leading, spacing: AppSpacing.stack) {
                Text(Self.dayFormatter.string(from: selectedDay))
                    .font(.app(14, weight: .semibold))
                    .foregroundStyle(AppColor.text)

                if trainingsOfDay.isEmpty && calendarStore.slots(on: selectedDay).isEmpty {
                    Text("Keine Einträge an diesem Tag")
                        .font(.app(14))
                        .foregroundStyle(AppColor.muted)
                }

                if !trainingsOfDay.isEmpty {
                    Text("Termine")
                        .font(.app(12, weight: .semibold))
                        .foregroundStyle(AppColor.muted)
                    ForEach(trainingsOfDay) { training in
                        NavigationLink {
                            TrainingDetailView(training: training,
                                               isPreview: auth.previewFlag) {
                                Task { await reload() }
                            }
                        } label: {
                            TrainingRow(training: training, showsDay: false)
                        }
                        .buttonStyle(.plain)
                    }
                }

                let slots = calendarStore.slots(on: selectedDay)
                if !slots.isEmpty {
                    Text("Verfügbarkeit")
                        .font(.app(12, weight: .semibold))
                        .foregroundStyle(AppColor.muted)
                        .padding(.top, 4)
                    ForEach(slots) { slot in
                        SlotRow(slot: slot)
                            .contextMenu {
                                // Belegte Fenster nicht löschen — daran hängt
                                // ein gebuchter Termin.
                                if !slot.isBooked {
                                    Button(role: .destructive) {
                                        Task { await deleteSlot(slot) }
                                    } label: {
                                        Label("Verfügbarkeit löschen", systemImage: "trash")
                                    }
                                }
                            }
                    }
                }
            }
        }
    }

    private func deleteSlot(_ slot: AvailabilitySlot) async {
        if !auth.previewFlag {
            try? await SchedulingService().deleteAvailability(slotId: slot.id)
        }
        await reload()
    }

    private func reload() async {
        guard let id = auth.trainer?.id else { return }
        await store.loadTrainings(trainerId: id)
        await calendarStore.load(trainerId: id)
    }

    static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_CH")
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_CH")
        f.dateFormat = "EEEE, d. MMMM"
        return f
    }()
}

/// Das Raster eines Monats. Punkte unter der Zahl: Marken-Olive für Termine,
/// Messing für Verfügbarkeiten — dieselbe Doppelmarkierung wie in Flutter.
private struct MonthGrid: View {
    let month: Date
    let selectedDay: Date
    let trainingDays: Set<Date>
    let availabilityDays: Set<Date>
    let onSelect: (Date) -> Void

    private var days: [Date?] {
        Calendar.sihl.monthGrid(for: month)
    }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 6) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 40)
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = Calendar.sihl.isDate(day, inSameDayAs: selectedDay)
        let isToday = Calendar.sihl.isDateInToday(day)
        return Button {
            onSelect(day)
        } label: {
            VStack(spacing: 3) {
                Text("\(Calendar.sihl.component(.day, from: day))")
                    .font(.app(14, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isSelected ? AppColor.white
                                     : (isToday ? AppColor.primary : AppColor.text))
                HStack(spacing: 3) {
                    if trainingDays.contains(day) {
                        Circle().fill(isSelected ? AppColor.white : AppColor.primary)
                            .frame(width: 4, height: 4)
                    }
                    if availabilityDays.contains(day) {
                        Circle().fill(isSelected ? AppColor.white : AppColor.brass)
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(isSelected ? AppColor.primary : .clear)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
        }
        .buttonStyle(.plain)
    }
}

private struct SlotRow: View {
    let slot: AvailabilitySlot

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: slot.isBooked ? "lock.fill" : "clock")
                .font(.app(12))
                .foregroundStyle(slot.isBooked ? AppColor.muted : AppColor.brass)
                .frame(width: 18)
            Text(timeRange)
                .font(.app(14))
                .foregroundStyle(AppColor.text)
            if let location = slot.locationName {
                Text("· \(location)")
                    .font(.app(13))
                    .foregroundStyle(AppColor.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if slot.isBooked {
                Text("belegt")
                    .font(.app(11, weight: .semibold))
                    .foregroundStyle(AppColor.muted)
            }
        }
    }

    private var timeRange: String {
        let from = slot.timeFrom.map(Self.trim) ?? "?"
        let to = slot.timeTo.map(Self.trim) ?? "?"
        return "\(from)–\(to)"
    }

    /// "17:00:00" → "17:00"
    private static func trim(_ time: String) -> String {
        time.split(separator: ":").prefix(2).joined(separator: ":")
    }
}

extension Calendar {
    /// Kalender der App: Montag als erster Wochentag, Schweizer Locale.
    static let sihl: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "de_CH")
        calendar.firstWeekday = 2
        return calendar
    }()

    /// Wochentagskürzel ab Montag.
    var shortWeekdaySymbolsMondayFirst: [String] {
        let symbols = DateFormatter().shortWeekdaySymbolsForLocale(locale ?? .current)
        return Array(symbols[1...]) + [symbols[0]]
    }

    /// Alle Tage des Monats, vorne aufgefüllt bis zum ersten Montag.
    func monthGrid(for month: Date) -> [Date?] {
        guard let interval = dateInterval(of: .month, for: month),
              let range = self.range(of: .day, in: .month, for: month) else { return [] }
        let first = interval.start
        // Wie viele Leerfelder vor dem Ersten? firstWeekday=2 (Montag) einrechnen.
        let weekday = component(.weekday, from: first)
        let leading = (weekday - firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<range.count {
            cells.append(date(byAdding: .day, value: offset, to: first))
        }
        return cells
    }
}

private extension DateFormatter {
    func shortWeekdaySymbolsForLocale(_ locale: Locale) -> [String] {
        self.locale = locale
        return shortWeekdaySymbols ?? ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]
    }
}
