import SwiftUI

/// Pendant zu `screens/calendar_screen.dart`.
/// Enthält: Monats-Kalender (nativ SwiftUI), Slot-Grid, Termin-Karten.
struct CalendarView: View {
    @Environment(AuthViewModel.self)     private var auth
    @Environment(CalendarViewModel.self) private var vm

    @State private var bookingSlot: CalTimeSlot?
    @State private var detailAppointment: Appointment?
    @State private var pendingCancelAppt: Appointment?
    @State private var showCancelAlert = false
    @State private var showNoCreditsAlert = false

    var body: some View {
        @Bindable var vm = vm
        ZStack {
            AppColor.background.ignoresSafeArea()

            if vm.isLoading && vm.calendarData == nil {
                LoadingView(message: "Lade Kalender…")
            } else if let err = vm.error, vm.calendarData == nil {
                ErrorStateView(message: err) {
                    Task { await vm.load(clientId: auth.clientId ?? "") }
                }
            } else {
                mainContent
            }
        }
        .task {
            if vm.calendarData == nil, let id = auth.clientId {
                await vm.load(clientId: id)
            }
        }
        .refreshable {
            if let id = auth.clientId { await vm.load(clientId: id) }
        }
        // Booking sheet
        .sheet(item: $bookingSlot) { slot in
            if let cal = vm.calendarData {
                let options = vm.optionsForSlot(slot, day: vm.selectedDate)
                BookingSheet(
                    slot: slot, day: vm.selectedDate,
                    calData: cal, options: options,
                    prefTrainerId: vm.prefTrainerId,
                    prefLocationId: vm.prefLocationId
                ) { selection in
                    Task {
                        guard let id = auth.clientId else { return }
                        await vm.book(slot: slot, selection: selection, clientId: id)
                    }
                }
            }
        }
        // Appointment detail sheet
        .sheet(item: $detailAppointment) { appt in
            AppointmentDetailSheet(appointment: appt, token: auth.token) {
                pendingCancelAppt = appt
                showCancelAlert   = true
            }
        }
        // Cancel alert
        .alert("Termin absagen", isPresented: $showCancelAlert, presenting: pendingCancelAppt) { appt in
            Button("Nein", role: .cancel) {}
            Button("Ja, absagen", role: .destructive) {
                Task {
                    guard let id = auth.clientId else { return }
                    do {
                        let refunded = try await vm.cancel(appointment: appt, clientId: id)
                        vm.toast = refunded
                            ? AppToast(message: "Termin abgesagt – Credit zurückerstattet.", style: .success)
                            : AppToast(message: "Termin abgesagt – Credit nicht zurückerstattet.", style: .neutral)
                    } catch {
                        vm.toast = AppToast(message: "Absage fehlgeschlagen: \(error.localizedDescription)", style: .error)
                    }
                }
            }
        } message: { appt in
            let hoursUntil = appt.startDate.timeIntervalSinceNow / 3600.0
            if hoursUntil < 12 {
                Text("Verspätete Absage (< 12 Stunden). Credit wird nicht zurückerstattet.")
            } else {
                Text("Credit wird automatisch zurückerstattet.")
            }
        }
        // No credits alert
        .alert("Keine Credits verfügbar", isPresented: $showNoCreditsAlert) {
            Button("Schließen", role: .cancel) {}
        } message: {
            Text("Du hast keine verfügbaren Credits. Bitte kaufe neue Credits, um Termine buchen zu können.")
        }
        // Toast overlay
        .appToast($vm.toast)
        // Booking loading overlay
        .overlay {
            if vm.isBooking || vm.isCancelling {
                ZStack {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView().tint(AppColor.primary).scaleEffect(1.4)
                        Text(vm.isBooking ? "Termin wird gebucht…" : "Termin wird abgesagt…")
                            .font(.system(size: 14))
                            .foregroundStyle(AppColor.text)
                    }
                    .padding(AppSpacing.card)
                    .background(AppColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                }
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // ── Monats-Kalender ────────────────────────────────────────────
                MonthCalendarView(
                    displayMonth: Binding(
                        get: { vm.displayMonth },
                        set: { vm.displayMonth = $0 }
                    ),
                    selectedDate: Binding(
                        get: { vm.selectedDate },
                        set: { vm.selectedDate = $0 }
                    ),
                    calendarData: vm.calendarData,
                    eventsForDay: { vm.eventsForDay($0) },
                    availForDay:  { vm.availabilityForDay($0) },
                    hasBookable:  { vm.hasAnyBookableWindow(for: $0) }
                )
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // ── Tag-Header ─────────────────────────────────────────────────
                dayHeader.padding(.horizontal, 16).padding(.top, 10)

                // ── Vorhandene Termine ────────────────────────────────────────
                let events = vm.eventsForDay(vm.selectedDate)
                if !events.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(events) { appt in
                            CalEventCard(appointment: appt) {
                                detailAppointment = appt
                            }
                            .opacity(appt.status.lowercased() == "cancelled" ? 0.45 : 1.0)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                // ── Slot-Grid ─────────────────────────────────────────────────
                let slots = vm.slotsForDay(vm.selectedDate)
                let avail = vm.availabilityForDay(vm.selectedDate)

                if !slots.isEmpty {
                    SlotGridView(slots: slots) { slot in
                        guard let cal = vm.calendarData else { return }
                        if cal.credits <= 0 { showNoCreditsAlert = true; return }
                        let opts = vm.optionsForSlot(slot, day: vm.selectedDate)
                        if opts.isEmpty {
                            vm.toast = AppToast(message: "Slot nicht mehr verfügbar.", style: .error)
                            return
                        }
                        bookingSlot = slot
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 80)

                } else if avail.isEmpty {
                    EmptyStateView(icon: "calendar.badge.exclamationmark",
                                   message: "Keine Verfügbarkeit an diesem Tag.")
                        .padding(.bottom, 80)
                } else {
                    EmptyStateView(icon: "calendar.badge.exclamationmark",
                                   message: "Keine buchbaren Termine an diesem Tag. Bitte einen anderen Tag wählen.")
                        .padding(.bottom, 80)
                }
            }
        }
    }

    // MARK: - Day Header

    private var dayHeader: some View {
        let slots = vm.slotsForDay(vm.selectedDate)
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "de_DE"); fmt.dateFormat = "EEEE, d. MMMM"

        return HStack {
            Text(fmt.string(from: vm.selectedDate))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColor.text)
            Spacer()
            if !slots.isEmpty {
                HStack(spacing: 4) {
                    Circle().fill(AppColor.green).frame(width: 6, height: 6)
                    Text("\(slots.count) Slots frei")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColor.green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(AppColor.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
            }
        }
    }

}

// MARK: - Month Calendar View

private struct MonthCalendarView: View {
    @Binding var displayMonth: Date
    @Binding var selectedDate: Date
    let calendarData: CalendarData?
    let eventsForDay: (Date) -> [Appointment]
    let availForDay:  (Date) -> [AvailabilityInterval]
    let hasBookable:  (Date) -> Bool

    private let cal = Calendar.current
    private let weekDays = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
    private let columns  = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    private var monthTitle: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "de_DE"); fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: displayMonth)
    }

    private var monthDays: [Date?] {
        guard let start = cal.date(from: cal.dateComponents([.year, .month], from: displayMonth)),
              let range = cal.range(of: .day, in: .month, for: start) else { return [] }
        let offset = (cal.component(.weekday, from: start) + 5) % 7  // Mon=0
        var days: [Date?] = Array(repeating: nil, count: offset)
        for day in range {
            days.append(cal.date(byAdding: .day, value: day - 1, to: start))
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    var body: some View {
        VStack(spacing: 0) {
            // Month header
            HStack {
                Button {
                    displayMonth = cal.date(byAdding: .month, value: -1, to: displayMonth) ?? displayMonth
                } label: {
                    Image(systemName: "chevron.left").foregroundStyle(AppColor.muted).padding(8)
                }
                Spacer()
                Text(monthTitle)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppColor.text)
                Spacer()
                Button {
                    displayMonth = cal.date(byAdding: .month, value: 1, to: displayMonth) ?? displayMonth
                } label: {
                    Image(systemName: "chevron.right").foregroundStyle(AppColor.muted).padding(8)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)

            // Week day headers
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(weekDays, id: \.self) { d in
                    Text(d)
                        .font(.system(size: 11))
                        .foregroundStyle(AppColor.muted)
                        .frame(height: 28)
                }
            }

            // Day cells
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(0..<monthDays.count, id: \.self) { i in
                    if let date = monthDays[i] {
                        let events = eventsForDay(date)
                        let avail  = availForDay(date)
                        DayCell(
                            date: date,
                            isSelected: cal.isDate(date, inSameDayAs: selectedDate),
                            isToday:    cal.isDateInToday(date),
                            appointments: events,
                            hasBookable: avail.isEmpty ? false : hasBookable(date),
                            minDate: calendarData?.minimumDate,
                            maxDate: calendarData?.maximumDate
                        ) { selectedDate = date }
                    } else {
                        Color.clear.frame(height: 52)
                    }
                }
            }
            .padding(.bottom, 8)
        }
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.border, lineWidth: 1))
    }
}

// MARK: - Day Cell

private struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let appointments: [Appointment]
    let hasBookable: Bool
    let minDate: Date?
    let maxDate: Date?
    let onTap: () -> Void

    private var isOutOfRange: Bool {
        if let min = minDate, date < min { return true }
        if let max = maxDate, date > max { return true }
        return false
    }

    private var dayNum: Int { Calendar.current.component(.day, from: date) }

    private var bookedCount:    Int { appointments.filter { $0.status.lowercased() == "booked" || $0.status.lowercased() == "attended" }.count }
    private var missedCount:    Int { appointments.filter { $0.status.lowercased() == "missed"    }.count }
    private var cancelledCount: Int { appointments.filter { $0.status.lowercased() == "cancelled" }.count }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                ZStack {
                    if isSelected {
                        Circle().fill(AppColor.primary).frame(width: 32, height: 32)
                    } else if isToday {
                        Circle().fill(AppColor.primary.opacity(0.3)).frame(width: 32, height: 32)
                    }
                    Text("\(dayNum)")
                        .font(.system(size: 14, weight: isSelected ? .bold : .regular))
                        .foregroundStyle(
                            isOutOfRange ? AppColor.muted.opacity(0.35)
                            : isSelected ? Color.white
                            : AppColor.text
                        )
                }
                .frame(width: 36, height: 36)

                // Dot markers
                HStack(spacing: 2) {
                    if hasBookable   { dot(AppColor.green) }
                    if bookedCount > 1 {
                        countDot(AppColor.primary, bookedCount)
                    } else if bookedCount == 1 {
                        dot(AppColor.primary)
                    }
                    if missedCount    > 0 { dot(AppColor.orange) }
                    if cancelledCount > 0 { dot(AppColor.red)    }
                }
                .frame(height: 8)
            }
            .frame(height: 52)
        }
        .buttonStyle(.plain)
        .disabled(isOutOfRange)
    }

    private func dot(_ color: Color) -> some View {
        Circle().fill(color).frame(width: 6, height: 6)
    }

    private func countDot(_ color: Color, _ n: Int) -> some View {
        Text("\(n)")
            .font(.system(size: 7, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 3)
            .frame(height: 10)
            .background(color)
            .clipShape(Capsule())
    }
}

// MARK: - Slot Grid

private struct SlotGridView: View {
    let slots: [CalTimeSlot]
    let onTap: (CalTimeSlot) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "square.grid.2x2").font(.system(size: 12)).foregroundStyle(AppColor.muted)
                Text("Verfügbare Slots").font(.system(size: 12, weight: .semibold)).foregroundStyle(AppColor.muted)
            }
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 4)

            // Wrap-Layout für Slot-Chips
            FlowLayout(spacing: 6) {
                ForEach(slots) { slot in
                    SlotChip(slot: slot) { onTap(slot) }
                }
            }
            .padding(.horizontal, 10).padding(.bottom, 10)

            // Legende
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2).fill(AppColor.green).frame(width: 8, height: 8)
                Text("Antippen zum Buchen").font(.system(size: 10)).foregroundStyle(AppColor.green)
            }
            .padding(.horizontal, 14).padding(.bottom, 10)
        }
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.border, lineWidth: 1))
    }
}

private struct SlotChip: View {
    let slot: CalTimeSlot
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 1) {
                Text(slot.timeStr)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppColor.green)
                Text(slot.endTimeStr)
                    .font(.system(size: 10))
                    .foregroundStyle(AppColor.green.opacity(0.6))
            }
            .frame(width: 80)
            .padding(.vertical, 8)
            .background(AppColor.green.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.control)
                .stroke(AppColor.green.opacity(0.24), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Calendar Event Card

struct CalEventCard: View {
    let appointment: Appointment
    let onTap: () -> Void

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()

    var body: some View {
        let statusLower = appointment.status.lowercased()
        let isCancelled = statusLower == "cancelled"
        let isMissed    = statusLower == "missed"
        // Abgesagt: neutraler Akzent — Zustand signalisieren nur Badge + Opacity.
        let accent: Color = {
            switch statusLower {
            case "cancelled": return AppColor.muted
            case "attended":  return AppColor.green
            case "missed":    return AppColor.orange
            default:          return AppColor.primary
            }
        }()
        let endTime = appointment.startDate.addingTimeInterval(TimeInterval(appointment.duration * 60))

        // Punktgetrennte Meta-Zeile (Muster wie StartView-Terminkarte)
        var metaParts: [String] = [
            "\(Self.timeFmt.string(from: appointment.startDate))–\(Self.timeFmt.string(from: endTime))",
            "\(appointment.duration) Min.",
        ]
        if !appointment.trainerName.isEmpty  { metaParts.append(appointment.trainerName) }
        if !appointment.locationName.isEmpty { metaParts.append(appointment.locationName) }

        return Button(action: onTap) {
            HStack(spacing: 0) {
                // Accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(accent)
                    .frame(width: 4, height: 44)
                    .padding(.trailing, 12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(appointment.trainingTypeName.isEmpty ? "Training" : appointment.trainingTypeName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppColor.text)

                    Text(metaParts.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                        .lineLimit(1)

                    if let plan = appointment.trainingPlanName, !plan.isEmpty {
                        Text(plan)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(accent)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Status badge / chevron
                if isCancelled {
                    Text("Abgesagt").font(.system(size: 11)).foregroundStyle(AppColor.red)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(AppColor.red.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
                } else if isMissed {
                    Text("Verpasst").font(.system(size: 11)).foregroundStyle(AppColor.orange)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(AppColor.orange.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
                } else {
                    Image(systemName: "chevron.right").font(.system(size: 14)).foregroundStyle(AppColor.muted)
                }
            }
            .padding(AppSpacing.card)
            .background(accent.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(accent.opacity(0.16), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout (kein LazyVGrid, da variable Breiten)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(subviews: subviews, in: proposal.replacingUnspecifiedDimensions()).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, in: bounds.size)
        for (view, frame) in zip(subviews, result.frames) {
            view.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                       proposal: ProposedViewSize(frame.size))
        }
    }

    private func layout(subviews: Subviews, in size: CGSize) -> (size: CGSize, frames: [CGRect]) {
        var frames: [CGRect] = []
        var x: CGFloat = 0; var y: CGFloat = 0; var rowH: CGFloat = 0
        for view in subviews {
            let s = view.sizeThatFits(.unspecified)
            if x + s.width > size.width && x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: s))
            x += s.width + spacing; rowH = max(rowH, s.height)
        }
        return (CGSize(width: size.width, height: y + rowH), frames)
    }
}
