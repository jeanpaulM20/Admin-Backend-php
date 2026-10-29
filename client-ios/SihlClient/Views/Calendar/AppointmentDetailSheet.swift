import SwiftUI
import QuickLook

/// Detail-Sheet für einen bestehenden Termin — Pendant zu `_showAppointmentDetail` in
/// `calendar_screen.dart`. Zeigt Infos + Buttons: "Zum Kalender" + "Absagen".
struct AppointmentDetailSheet: View {
    let appointment: Appointment
    /// Wird vor dem Schliessen aufgerufen; der Aufrufer zeigt den Absage-Dialog
    /// erst nach dem Schliessen des Sheets (onDismiss).
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    /// Lokal gespeicherte .ics-Datei (per Header-Auth geladen, kein Token in der URL).
    @State private var icsFile: URL?
    /// QuickLook zeigt die .ics als Termin mit „Zum Kalender hinzufügen" —
    /// das Teilen-Menü böte keine Kalender-Aktion
    @State private var icsPreview: URL?
    @State private var icsFailed = false

    private static let longDateFmt = ZurichTime.displayFormatter("EEEE, d. MMMM yyyy")
    private static let timeFmt     = ZurichTime.time

    private var isCancelled: Bool { appointment.status.lowercased() == "cancelled" }
    private var isAttended:  Bool { appointment.status.lowercased() == "attended" }
    private var isMissed:    Bool { appointment.status.lowercased() == "missed" }
    /// Nur kommende Termine lassen sich absagen (das Backend prüft dasselbe).
    private var canCancel:   Bool { !isCancelled && !isAttended && !isMissed && appointment.startDate > Date() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Title row
                    HStack(alignment: .top) {
                        Text(appointment.trainingTypeName.isEmpty
                             ? "Training" : appointment.trainingTypeName)
                            .font(.app(18, weight: .bold))
                            .foregroundStyle(isCancelled ? AppColor.muted : AppColor.text)
                            .strikethrough(isCancelled)
                        Spacer()
                        statusBadge
                    }
                    .padding(.bottom, 14)

                    // Detail rows
                    VStack(alignment: .leading, spacing: 10) {
                        detailRow("calendar",
                                  "Datum",
                                  Self.longDateFmt.string(from: appointment.startDate))

                        let end = appointment.startDate.addingTimeInterval(TimeInterval(appointment.duration * 60))
                        detailRow("clock",
                                  "Uhrzeit",
                                  "\(Self.timeFmt.string(from: appointment.startDate)) – \(Self.timeFmt.string(from: end)) (\(appointment.duration) Min.)")

                        if !appointment.trainerName.isEmpty {
                            detailRow("person", "Trainer", appointment.trainerName)
                        }
                        if !appointment.locationName.isEmpty {
                            detailRow("mappin", "Ort", appointment.locationName)
                        }
                        if let plan = appointment.trainingPlanName, !plan.isEmpty {
                            detailRow("dumbbell", "Trainingsplan", plan)
                        }
                    }
                    .padding(.bottom, 20)

                    // Buttons
                    HStack(spacing: 10) {
                        // "Zum Kalender" — teilt die vorab geladene .ics-Datei
                        calendarButton

                        if canCancel {
                            Button {
                                onCancel()
                                dismiss()
                            } label: {
                                Label("Absagen", systemImage: "xmark.circle")
                                    .font(.app(14, weight: .medium))
                                    .foregroundStyle(AppColor.red)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .overlay(RoundedRectangle(cornerRadius: AppRadius.control)
                                        .stroke(AppColor.red, lineWidth: 1))
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .background(AppColor.background.ignoresSafeArea())
            .navigationTitle("Termin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                        .foregroundStyle(AppColor.primary)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .task { await loadICS() }
    }

    // MARK: - Kalender-Button

    @ViewBuilder
    private var calendarButton: some View {
        if let icsFile {
            Button { icsPreview = icsFile } label: {
                calendarLabel("Kalender")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Termin in Kalender übernehmen")
            .quickLookPreview($icsPreview)
        } else if icsFailed {
            Button {
                Task { await loadICS() }
            } label: {
                calendarLabel("Erneut laden")
            }
            .accessibilityLabel("Kalenderdatei erneut laden")
        } else {
            calendarLabel("Kalender")
                .opacity(0.5)
                .overlay { ProgressView().tint(AppColor.primary) }
                .accessibilityLabel("Kalenderdatei wird geladen")
        }
    }

    private func calendarLabel(_ title: String) -> some View {
        Label(title, systemImage: "calendar.badge.plus")
            .font(.app(14, weight: .medium))
            .foregroundStyle(AppColor.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .overlay(RoundedRectangle(cornerRadius: AppRadius.control)
                .stroke(AppColor.primary, lineWidth: 1))
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        let (label, color): (String, Color) = {
            switch appointment.status.lowercased() {
            case "cancelled": return ("Abgesagt",   AppColor.red)
            case "attended":  return ("Absolviert", AppColor.green)
            case "missed":    return ("Verpasst",   AppColor.orange)
            default:          return ("Gebucht",    AppColor.primary)
            }
        }()
        return Text(label)
            .font(.app(11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.control).stroke(color.opacity(0.24), lineWidth: 1))
    }

    // MARK: - Detail Row

    private func detailRow(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.app(14))
                .foregroundStyle(AppColor.muted)
                .frame(width: 16)
            Text(label)
                .font(.app(13))
                .foregroundStyle(AppColor.muted)
                .frame(width: 65, alignment: .leading)
            Text(value)
                .font(.app(14))
                .foregroundStyle(AppColor.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - iCal

    /// Lädt die .ics per `APIClient` (Token im Header) und legt sie als
    /// temporäre Datei ab — Safari-Aufruf mit `?token=` entfällt.
    private func loadICS() async {
        icsFailed = false
        do {
            let data = try await APIClient.shared.get("api/training/\(appointment.id)/ical")
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("SIHLMOVE-Termin-\(appointment.id).ics")
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            icsFile = url
        } catch {
            if !Task.isCancelled { icsFailed = true }
        }
    }
}
