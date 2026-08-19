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

            if vm.isLoading {
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
            VStack(alignment: .leading, spacing: 0) {
                greeting
                    .padding(.bottom, 16)

                DailyQuoteView(isLoading: vm.quoteLoading, quote: vm.quote)

                summaryRow
                    .padding(.bottom, 28)

                sectionHeader
                    .padding(.bottom, 16)

                appointmentList
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
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
                .font(.system(size: 16))
                .foregroundStyle(AppColor.muted)
            Text(name.isEmpty ? "Willkommen!" : "\(name)!")
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(AppColor.text)
        }
    }

    // MARK: - Summary

    private var summaryRow: some View {
        let upcoming = upcomingAppointments
        let next     = upcoming.first

        let nextLabel: String = {
            guard let appt = next else { return "–" }
            let df = DateFormatter()
            df.locale = Locale(identifier: "de_DE")
            df.dateFormat = "dd.MM.  HH:mm"
            return df.string(from: appt.startDate)
        }()

        return HStack(spacing: 12) {
            SummaryCard(icon: "calendar",
                        value: nextLabel,
                        label: "Nächster Termin")
                .frame(maxWidth: .infinity)
                .layoutPriority(3)

            SummaryCard(icon: "circle.grid.2x2",
                        value: "\(vm.startData?.totalCredits ?? 0)",
                        label: "Credits")
                .frame(maxWidth: .infinity)
                .layoutPriority(2)
        }
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(AppColor.primary)
                .frame(width: 3, height: 20)

            Text("Nächste Termine")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppColor.text)

            Spacer()

            Text("\(upcomingAppointments.count)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColor.muted)
        }
    }

    // MARK: - Appointment List

    private var appointmentList: some View {
        let upcoming = upcomingAppointments
        return Group {
            if upcoming.isEmpty {
                EmptyAppointmentsView(onBookNow: onGoToCalendar)
            } else {
                VStack(spacing: 10) {
                    ForEach(upcoming) { appt in
                        AppointmentCard(appointment: appt)
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
                Text("„\(q.text)"")
                    .font(.system(size: 13))
                    .italic()
                    .foregroundStyle(AppColor.text.opacity(0.55))
                    .lineSpacing(4)
                Text("— \(q.author)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColor.muted)
            }
            .padding(.bottom, 16)
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
        .padding(.bottom, 24)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                opacity = 0.55
            }
        }
    }
}

// MARK: - Summary Card

private struct SummaryCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(AppColor.muted)
                .padding(.bottom, 12)

            Text(value)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(AppColor.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.bottom, 4)

            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(AppColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Appointment Card

private struct AppointmentCard: View {
    let appointment: Appointment

    private static let dayFmt: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "de_DE"); f.dateFormat = "dd"; return f
    }()
    private static let monFmt: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "de_DE"); f.dateFormat = "MMM"; return f
    }()
    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "de_DE"); f.dateFormat = "EEE, d. MMM"; return f
    }()
    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()

    var body: some View {
        HStack(spacing: 14) {
            // ── Date Bubble ──────────────────────────────────────────────────
            VStack(spacing: 1) {
                Text(Self.dayFmt.string(from: appointment.startDate))
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(AppColor.primary)
                Text(Self.monFmt.string(from: appointment.startDate))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppColor.primary)
            }
            .frame(width: 50, height: 50)
            .background(AppColor.primary.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // ── Details ──────────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                Text(appointment.trainingTypeName.isEmpty
                     ? "Training" : appointment.trainingTypeName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppColor.text)

                Text("\(Self.timeFmt.string(from: appointment.startDate)) · \(appointment.duration) Min.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColor.muted)

                if !appointment.trainerName.isEmpty {
                    Text(appointment.trainerName)
                        .font(.system(size: 12))
                        .foregroundStyle(AppColor.muted)
                }
            }

            Spacer()

            // ── Status Badge ─────────────────────────────────────────────────
            let label = appointment.status == "booked" ? "Gebucht" : appointment.status
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppColor.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppColor.green.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(16)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Empty State

private struct EmptyAppointmentsView: View {
    let onBookNow: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 32)

            Image(systemName: "calendar")
                .font(.system(size: 32))
                .foregroundStyle(AppColor.muted)

            Text("Suche Dir einen passenden Termin aus.")
                .font(.system(size: 14))
                .foregroundStyle(AppColor.muted)
                .multilineTextAlignment(.center)

            if let onBookNow {
                Button(action: onBookNow) {
                    Text("Termin buchen")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppColor.primary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AppColor.primary, lineWidth: 1)
                        )
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Shared Helper Views (wiederverwendbar in anderen Screens)

/// Einfache Ladeanimation — Pendant zu `widgets/loading_indicator.dart`.
struct LoadingView: View {
    var message: String = "Laden…"
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(AppColor.primary)
                .scaleEffect(1.3)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(AppColor.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Fehler-Anzeige mit Retry — Pendant zu `widgets/error_view.dart`.
struct ErrorStateView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(AppColor.muted)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(AppColor.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button(action: onRetry) {
                Text("Erneut versuchen")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppColor.primary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppColor.primary, lineWidth: 1)
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
