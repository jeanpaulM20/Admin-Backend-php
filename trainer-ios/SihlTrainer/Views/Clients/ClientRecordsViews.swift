import SwiftUI

/// Dateien im Kundendossier. Pendant zu `screens/client_files_screen.dart`.
/// Hochladen und Versenden folgen — hier zunächst Einsicht und Öffnen.
struct ClientFilesView: View {
    let client: Client
    let isPreview: Bool

    @State private var files: [ClientFile] = []
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        Group {
            if isLoading {
                LoadingState()
            } else if let error {
                MessageState(icon: "exclamationmark.triangle", title: "Dateien nicht geladen", message: error)
            } else if files.isEmpty {
                MessageState(icon: "doc", title: "Keine Dateien",
                             message: "Für \(client.name) sind keine Dateien hinterlegt.")
            } else {
                List(files) { file in
                    row(file)
                        .listRowBackground(AppColor.background)
                        .listRowSeparatorTint(AppColor.border)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(AppColor.background)
        .navigationTitle("Dateien")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder private func row(_ file: ClientFile) -> some View {
        // Der Download läuft über den Browser, weil der Link den Token als
        // Query-Parameter trägt — der APIClient ist dafür nicht zuständig.
        let url = file.downloadURL(token: KeychainStore.get(AuthService.tokenKey))
        HStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.app(15))
                .foregroundStyle(AppColor.primary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.app(15))
                    .foregroundStyle(AppColor.text)
                    .lineLimit(1)
                if let date = file.date {
                    Text(date)
                        .font(.app(12))
                        .foregroundStyle(AppColor.muted)
                }
            }
            Spacer(minLength: 0)
            if let url {
                Link(destination: url) {
                    Image(systemName: "arrow.down.circle")
                        .foregroundStyle(AppColor.primary)
                }
            }
        }
        .padding(.vertical, 3)
    }

    private func load() async {
        defer { isLoading = false }
        #if DEBUG
        if isPreview {
            files = PreviewData.files
            return
        }
        #endif
        do {
            files = try await ClientRecordsService().files(clientId: client.id)
        } catch let apiError as APIError {
            error = apiError.message
        } catch {
            self.error = "Dateien konnten nicht geladen werden"
        }
    }
}

/// Anamnesebogen zur Einsicht. Pendant zu `screens/anamnese_screen.dart`;
/// ausgefüllt wird der Bogen weiterhin vom Kunden.
struct AnamneseView: View {
    let client: Client
    let isPreview: Bool

    @State private var anamnese: Anamnese?
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        Group {
            if isLoading {
                LoadingState()
            } else if let error {
                MessageState(icon: "exclamationmark.triangle", title: "Anamnese nicht geladen", message: error)
            } else if let anamnese {
                content(anamnese)
            } else {
                MessageState(icon: "list.clipboard", title: "Kein Bogen",
                             message: "\(client.name) hat den Anamnesebogen noch nicht ausgefüllt.")
            }
        }
        .background(AppColor.background)
        .navigationTitle("Anamnese")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func content(_ data: Anamnese) -> some View {
        ScrollView {
            VStack(spacing: AppSpacing.stack) {
                section("Alltag", [
                    ("Beruf", data.profession),
                    ("Belastung", data.activityLabel),
                    ("Adresse", data.address),
                ])
                section("Sport", [
                    ("Sportarten", data.sports),
                    ("Umfang", data.sportsScope),
                    ("Schlaf Woche", data.sleepWeek.map { "\($0) h" }),
                    ("Schlaf Wochenende", data.sleepWeekend.map { "\($0) h" }),
                ])
                section("Ziele", [
                    ("Ziele", data.goals),
                    ("Bemerkungen", data.comments),
                ])
                healthCard(data)
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.bottom, AppSpacing.bottomInset)
        }
    }

    @ViewBuilder private func section(_ title: String, _ rows: [(String, String?)]) -> some View {
        let filled = rows.compactMap { label, value -> (String, String)? in
            guard let value, !value.isEmpty else { return nil }
            return (label, value)
        }
        if !filled.isEmpty {
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.app(13, weight: .semibold))
                        .foregroundStyle(AppColor.muted)
                    ForEach(filled, id: \.0) { label, value in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(label)
                                .font(.app(11))
                                .foregroundStyle(AppColor.muted)
                            Text(value)
                                .font(.app(14))
                                .foregroundStyle(AppColor.text)
                        }
                    }
                }
            }
        }
    }

    /// Gesundheitliches gebündelt — beim Trainieren ist das der Teil, auf den
    /// es ankommt, darum eigens hervorgehoben.
    @ViewBuilder private func healthCard(_ data: Anamnese) -> some View {
        let flags: [(String, Bool, String?)] = [
            ("Verletzung", data.injury, [data.injuryType, data.injuryBodypart].compactMap { $0 }.joined(separator: ", ")),
            ("Bewegungsapparat", data.musculoskeletalProblems, data.musculoskeletalDescription),
            ("In ärztlicher Behandlung", data.medicalTreatment, nil),
            ("Nimmt Medikamente", data.takingDrugs, nil),
        ].filter { $0.1 }

        if !flags.isEmpty || !data.diseases.isEmpty {
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Gesundheit")
                        .font(.app(13, weight: .semibold))
                        .foregroundStyle(AppColor.muted)
                    ForEach(flags, id: \.0) { label, _, detail in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.app(11))
                                .foregroundStyle(AppColor.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(label)
                                    .font(.app(14))
                                    .foregroundStyle(AppColor.text)
                                if let detail, !detail.isEmpty {
                                    Text(detail)
                                        .font(.app(12))
                                        .foregroundStyle(AppColor.muted)
                                }
                            }
                        }
                    }
                    if !data.diseases.isEmpty {
                        Text(data.diseases.joined(separator: " · "))
                            .font(.app(13))
                            .foregroundStyle(AppColor.brass)
                            .padding(.top, 2)
                    }
                }
            }
        }
    }

    private func load() async {
        defer { isLoading = false }
        #if DEBUG
        if isPreview {
            anamnese = PreviewData.anamnese
            return
        }
        #endif
        do {
            anamnese = try await ClientRecordsService().anamnese(clientId: client.id)
        } catch let apiError as APIError {
            error = apiError.message
        } catch {
            self.error = "Anamnese konnte nicht geladen werden"
        }
    }
}

/// Leistungstests und Messwerte. Pendant zu `screens/performance_screen.dart`;
/// das Erfassen neuer Werte folgt.
struct PerformanceView: View {
    let client: Client
    let isPreview: Bool

    @State private var tests: [PerformanceTest] = []
    @State private var metrics: [MetricEntry] = []
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        Group {
            if isLoading {
                LoadingState()
            } else if let error {
                MessageState(icon: "exclamationmark.triangle", title: "Daten nicht geladen", message: error)
            } else if tests.isEmpty && metrics.isEmpty {
                MessageState(icon: "chart.line.uptrend.xyaxis", title: "Keine Werte",
                             message: "Für \(client.name) sind keine Tests und Messwerte erfasst.")
            } else {
                content
            }
        }
        .background(AppColor.background)
        .navigationTitle("Leistung")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: AppSpacing.stack) {
                ForEach(metrics.prefix(3)) { metric in
                    metricCard(metric)
                }
                ForEach(tests.prefix(3)) { test in
                    testCard(test)
                }
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.bottom, AppSpacing.bottomInset)
        }
    }

    private func metricCard(_ metric: MetricEntry) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                header("Messwerte", date: metric.recordedAt)
                ForEach(metric.values, id: \.0) { label, value in
                    HStack {
                        Text(label)
                            .font(.app(14))
                            .foregroundStyle(AppColor.text)
                        Spacer(minLength: 0)
                        Text(value)
                            .font(.app(14, weight: .semibold))
                            .foregroundStyle(AppColor.brass)
                    }
                }
            }
        }
    }

    private func testCard(_ test: PerformanceTest) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    header("Leistungstest", date: test.recordedAt)
                    Spacer(minLength: 0)
                    if let points = test.points, points > 0 {
                        Text("\(Int(points)) Punkte")
                            .font(.app(13, weight: .semibold))
                            .foregroundStyle(AppColor.primary)
                    }
                }
                ForEach(test.groups, id: \.title) { group in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.title)
                            .font(.app(11, weight: .semibold))
                            .foregroundStyle(AppColor.brass)
                        ForEach(group.values, id: \.0) { label, value in
                            HStack {
                                Text(label)
                                    .font(.app(13))
                                    .foregroundStyle(AppColor.text)
                                Spacer(minLength: 0)
                                Text(value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value))
                                    .font(.app(13, weight: .semibold))
                                    .foregroundStyle(AppColor.text)
                            }
                        }
                    }
                }
            }
        }
    }

    private func header(_ title: String, date: Date?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.app(13, weight: .semibold))
                .foregroundStyle(AppColor.muted)
            if let date {
                Text(ReviewFormatters.date.string(from: date))
                    .font(.app(11))
                    .foregroundStyle(AppColor.muted)
            }
        }
    }

    private func load() async {
        defer { isLoading = false }
        #if DEBUG
        if isPreview {
            tests = PreviewData.performanceTests
            metrics = PreviewData.metrics
            return
        }
        #endif
        let service = ClientRecordsService()
        do {
            async let tests = service.performanceTests(clientId: client.id)
            async let metrics = service.metrics(clientId: client.id)
            self.tests = try await tests
            self.metrics = try await metrics
        } catch let apiError as APIError {
            error = apiError.message
        } catch {
            self.error = "Daten konnten nicht geladen werden"
        }
    }
}
