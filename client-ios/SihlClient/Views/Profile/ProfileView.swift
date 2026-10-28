import QuickLook
import SwiftUI
import UIKit

/// Pendant zu `screens/profile_screen.dart`.
/// Geöffnet als NavigationDestination vom Profil-Avatar in MainTabView.
struct ProfileView: View {
    @AppStorage(TourAssistantConsent.storageKey) private var aiConsent = false
    @Environment(AuthViewModel.self)    private var auth
    @Environment(ProfileViewModel.self) private var vm

    @State private var selectedInvoice: Invoice?
    @State private var showLogoutAlert   = false
    @State private var showPolarDisconnectAlert = false
    @State private var showDeleteAccount = false
    @State private var toast: AppToast?
    @Environment(\.openURL) private var openURL

    // Dateien: lokale Kopie für die QuickLook-Vorschau
    @State private var previewURL: URL?
    @State private var openingFileId: String?

    // Push Notifications
    @State private var pushEnabled  = false
    @State private var pushLoading  = false
    @State private var pushDenied   = false   // true = User muss in Einstellungen aktivieren

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()

            if auth.clientId == "demo" {
                demoContent
            } else if vm.isLoading {
                LoadingView(message: "Lade Profil…")
            } else if let err = vm.error {
                // Auch ohne Profildaten muss man sich abmelden können
                VStack(spacing: 0) {
                    ErrorStateView(message: err) {
                        Task { await vm.load(clientId: auth.clientId ?? "") }
                    }
                    logoutButton
                        .padding(.horizontal, AppSpacing.screen)
                        .padding(.bottom, AppSpacing.bottomInset)
                }
            } else {
                content
            }
        }
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if vm.data == nil, let id = auth.clientId {
                await vm.load(clientId: id)
            }
            await refreshPushStatus()
        }
        .refreshable {
            if let id = auth.clientId { await vm.load(clientId: id) }
        }
        .sheet(item: $selectedInvoice) { invoice in
            InvoiceDetailSheet(invoice: invoice)
        }
        .sheet(isPresented: $showDeleteAccount) {
            DeleteAccountSheet(clientId: auth.clientId ?? "")
        }
        .quickLookPreview($previewURL)
        .alert("Abmelden", isPresented: $showLogoutAlert) {
            Button("Abbrechen", role: .cancel) {}
            Button("Abmelden", role: .destructive) {
                Task { await auth.logout() }
            }
        } message: {
            Text("Möchtest du dich wirklich abmelden?")
        }
        .alert("Polar trennen", isPresented: $showPolarDisconnectAlert) {
            Button("Abbrechen", role: .cancel) {}
            Button("Trennen", role: .destructive) {
                Task {
                    guard let id = auth.clientId else { return }
                    do {
                        try await vm.disconnectPolar(clientId: id)
                    } catch {
                        toast = AppToast(message: "Polar-Trennung fehlgeschlagen", style: .error)
                    }
                }
            }
        } message: {
            Text("Polar-Verbindung wirklich trennen?")
        }
        .appToast($toast)
    }

    // MARK: - Demo-Modus

    /// Im Demo fehlen nur Konto- und Vertragsdaten — die Sensoren bleiben
    /// erreichbar (Trainingspläne liegen im Start-Tab).
    private var demoContent: some View {
        ScrollView {
            VStack(spacing: AppSpacing.stack) {
                EmptyStateView(
                    icon: "person.crop.circle.badge.questionmark",
                    message: "Konto- und Vertragsdaten sind im Demo-Modus nicht verfügbar."
                )
                .padding(.vertical, 12)

                sensorsRow
                privacyRow

                Spacer(minLength: 24)
                logoutButton
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.top, 16)
            .padding(.bottom, AppSpacing.bottomInset)
        }
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            VStack(spacing: AppSpacing.stack) {
                avatarHeader
                    .padding(.bottom, 20)

                creditsSection
                creditsBuyRow
                invoicesSection
                filesSection
                connectionsSection
                if AppFeatures.glucose {
                    glucoseRow
                }

                sensorsRow
                notificationsSection
                privacyRow
                if aiConsent { aiConsentRow }
                deleteAccountRow

                Spacer(minLength: 24)
                logoutButton
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.top, 24)
            .padding(.bottom, AppSpacing.bottomInset)
        }
    }

    // MARK: - Avatar

    private var avatarHeader: some View {
        VStack(spacing: 16) {
            Circle()
                .fill(AppColor.primary)
                .frame(width: 90, height: 90)
                .overlay(
                    Text(vm.data?.initials ?? "?")
                        .font(.app(32, weight: .heavy))
                        .foregroundStyle(AppColor.white)
                )
            VStack(spacing: 4) {
                Text(vm.data?.fullName ?? "")
                    .font(.app(22, weight: .bold))
                    .foregroundStyle(AppColor.text)
                Text("Mitglied")
                    .font(.app(14))
                    .foregroundStyle(AppColor.muted)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Credits Section

    private var creditsSection: some View {
        SectionDisclosure(
            icon: "creditcard.fill",
            title: "Meine Lektionen",
            subtitle: vm.creditsSubtitle
        ) {
            if vm.activePacks.isEmpty {
                EmptyHint(text: "Keine aktiven Credit-Pakete")
            } else {
                ForEach(vm.activePacks) { pack in
                    CreditPackCard(pack: pack).padding(.bottom, 12)
                }
            }
            if !vm.expiredPacks.isEmpty {
                SectionDisclosure(
                    icon: "archivebox",
                    title: "Archiv",
                    subtitle: "\(vm.expiredPacks.count) abgelaufene Pakete"
                ) {
                    ForEach(vm.expiredPacks) { pack in
                        CreditPackCard(pack: pack).padding(.bottom, 12)
                    }
                }
            }
        }
    }

    // MARK: - Lektionen & Guthaben Row

    private var creditsBuyRow: some View {
        NavRow(icon: "cart", tint: AppColor.primary,
               title: "Lektionen & Guthaben", subtitle: "Pakete für Training im Studio") {
            CreditsView()
        }
    }

    // MARK: - Datenschutz & Konto löschen

    private var privacyRow: some View {
        Link(destination: AppLinks.privacy) {
            ProfileRowLabel(icon: "hand.raised.fill", tint: AppColor.primary,
                            title: "Datenschutz", subtitle: "So gehen wir mit deinen Daten um",
                            trailingIcon: "arrow.up.right")
        }
        .buttonStyle(.plain)
    }

    /// Erteilte KI-Einwilligung (Touren-Assistent) widerrufen. Danach fragt
    /// der Assistent vor der nächsten Nutzung erneut.
    private var aiConsentRow: some View {
        Button {
            aiConsent = false
        } label: {
            ProfileRowLabel(icon: "sparkles", tint: AppColor.brass,
                            title: "KI-Einwilligung widerrufen",
                            subtitle: "Touren-Assistent fragt beim nächsten Mal erneut",
                            trailingIcon: "xmark.circle")
        }
        .buttonStyle(.plain)
        .accessibilityHint("Widerruft die Zustimmung zur Übermittlung an den KI-Anbieter")
    }

    private var deleteAccountRow: some View {
        Button {
            showDeleteAccount = true
        } label: {
            ProfileRowLabel(icon: "person.crop.circle.badge.xmark", tint: AppColor.red,
                            title: "Konto löschen", subtitle: "Konto und Daten löschen lassen",
                            trailingIcon: "chevron.right")
        }
        .buttonStyle(.plain)
    }

    // MARK: - Blutzucker Row (CGM — ehemals Tab 6; max. 5 Tabs, s. MainTabView)

    private var glucoseRow: some View {
        NavRow(icon: "waveform.path.ecg", tint: AppColor.red,
               title: "Blutzucker", subtitle: "FreeStyle Libre CGM-Daten") {
            GlucoseView().navigationTitle("Blutzucker")
        }
    }

    // MARK: - Sensoren (aus dem Aufzeichnungs-Screen hierher verschoben)

    private var sensorsRow: some View {
        NavRow(icon: "sensor.tag.radiowaves.forward", tint: AppColor.primary,
               title: "Sensoren", subtitle: "Herzfrequenz-Gurt und Standort") {
            SensorSettingsView()
        }
    }

    // MARK: - Invoices Section

    private var invoicesSection: some View {
        SectionDisclosure(
            icon: "doc.text.fill",
            title: "Rechnungen",
            subtitle: vm.countLabel(vm.invoices.count, "Rechnung", "Rechnungen")
        ) {
            if vm.invoices.isEmpty {
                EmptyHint(text: "Keine Rechnungen vorhanden")
            } else {
                ForEach(vm.invoices) { inv in
                    InvoiceRow(invoice: inv)
                        .onTapGesture { selectedInvoice = inv }
                        .padding(.bottom, 10)
                }
            }
        }
    }

    // MARK: - Files Section

    private var filesSection: some View {
        SectionDisclosure(
            icon: "folder.fill",
            title: "Dateien",
            subtitle: vm.countLabel(vm.files.count, "Datei", "Dateien")
        ) {
            if vm.files.isEmpty {
                EmptyHint(text: "Keine Dateien vorhanden")
            } else {
                ForEach(vm.files) { file in
                    FileRow(file: file, loading: openingFileId == file.id) {
                        open(file)
                    }
                    .padding(.bottom, 8)
                }
            }
        }
    }

    /// Eigene Dateien mit Header-Auth laden und in QuickLook zeigen —
    /// kein Token in der URL (Safari-Verlauf, Server-Logs).
    private func open(_ file: ClientFile) {
        if let url = file.externalURL {
            openURL(url)
            return
        }
        guard file.downloadPath != nil, openingFileId == nil else { return }
        openingFileId = file.id
        Task {
            defer { openingFileId = nil }
            do {
                previewURL = try await vm.downloadFile(file)
            } catch {
                let message = (error as? APIError)?.message ?? "Datei konnte nicht geladen werden"
                withAnimation { toast = AppToast(message: message, style: .error) }
            }
        }
    }

    // MARK: - Verbindungen (Polar)

    private var connectionsSection: some View {
        SectionDisclosure(
            icon: "link",
            title: "Verbindungen",
            subtitle: vm.polarConnected ? "Polar verbunden" : nil
        ) {
            PolarCard(
                available: vm.polarAvailable,
                connected: vm.polarConnected,
                loading: vm.polarLoading,
                lastSync: vm.polarLastSync,
                onSync: {
                    Task {
                        guard let id = auth.clientId else { return }
                        do {
                            let message = try await vm.syncPolar(clientId: id)
                            withAnimation { toast = AppToast(message: message, style: .success) }
                        } catch {
                            let message = (error as? APIError)?.message ?? "Polar-Abgleich fehlgeschlagen"
                            withAnimation { toast = AppToast(message: message, style: .error) }
                        }
                    }
                },
                onDisconnect: { showPolarDisconnectAlert = true },
                onConnect: vm.polarConnectUrl == nil ? nil : {
                    Task {
                        guard let id = auth.clientId else { return }
                        if let message = await vm.connectPolar(clientId: id) {
                            withAnimation { toast = AppToast(message: message, style: .error) }
                        } else if vm.polarConnected {
                            withAnimation { toast = AppToast(message: "Polar verbunden", style: .success) }
                        }
                    }
                }
            )
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        SectionDisclosure(
            icon: "bell.fill",
            title: "Benachrichtigungen",
            subtitle: pushDenied ? "In iOS ausgeschaltet" : (pushEnabled ? "Push eingeschaltet" : "Push ausgeschaltet")
        ) {
            PushNotificationCard(
                enabled:   pushEnabled,
                loading:   pushLoading,
                denied:    pushDenied,
                onToggle: { enable in
                    Task { await togglePush(enable: enable) }
                }
            )
        }
    }

    private func refreshPushStatus() async {
        let status = await PushNotificationService.shared.authorizationStatus()
        pushDenied  = (status == .denied)
        pushEnabled = await PushNotificationService.shared.isEnabled
    }

    private func togglePush(enable: Bool) async {
        guard let id = auth.clientId else { return }
        pushLoading = true
        if enable {
            if pushDenied {
                // User muss selbst in Einstellungen gehen
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    await UIApplication.shared.open(url)
                }
            } else {
                let ok = await PushNotificationService.shared.requestAndRegister(clientId: id)
                pushEnabled = ok
                await refreshPushStatus()
            }
        } else {
            await PushNotificationService.shared.disable(clientId: id)
            pushEnabled = false
            await refreshPushStatus()
        }
        pushLoading = false
    }

    // MARK: - Logout

    private var logoutButton: some View {
        Button {
            showLogoutAlert = true
        } label: {
            HStack(spacing: 8) {
                // Abmelden meldet erst Push beim Server ab (bis 8 s bei
                // schlechtem Netz) — darum sichtbar „läuft"
                if auth.isLoggingOut {
                    ProgressView().tint(AppColor.red)
                } else {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.app(16))
                }
                Text(auth.isLoggingOut ? "Wird abgemeldet …" : "Abmelden")
                    .font(.app(15, weight: .semibold))
            }
            .foregroundStyle(AppColor.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.control)
                    .stroke(AppColor.red.opacity(0.47), lineWidth: 1)
            )
        }
        .disabled(auth.isLoggingOut)
    }
}

// MARK: - Collapsible Section

/// Wiederverwendbare aufklappbare Sektion — Pendant zu Flutter `_SectionTile` (ExpansionTile).
struct SectionDisclosure<Content: View>: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var tint: Color = AppColor.primary
    @ViewBuilder let content: () -> Content

    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Header / Tap-Target
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(spacing: ProfileGrid.gap) {
                    ProfileIconTile(icon: icon, tint: tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.app(15, weight: .bold))
                            .foregroundStyle(AppColor.text)
                        if let subtitle {
                            Text(subtitle)
                                .font(.app(12))
                                .foregroundStyle(AppColor.muted)
                        }
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.app(14))
                        .foregroundStyle(AppColor.muted)
                }
                .padding(.horizontal, AppSpacing.card)
                .padding(.vertical, ProfileGrid.rowVertical)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(expanded ? "Zuklappen" : "Aufklappen")

            // Body
            if expanded {
                Divider().background(AppColor.border)
                VStack(spacing: 0) {
                    content()
                }
                .padding(.horizontal, AppSpacing.card)
                .padding(.vertical, ProfileGrid.bodyVertical)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.border, lineWidth: 1))
    }
}

// MARK: - Credit Pack Card

private struct CreditPackCard: View {
    let pack: CreditPack

    var body: some View {
        VStack(alignment: .leading, spacing: ProfileGrid.gap) {
            HStack(spacing: ProfileGrid.gap) {
                ProfileIconTile(icon: "creditcard", tint: AppColor.primary)
                Text(pack.title)
                    .font(.app(14, weight: .bold))
                    .foregroundStyle(AppColor.text)
                Spacer()
                Text("\(pack.remainingCredits) / \(pack.prepaidCredits)")
                    .font(.app(13, weight: .bold))
                    .foregroundStyle(AppColor.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppColor.primary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
            }

            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AppColor.surface2)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AppColor.primary)
                        .frame(width: geo.size.width * pack.fraction, height: 6)
                }
            }
            .frame(height: 6)
            // Balken bündig mit dem Titel, nicht mit der Kachel
            .padding(.leading, ProfileGrid.tile + ProfileGrid.gap)
        }
        .padding(.vertical, ProfileGrid.itemVertical)
    }
}

// MARK: - Invoice Row

private struct InvoiceRow: View {
    let invoice: Invoice

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "dd.MM.yyyy"; return f
    }()

    var body: some View {
        let isPaid = invoice.isPaid
        let color: Color = isPaid ? AppColor.green : AppColor.primary

        HStack(spacing: ProfileGrid.gap) {
            ProfileIconTile(icon: "receipt", tint: AppColor.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Rechnung \(invoice.invoiceNumber)")
                    .font(.app(14, weight: .bold))
                    .foregroundStyle(AppColor.text)
                if let d = invoice.transactionDate {
                    Text(Self.dateFmt.string(from: d))
                        .font(.app(12))
                        .foregroundStyle(AppColor.muted)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(invoice.amountFormatted)
                    .font(.app(16, weight: .heavy))
                    .foregroundStyle(AppColor.text)
                Text(isPaid ? "Bezahlt" : "Offen")
                    .font(.app(11, weight: .bold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
            }

            Image(systemName: "chevron.right")
                .font(.app(14))
                .foregroundStyle(AppColor.muted)
        }
        .padding(.vertical, ProfileGrid.itemVertical)
        .contentShape(Rectangle())
    }
}

// MARK: - File Row

private struct FileRow: View {
    let file: ClientFile
    let loading: Bool
    let onOpen: () -> Void

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "dd.MM.yyyy"; return f
    }()

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: ProfileGrid.gap) {
                ProfileIconTile(icon: "doc.fill", tint: AppColor.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name)
                        .font(.app(14, weight: .bold))
                        .foregroundStyle(AppColor.text)
                    Text(file.date.map { Self.dateFmt.string(from: $0) } ?? "-")
                        .font(.app(12))
                        .foregroundStyle(AppColor.muted)
                }
                Spacer()
                if loading {
                    ProgressView().tint(AppColor.primary)
                } else if file.hasUrl {
                    Image(systemName: file.externalURL != nil ? "arrow.up.right.square" : "eye")
                        .font(.app(16))
                        .foregroundStyle(AppColor.primary)
                }
            }
            .padding(.vertical, ProfileGrid.itemVertical)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!file.hasUrl || loading)
    }
}

// MARK: - Profil-Zeile (Link/Aktion)

/// Optik wie `NavRow`, aber für Links und Aktionen statt Navigation.
private struct ProfileRowLabel: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    let trailingIcon: String

    var body: some View {
        HStack(spacing: ProfileGrid.gap) {
            ProfileIconTile(icon: icon, tint: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.app(15, weight: .bold))
                    .foregroundStyle(AppColor.text)
                Text(subtitle)
                    .font(.app(12))
                    .foregroundStyle(AppColor.muted)
            }
            .multilineTextAlignment(.leading)
            Spacer()
            Image(systemName: trailingIcon)
                .font(.app(14))
                .foregroundStyle(AppColor.muted)
        }
        .padding(.horizontal, AppSpacing.card)
        .padding(.vertical, ProfileGrid.rowVertical)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.border, lineWidth: 1))
        .contentShape(Rectangle())
    }
}

// MARK: - Konto löschen

/// Bestätigung mit Erklärung; die Löschung läuft per E-Mail an Sihl Training.
private struct DeleteAccountSheet: View {
    let clientId: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var mailFailed = false

    private var mailURL: URL? {
        AppLinks.supportMail(
            subject: "Konto löschen – Kunden-ID \(clientId)",
            body: "Bitte löscht mein Konto bei Sihl Training und die dazugehörigen Daten.\n\nKunden-ID: \(clientId)"
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Konto löschen")
                    .font(.app(20, weight: .bold))
                    .foregroundStyle(AppColor.text)
                Spacer()
                Button("Abbrechen") { dismiss() }
                    .font(.app(15))
                    .foregroundStyle(AppColor.muted)
            }

            Text("Wir löschen dein Konto und deine Daten innerhalb von 30 Tagen; gesetzlich aufzubewahrende Rechnungen ausgenommen.")
                .font(.app(15))
                .foregroundStyle(AppColor.text)
                .fixedSize(horizontal: false, vertical: true)

            Text("Tippe unten, um eine vorbereitete E-Mail an \(AppLinks.supportEmail) zu öffnen, und sende sie ab.")
                .font(.app(13))
                .foregroundStyle(AppColor.muted)
                .fixedSize(horizontal: false, vertical: true)

            if mailFailed {
                InlineErrorBanner(message: "Keine Mail-App gefunden. Schreib bitte an \(AppLinks.supportEmail) mit Betreff „Konto löschen – Kunden-ID \(clientId)“.")
                    .textSelection(.enabled)
            }

            Spacer(minLength: 0)

            Button {
                guard let mailURL else { mailFailed = true; return }
                openURL(mailURL) { accepted in
                    if accepted { dismiss() } else { mailFailed = true }
                }
            } label: {
                Text("Löschung per E-Mail anfragen")
            }
            .buttonStyle(PrimaryButtonStyle(fill: AppColor.red))
        }
        .padding(AppSpacing.screen)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppColor.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Polar Card

private struct PolarCard: View {
    /// false = auf dem Server nicht eingerichtet → Hinweis statt leerer Aktion
    let available: Bool
    let connected: Bool
    let loading: Bool
    let lastSync: Date?
    let onSync: () -> Void
    let onDisconnect: () -> Void
    var onConnect: (() -> Void)? = nil

    private let polarRed = Color(hex: 0xD4002A)

    var body: some View {
        VStack(alignment: .leading, spacing: ProfileGrid.gap) {
            // Kopfzeile wie jede Profil-Zeile: Kachel · Titel/Status
            HStack(spacing: ProfileGrid.gap) {
                ProfileIconTile(tint: polarRed) {
                    Text("P")
                        .font(.app(18, weight: .black))
                        .foregroundStyle(polarRed)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Polar")
                        .font(.app(15, weight: .bold))
                        .foregroundStyle(AppColor.text)
                    Text(statusText)
                        .font(.app(12))
                        .foregroundStyle(connected ? AppColor.green : AppColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if loading {
                    ProgressView().tint(AppColor.primary)
                }
            }

            // Aktionen in eigener Zeile, gleich breit — nebeneinander mit dem
            // Text gequetscht brachen die Beschriftungen Buchstabe für Buchstabe
            if !loading {
                if connected {
                    HStack(spacing: ProfileGrid.gap) {
                        actionButton("Abgleichen", icon: "arrow.clockwise",
                                     tint: AppColor.primary, action: onSync)
                        actionButton("Trennen", icon: "link.badge.minus",
                                     tint: AppColor.red, action: onDisconnect)
                    }
                } else if let onConnect {
                    actionButton("Verbinden", icon: "link",
                                 tint: AppColor.primary, action: onConnect)
                }
            }
        }
        .padding(.vertical, ProfileGrid.itemVertical)
    }

    private func actionButton(_ title: String, icon: String, tint: Color,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.app(14, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)   // grosse Schrift: lieber kleiner als umbrechen
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, minHeight: ProfileGrid.control)
                .background(tint.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
        }
        .buttonStyle(.plain)
    }

    private var statusText: String {
        if connected {
            guard let lastSync else { return "Verbunden" }
            return "Verbunden · abgeglichen \(lastSync.formatted(.relative(presentation: .named)))"
        }
        return available ? "Nicht verbunden" : "Derzeit nicht verfügbar"
    }
}

// MARK: - Empty Hint

/// Inline-Leerzustand (EmptyStateView-Kanon ohne Icon): EINE Muted-Zeile, kein Container.
struct EmptyHint: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(AppColor.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
    }
}

// MARK: - PushNotificationCard

/// Pendant zu `_PushNotificationCard` in `profile_screen.dart`.
private struct PushNotificationCard: View {
    let enabled:  Bool
    let loading:  Bool
    let denied:   Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: ProfileGrid.gap) {
            ProfileIconTile(icon: "bell.badge.fill", tint: AppColor.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Push-Benachrichtigungen")
                    .font(.app(15, weight: .bold))
                    .foregroundStyle(AppColor.text)
                // Zustand signalisiert der Toggle; Fliesstext nur im denied-Fall.
                if denied {
                    Text("In den iOS-Einstellungen aktivieren")
                        .font(.app(12))
                        .foregroundStyle(AppColor.muted)
                }
            }

            Spacer()

            if loading {
                ProgressView().tint(AppColor.primary)
            } else if denied {
                // Statt Toggle: Button der in Einstellungen führt
                Button {
                    onToggle(true)
                } label: {
                    Text("Einstellungen")
                        .font(.app(14, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(AppColor.primary)
                        .padding(.horizontal, 12)
                        .frame(minHeight: ProfileGrid.control)
                        .background(AppColor.primary.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
                }
            } else {
                Toggle("", isOn: Binding(
                    get: { enabled },
                    set: { onToggle($0) }
                ))
                .tint(AppColor.primary)
                .labelsHidden()
            }
        }
        .padding(.vertical, ProfileGrid.itemVertical)
    }
}



// MARK: - Profil-Raster

/// Rasterwerte des Profils (4-pt-Raster, Werte aus AppSpacing wo vorhanden):
/// jede Zeile beginnt mit derselben 36-pt-Kachel, Titel stehen daher in
/// allen Karten auf derselben Fluchtlinie.
enum ProfileGrid {
    /// Kachel → Text und Knopf → Knopf
    static let gap: CGFloat = 12
    /// Vertikales Innenpadding einer Karten-Kopfzeile (36 + 2×14 = 64 pt)
    static let rowVertical: CGFloat = 14
    /// Innenpadding des aufgeklappten Inhalts
    static let bodyVertical: CGFloat = 12
    /// Abstand einzelner Einträge im aufgeklappten Inhalt
    static let itemVertical: CGFloat = 8
    /// Mindesthöhe von Knöpfen (Apple-Tippfläche)
    static let control: CGFloat = 44
    /// Kantenlänge der Icon-Kachel
    static let tile: CGFloat = 36
}

/// Einheitliche Icon-Kachel am Zeilenanfang.
struct ProfileIconTile<Glyph: View>: View {
    let tint: Color
    @ViewBuilder let glyph: () -> Glyph

    var body: some View {
        RoundedRectangle(cornerRadius: AppRadius.control)
            .fill(tint.opacity(0.14))
            .frame(width: ProfileGrid.tile, height: ProfileGrid.tile)
            .overlay(glyph())
            .accessibilityHidden(true)
    }
}

extension ProfileIconTile where Glyph == AnyView {
    init(icon: String, tint: Color) {
        self.tint = tint
        self.glyph = {
            AnyView(Image(systemName: icon)
                .font(.app(16))
                .foregroundStyle(tint))
        }
    }
}
