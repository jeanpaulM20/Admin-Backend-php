import SwiftUI

/// Buchungs-Sheet — Pendant zur `_showBookingSheet`-Logik in `calendar_screen.dart`.
/// Zeigt Trainer + Standort-Picker und einen Bestätigungs-Button.
struct BookingSheet: View {
    let slot: CalTimeSlot
    let day: Date
    let calData: CalendarData
    let options: [SlotOption]
    let onConfirm: (SlotSelection) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selTrainerId:  String?
    @State private var selLocationId: String?
    @State private var locationWasReset = false

    // Pre-populate from preferences
    init(slot: CalTimeSlot, day: Date, calData: CalendarData, options: [SlotOption],
         prefTrainerId: String?, prefLocationId: String?,
         onConfirm: @escaping (SlotSelection) -> Void) {
        self.slot      = slot
        self.day       = day
        self.calData   = calData
        self.options   = options
        self.onConfirm = onConfirm

        let trainerIds = Array(Set(options.map(\.trainerId)))
        let initTrainer = trainerIds.contains(prefTrainerId ?? "")
            ? prefTrainerId
            : (trainerIds.count == 1 ? trainerIds.first : nil)

        let allLocIds = calData.locations.map(\.id)
        let initLoc: String?
        if let pref = prefLocationId, allLocIds.contains(pref) {
            initLoc = pref
        } else if allLocIds.count == 1 {
            initLoc = allLocIds.first
        } else {
            initLoc = nil
        }

        _selTrainerId  = State(initialValue: initTrainer)
        _selLocationId = State(initialValue: initLoc)
    }

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "EEEE, d. MMMM"; return f
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Slot-Info
                    slotHeader.padding(.bottom, 20)

                    // Trainer-Picker
                    pickerLabel("Trainer")
                    trainerPicker.padding(.bottom, 14)

                    // Standort-Picker
                    pickerLabel("Standort")
                    locationPicker

                    // Hinweis Standort zurückgesetzt
                    if locationWasReset {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                                .font(.app(12))
                                .foregroundStyle(AppColor.orange)
                            Text("Standort angepasst (Pufferzeit mit neuem Trainer)")
                                .font(.app(11))
                                .foregroundStyle(AppColor.orange)
                        }
                        .padding(.top, 6)
                    }

                    // Buchungs-Zusammenfassung
                    if let tid = selTrainerId, let lid = selLocationId {
                        confirmSummary(trainerId: tid, locationId: lid)
                            .padding(.top, 20)
                    }

                    // Buttons
                    actionRow.padding(.top, 20)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .background(AppColor.background.ignoresSafeArea())
            .navigationTitle("Termin buchen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(AppColor.muted)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Slot Header

    private var slotHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.app(13))
                    .foregroundStyle(AppColor.primary)
                Text(Self.dateFmt.string(from: day))
                    .font(.app(14, weight: .semibold))
                    .foregroundStyle(AppColor.primary)
            }
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.app(13))
                    .foregroundStyle(AppColor.primary)
                Text("\(slot.timeStr) – \(slot.endTimeStr) (60 Min.)")
                    .font(.app(14, weight: .semibold))
                    .foregroundStyle(AppColor.primary)
            }
        }
    }

    // MARK: - Trainer Picker

    private var trainerIds: [String] {
        Array(Set(options.map(\.trainerId)))
    }

    private var trainerPicker: some View {
        Menu {
            ForEach(trainerIds, id: \.self) { tid in
                let name = trainerName(id: tid)
                Button(name) {
                    if selTrainerId != tid {
                        selTrainerId = tid
                        // Reset location if not available with new trainer
                        resetLocationIfNeeded(newTrainerId: tid)
                    }
                }
            }
        } label: {
            pickerRow(label: selTrainerId.flatMap { trainerName(id: $0) } ?? "Trainer wählen",
                      hasValue: selTrainerId != nil)
        }
    }

    // MARK: - Location Picker

    private var availableLocationIds: [String] {
        guard let tid = selTrainerId else { return calData.locations.map(\.id) }
        return calData.locations.map(\.id).filter { locId in
            isTrainerFreeForLocation(trainerId: tid, locationId: locId)
        }
    }

    private var locationPicker: some View {
        let locs = availableLocationIds
        return Menu {
            ForEach(locs, id: \.self) { lid in
                let name = locationName(id: lid)
                Button(name) { selLocationId = lid }
            }
        } label: {
            let current = selLocationId.flatMap { availableLocationIds.contains($0) ? $0 : nil }
            pickerRow(label: current.flatMap { locationName(id: $0) } ?? "Standort wählen",
                      hasValue: current != nil)
        }
        .disabled(locs.isEmpty)
    }

    // MARK: - Summary

    private func confirmSummary(trainerId: String, locationId: String) -> some View {
        VStack(spacing: 0) {
            confirmRow("Trainer", trainerName(id: trainerId))
            confirmRow("Ort",     locationName(id: locationId))
            confirmRow("Dauer",   "60 Min.")
            confirmRow("Credits", "1 Credit")
        }
        .padding(12)
        .background(AppColor.green.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.control)
            .stroke(AppColor.green.opacity(0.12), lineWidth: 1))
    }

    private func confirmRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.app(13))
                .foregroundStyle(AppColor.muted)
                .frame(width: 65, alignment: .leading)
            Text(value)
                .font(.app(13))
                .foregroundStyle(AppColor.text)
            Spacer()
        }
        .padding(.bottom, 6)
    }

    // MARK: - Action Row

    private var canConfirm: Bool { selTrainerId != nil && selLocationId != nil && availableLocationIds.contains(selLocationId ?? "") }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button("Abbrechen") { dismiss() }
                .foregroundStyle(AppColor.muted)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(AppColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))

            Button("Jetzt buchen") {
                guard let tid = selTrainerId, let lid = selLocationId else { return }
                let typeId = options.first(where: { $0.trainerId == tid })?.trainingTypeId
                onConfirm(SlotSelection(trainerId: tid, locationId: lid, trainingTypeId: typeId))
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canConfirm)
            .opacity(canConfirm ? 1 : 0.5)
        }
    }

    // MARK: - Helpers

    private func pickerLabel(_ text: String) -> some View {
        Text(text)
            .font(.app(12, weight: .semibold))
            .foregroundStyle(AppColor.muted)
            .padding(.bottom, 6)
    }

    private func pickerRow(label: String, hasValue: Bool) -> some View {
        HStack {
            Text(label)
                .font(.app(14))
                .foregroundStyle(hasValue ? AppColor.text : AppColor.muted)
            Spacer()
            Image(systemName: "chevron.down")
                .font(.app(13))
                .foregroundStyle(AppColor.muted)
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
        .background(AppColor.background)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.control).stroke(AppColor.border, lineWidth: 1))
    }

    private func trainerName(id: String) -> String {
        calData.trainers.first(where: { $0.id == id })?.fullName ?? id
    }

    private func locationName(id: String) -> String {
        calData.locations.first(where: { $0.id == id })?.name ?? id
    }

    private func isTrainerFreeForLocation(trainerId: String, locationId: String) -> Bool {
        guard let dateStr = selDateStr() else { return true }
        let startMin = slot.startMin; let endMin = startMin + 60
        let locBuffers = Dictionary(uniqueKeysWithValues: calData.locations.map { ($0.id, $0.bufferMinutes) })
        for b in calData.trainerBookings {
            guard b.trainerId == trainerId, b.date == dateStr,
                  b.status.lowercased() != "cancelled" else { continue }
            let parts = b.starttime.split(separator: ":").compactMap { Int($0) }
            guard parts.count >= 2 else { continue }
            let bStart = parts[0] * 60 + parts[1]; let bEnd = bStart + b.duration
            let same = b.locationId == locationId
            let buf  = same ? 0 : max(locBuffers[locationId] ?? 30, locBuffers[b.locationId ?? ""] ?? 30)
            if startMin < bEnd + buf && bStart < endMin + buf { return false }
        }
        return true
    }

    private func resetLocationIfNeeded(newTrainerId: String) {
        guard let current = selLocationId else { return }
        if !isTrainerFreeForLocation(trainerId: newTrainerId, locationId: current) {
            let avail = availableLocationIds
            locationWasReset = true
            selLocationId = avail.count == 1 ? avail.first : nil
        }
    }

    private func selDateStr() -> String? {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: day)
        guard let y = c.year, let m = c.month, let d = c.day else { return nil }
        return String(format: "%04d-%02d-%02d", y, m, d)
    }
}
