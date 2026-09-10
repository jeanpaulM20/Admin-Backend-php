import SwiftUI

// MARK: - CalendarSyncView

/// Kalender-Zusammenführung, Phase 1.
///
/// Outlook wird nur gelesen, Google nur beschrieben: Jeder Klinik-Termin
/// erscheint als neutraler Sperreintrag im Google-Kalender, worauf die
/// Terminplanung auf der Website diese Zeit selbst ausblendet. Aus Outlook
/// wandert dabei ausschliesslich die Zeit — keine Betreffs, keine Namen.
struct CalendarSyncView: View {
    let trainerId: Int

    @State private var status: CalendarStatus?
    @State private var isLoading = true
    @State private var busyProvider: String?
    @State private var isSyncing = false
    @State private var message: String?
    @State private var messageIsError = false
    @State private var confirmDisconnect: String?

    // Phase 2: abonnierte Fremdkalender
    @State private var feeds: [CalendarFeed] = []
    @State private var showAddFeed = false
    @State private var confirmRemoveFeed: CalendarFeed?

    @Environment(\.openURL) private var openURL

    private let service = CalendarConnectionService()

    private var bothConnected: Bool {
        (status?.google.connected ?? false) && (status?.microsoft.connected ?? false)
    }

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: AppSpacing.stack) {
                    explainer

                    if isLoading {
                        ProgressView().tint(AppColor.primary).padding(.top, 32)
                    } else if let status {
                        providerCard(
                            provider: "microsoft",
                            title: "Outlook",
                            subtitle: "Termine der Klinik",
                            note: "Wird nur gelesen — die App schreibt nie hinein.",
                            icon: "building.2",
                            link: status.microsoft
                        )
                        providerCard(
                            provider: "google",
                            title: "Google Kalender",
                            subtitle: "Belegung für die Website",
                            note: "Hier entstehen die Sperreinträge.",
                            icon: "calendar",
                            link: status.google
                        )

                        if bothConnected { syncCard }
                    }

                    feedsSection

                    Spacer(minLength: 12)
                }
                .padding(.horizontal, AppSpacing.screen)
                .padding(.top, AppSpacing.stack)
                .padding(.bottom, AppSpacing.bottomInset)
            }
        }
        .navigationTitle("Kalender")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showAddFeed) {
            AddCalendarFeedSheet(trainerId: trainerId) {
                Task { await load() }
            }
        }
        .alert("Abo entfernen?", isPresented: Binding(
            get: { confirmRemoveFeed != nil },
            set: { if !$0 { confirmRemoveFeed = nil } }
        ), presenting: confirmRemoveFeed) { feed in
            Button("Abbrechen", role: .cancel) {}
            Button("Entfernen", role: .destructive) {
                Task { await removeFeed(feed) }
            }
        } message: { feed in
            Text("„\(feed.label)“ wird nicht mehr gelesen. Bereits gespiegelte Sperreinträge verschwinden beim nächsten Abgleich.")
        }
        .alert(messageIsError ? "Fehlgeschlagen" : "Erledigt",
               isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
        .alert("Verbindung trennen?", isPresented: Binding(
            get: { confirmDisconnect != nil },
            set: { if !$0 { confirmDisconnect = nil } }
        ), presenting: confirmDisconnect) { provider in
            Button("Abbrechen", role: .cancel) {}
            Button("Trennen", role: .destructive) {
                Task { await disconnect(provider) }
            }
        } message: { provider in
            Text(provider == "google"
                 ? "Bereits angelegte Sperreinträge bleiben im Kalender stehen und müssen dort von Hand entfernt werden."
                 : "Die Termine der Klinik sperren danach keine Zeiten mehr.")
        }
    }

    // MARK: Abonnierte Kalender

    /// Fremdkalender per iCal-Adresse — unabhängig davon, ob das andere
    /// Studio Google, Outlook oder etwas ganz anderes benutzt.
    private var feedsSection: some View {
        Card {
            VStack(alignment: .leading, spacing: AppSpacing.stack) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Abonnierte Kalender")
                            .font(.app(15, weight: .semibold))
                            .foregroundStyle(AppColor.text)
                        Text("Termine anderer Studios sperren deine Zeit")
                            .font(.app(12))
                            .foregroundStyle(AppColor.muted)
                    }
                    Spacer(minLength: 0)
                    Button {
                        showAddFeed = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.app(20))
                            .foregroundStyle(AppColor.primary)
                    }
                    .accessibilityLabel("Kalender abonnieren")
                }

                if feeds.isEmpty {
                    Text("Noch kein Kalender abonniert. Du brauchst dafür die iCal-Adresse des anderen Studios.")
                        .font(.app(13))
                        .foregroundStyle(AppColor.muted)
                } else {
                    ForEach(feeds) { feed in
                        feedRow(feed)
                        if feed.id != feeds.last?.id {
                            Divider().overlay(AppColor.border)
                        }
                    }
                }
            }
        }
    }

    private func feedRow(_ feed: CalendarFeed) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: feed.lastError == nil ? "calendar.badge.checkmark" : "exclamationmark.triangle")
                .font(.app(15))
                .foregroundStyle(feed.lastError == nil ? AppColor.green : AppColor.orange)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(feed.label)
                    .font(.app(14, weight: .semibold))
                    .foregroundStyle(AppColor.text)
                Text(feed.source)
                    .font(.app(11))
                    .foregroundStyle(AppColor.muted)
                    .lineLimit(1)
                if let error = feed.lastError {
                    Text(error)
                        .font(.app(11))
                        .foregroundStyle(AppColor.orange)
                } else {
                    Text("\(feed.eventCount) Termine übernommen")
                        .font(.app(11))
                        .foregroundStyle(AppColor.brass)
                }
            }
            Spacer(minLength: 0)
            Button {
                confirmRemoveFeed = feed
            } label: {
                Image(systemName: "trash")
                    .font(.app(13))
                    .foregroundStyle(AppColor.red)
            }
            .accessibilityLabel("Abo entfernen")
        }
        .padding(.vertical, 2)
    }

    private func removeFeed(_ feed: CalendarFeed) async {
        do {
            try await CalendarFeedService().remove(trainerId: trainerId, feedId: feed.id)
            await load()
        } catch let error as APIError {
            show(error.message, isError: true)
        } catch {
            show("Abo konnte nicht entfernt werden.", isError: true)
        }
    }

    // MARK: Bausteine

    private var explainer: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("So greifen die Kalender ineinander")
                    .font(.app(15, weight: .bold))
                    .foregroundStyle(AppColor.text)
                Text("Die Klinik trägt ihre Termine wie gewohnt in Outlook ein. Die App übernimmt daraus die belegten Zeiten in deinen Google-Kalender — und weil die Terminplanung auf deiner Website gegen genau diesen Kalender prüft, sind die Zeiten dort automatisch vergeben.")
                    .font(.app(13))
                    .foregroundStyle(AppColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func providerCard(provider: String, title: String, subtitle: String,
                              note: String, icon: String, link: CalendarLink) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.app(16))
                        .foregroundStyle(link.connected ? AppColor.primary : AppColor.muted)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.app(15, weight: .semibold)).foregroundStyle(AppColor.text)
                        Text(link.connected ? (link.accountEmail ?? "verbunden") : subtitle)
                            .font(.app(12))
                            .foregroundStyle(link.connected ? AppColor.primary : AppColor.muted)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if link.connected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.app(17)).foregroundStyle(AppColor.primary)
                    }
                }

                Text(note)
                    .font(.app(12))
                    .foregroundStyle(AppColor.muted)
                    .fixedSize(horizontal: false, vertical: true)

                if let error = link.lastSyncError {
                    Text(error)
                        .font(.app(12))
                        .foregroundStyle(AppColor.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !link.available {
                    Text("Auf dem Server noch nicht eingerichtet.")
                        .font(.app(12))
                        .foregroundStyle(AppColor.orange)
                } else if link.connected {
                    Button("Verbindung trennen") { confirmDisconnect = provider }
                        .font(.app(13))
                        .foregroundStyle(AppColor.muted)
                } else {
                    Button {
                        Task { await connect(provider) }
                    } label: {
                        HStack(spacing: 6) {
                            if busyProvider == provider {
                                ProgressView().tint(AppColor.white).scaleEffect(0.8)
                            }
                            Text("\(title) verbinden").font(.app(14, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(AppColor.primary, in: RoundedRectangle(cornerRadius: AppRadius.control))
                        .foregroundStyle(AppColor.white)
                    }
                    .disabled(busyProvider != nil)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var syncCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Abgleich")
                    .font(.app(15, weight: .bold))
                    .foregroundStyle(AppColor.text)
                Text(lastSyncText)
                    .font(.app(12))
                    .foregroundStyle(AppColor.muted)
                Text("Läuft automatisch alle 15 Minuten.")
                    .font(.app(12))
                    .foregroundStyle(AppColor.muted)

                Button {
                    Task { await syncNow() }
                } label: {
                    HStack(spacing: 6) {
                        if isSyncing {
                            ProgressView().tint(AppColor.primary).scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath").font(.app(13))
                        }
                        Text("Jetzt abgleichen").font(.app(14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(AppColor.surface2, in: RoundedRectangle(cornerRadius: AppRadius.control))
                    .foregroundStyle(AppColor.primary)
                }
                .disabled(isSyncing)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var lastSyncText: String {
        guard let date = status?.microsoft.lastSyncAt else { return "Noch nicht abgeglichen." }
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_CH")
        f.dateFormat = "d. MMMM, HH:mm"
        return "Zuletzt abgeglichen: \(f.string(from: date))"
    }

    // MARK: Aktionen

    private func show(_ text: String, isError: Bool = false) {
        messageIsError = isError
        message = text
    }

    private func load() async {
        isLoading = status == nil
        // Verbindungen und Abos zusammen laden — beide gehören zur selben Seite.
        async let link = service.status(trainerId: trainerId)
        async let subscriptions = CalendarFeedService().feeds(trainerId: trainerId)
        status = try? await link
        feeds = (try? await subscriptions) ?? []
        isLoading = false
    }

    private func connect(_ provider: String) async {
        busyProvider = provider
        defer { busyProvider = nil }
        do {
            let url = try await service.connectURL(provider: provider, trainerId: trainerId)
            openURL(url)
        } catch let error as APIError {
            show(error.message, isError: true)
        } catch {
            show("Verbindung konnte nicht gestartet werden", isError: true)
        }
    }

    private func disconnect(_ provider: String) async {
        do {
            try await service.disconnect(provider: provider, trainerId: trainerId)
            await load()
            show("Verbindung getrennt")
        } catch {
            show("Trennen fehlgeschlagen", isError: true)
        }
    }

    private func syncNow() async {
        isSyncing = true
        defer { isSyncing = false }
        do {
            let changed = try await service.syncNow(trainerId: trainerId)
            await load()
            show(changed == 0 ? "Alles aktuell" : "\(changed) Sperrzeiten aktualisiert")
        } catch let error as APIError {
            show(error.message, isError: true)
        } catch {
            show("Abgleich fehlgeschlagen", isError: true)
        }
    }
}
