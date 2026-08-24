import SwiftUI
import UIKit

/// Detail-Sheet für einen bestehenden Termin — Pendant zu `_showAppointmentDetail` in
/// `calendar_screen.dart`. Zeigt Infos + Buttons: "Zum Kalender" + "Absagen".
struct AppointmentDetailSheet: View {
    let appointment: Appointment
    let token: String?
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    private static let longDateFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "EEEE, d. MMMM yyyy"
        return f
    }()
    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()

    private var isCancelled: Bool { appointment.status.lowercased() == "cancelled" }
    private var isAttended:  Bool { appointment.status.lowercased() == "attended" }
    private var isMissed:    Bool { appointment.status.lowercased() == "missed" }
    private var canCancel:   Bool { !isCancelled && !isAttended && !isMissed }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Title row
                    HStack(alignment: .top) {
                        Text(appointment.trainingTypeName.isEmpty
                             ? "Training" : appointment.trainingTypeName)
                            .font(.system(size: 18, weight: .bold))
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
                        // "Zum Kalender" — lädt die iCal-URL
                        Button {
                            addToCalendar()
                            dismiss()
                        } label: {
                            Label("Kalender", systemImage: "calendar.badge.plus")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppColor.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .overlay(RoundedRectangle(cornerRadius: AppRadius.control)
                                    .stroke(AppColor.primary, lineWidth: 1))
                        }

                        if canCancel {
                            Button {
                                dismiss()
                                onCancel()
                            } label: {
                                Label("Absagen", systemImage: "xmark.circle")
                                    .font(.system(size: 14, weight: .medium))
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
            .font(.system(size: 11, weight: .semibold))
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
                .font(.system(size: 14))
                .foregroundStyle(AppColor.muted)
                .frame(width: 16)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(AppColor.muted)
                .frame(width: 65, alignment: .leading)
            Text(value)
                .font(.system(size: 14))
                .foregroundStyle(AppColor.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - iCal

    private func addToCalendar() {
        let base = APIConfig.baseURL.absoluteString
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var urlStr = "\(base)/api/training/\(appointment.id)/ical"
        if let t = token { urlStr += "?token=\(t)" }
        guard let url = URL(string: urlStr) else { return }
        UIApplication.shared.open(url)
    }
}
