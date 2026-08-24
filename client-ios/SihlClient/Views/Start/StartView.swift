import SwiftUI

/// Pendant zu `screens/start_screen.dart`.
/// `onGoToCalendar` wird vom MainTabView übergeben, um auf Tab „Kalender" zu wechseln.
struct StartView: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(StartViewModel.self) private var vm

    var onGoToCalendar: (() -> Void)?

    // MARK: - Body

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()

            if auth.clientId == "demo" {
                DemoUnavailableView(message: "Die Startseite zeigt deinen persönlichen Trainingsstand.")
            } else if vm.isLoading {
                LoadingView(message: "Lade Daten…")
            } else if let err = vm.error {
                ErrorStateView(message: err) {
                    Task { await vm.load(clientId: auth.clientId ?? "") }
                }
            } else {
                contentScroll
            }
        }
        .task {
            if vm.startData == nil, let id = auth.clientId {
                await vm.load(clientId: id)
            }
        }
        .refreshable {
            if let id = auth.clientId {
                await vm.load(clientId: id)
            }
        }
    }

    // MARK: - Content

    private var contentScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.stack) {
                greeting

                DailyQuoteView(isLoading: vm.quoteLoading, quote: vm.quote)

                sectionHeader

                appointmentList
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.top, AppSpacing.card)
            .padding(.bottom, AppSpacing.bottomInset)
        }
    }

    // MARK: - Greeting

    private var greeting: some View {
        let hour = Calendar.current.component(.hour, from: Date())
        let greet = hour < 12 ? "Guten Morgen,"
                  : hour < 18 ? "Guten Tag,"
                  :             "Guten Abend,"
        let name = vm.startData?.firstName ?? ""

        return VStack(alignment: .leading, spacing: 4) {
            Text(greet)
                .font(.app(16))
                .foregroundStyle(AppColor.muted)
            Text(name.isEmpty ? "Willkommen!" : "\(name)!")
                .font(.app(28, weight: .heavy))
                .foregroundStyle(AppColor.text)
        }
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(AppColor.primary)
                .frame(width: 3, height: 20)

            Text("Nächste Termine")
                .font(.app(17, weight: .bold))
                .foregroundStyle(AppColor.text)

            Spacer()

            // Zähler nur, wenn es etwas zu zählen gibt — eine nackte "0"
            // neben dem Leerzustand wäre redundant und unlesbar
            if !upcomingAppointments.isEmpty {
                Text("\(upcomingAppointments.count)")
                    .font(.app(15, weight: .semibold))
                    .foregroundStyle(AppColor.muted)
            }
        }
    }

    // MARK: - Appointment List

    private var appointmentList: some View {
        let upcoming = upcomingAppointments
        return Group {
            if upcoming.isEmpty {
                // Die eine Hauptaktion der leeren Startseite → CTA-Stil
                EmptyStateView(
                    icon: "calendar",
                    message: "Du hast noch keine Termine geplant.",
                    actionTitle: onGoToCalendar != nil ? "Termin buchen" : nil,
                    action: onGoToCalendar,
                    prominentAction: true
                )
            } else {
                VStack(spacing: AppSpacing.stack) {
                    ForEach(upcoming) { appt in
                        AppointmentCard(appointment: appt)
                            .contentShape(Rectangle())
                            .onTapGesture { onGoToCalendar?() }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var upcomingAppointments: [Appointment] {
        let now = Date()
        return (vm.startData?.appointments ?? [])
            .filter { $0.startDate > now }
            .sorted { $0.startDate < $1.startDate }
    }
}

// MARK: - Daily Quote

private struct DailyQuoteView: View {
    let isLoading: Bool
    let quote: DailyQuote?

    var body: some View {
        if isLoading {
            QuoteShimmer()
        } else if let q = quote {
            VStack(alignment: .leading, spacing: 4) {
                Text("„\(q.text)\u{201C}")
                    .font(.app(13))
                    .italic()
                    .foregroundStyle(AppColor.text.opacity(0.55))
                    .lineSpacing(4)
                Text("— \(q.author)")
                    .font(.app(11, weight: .medium))
                    .foregroundStyle(AppColor.muted)
            }
        }
        // nil + not loading → invisible (SizedBox equivalent)
    }
}

private struct QuoteShimmer: View {
    @State private var opacity: Double = 0.25

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 4)
                .fill(AppColor.surface2)
                .frame(maxWidth: .infinity, minHeight: 12, maxHeight: 12)
            RoundedRectangle(cornerRadius: 4)
                .fill(AppColor.surface2)
                .frame(width: 220, height: 12)
            RoundedRectangle(cornerRadius: 4)
                .fill(AppColor.surface2)
                .frame(width: 120, height: 10)
        }
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                opacity = 0.55
            }
        }
    }
}

// MARK: - Appointment Card

private struct AppointmentCard: View {
    let appointment: Appointment

    private static let dayFmt: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "de_CH"); f.dateFormat = "dd"; return f
    }()
    private static let monFmt: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "de_CH"); f.dateFormat = "MMM"; return f
    }()
    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "de_CH"); f.dateFormat = "EEE, d. MMM"; return f
    }()
    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()

    /// Bekannte Status deutsch und mit passender Farbe; Unbekanntes neutral.
    private static func statusBadge(_ status: String) -> (String, Color) {
        switch status.lowercased() {
        case "booked", "confirmed": return ("Gebucht", AppColor.green)
        case "cancelled", "canceled": return ("Abgesagt", AppColor.red)
        case "pending", "requested": return ("Angefragt", AppColor.brass)
        default: return (status, AppColor.muted)
        }
    }

    var body: some View {
        HStack(spacing: AppSpacing.stack) {
            // ── Date Bubble ──────────────────────────────────────────────────
            VStack(spacing: 1) {
                Text(Self.dayFmt.string(from: appointment.startDate))
                    .font(.app(18, weight: .heavy))
                    .foregroundStyle(AppColor.primary)
                Text(Self.monFmt.string(from: appointment.startDate))
                    .font(.app(10, weight: .semibold))
                    .foregroundStyle(AppColor.primary)
            }
            .frame(width: 50, height: 50)
            .background(AppColor.primary.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))

            // ── Details ──────────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                Text(appointment.trainingTypeName.isEmpty
                     ? "Training" : appointment.trainingTypeName)
                    .font(.app(15, weight: .bold))
                    .foregroundStyle(AppColor.text)

                Text("\(Self.timeFmt.string(from: appointment.startDate)) · \(appointment.duration) Min.")
                    .font(.app(12))
                    .foregroundStyle(AppColor.muted)

                if !appointment.trainerName.isEmpty {
                    Text(appointment.trainerName)
                        .font(.app(12))
                        .foregroundStyle(AppColor.muted)
                }
            }

            Spacer()

            // ── Status Badge — Sprache UND Farbe folgen dem Status ───────────
            let (label, color) = Self.statusBadge(appointment.status)
            Text(label)
                .font(.app(11, weight: .semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(AppSpacing.card)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
    }
}

// `LoadingView`, `ErrorStateView` und `EmptyStateView` leben in `Views/Shared/SharedComponents.swift`.
