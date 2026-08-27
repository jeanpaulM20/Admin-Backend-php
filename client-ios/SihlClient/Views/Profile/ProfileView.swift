import SwiftUI
import UIKit

/// Pendant zu `screens/profile_screen.dart`.
/// Geöffnet als NavigationDestination vom Profil-Avatar in MainTabView.
struct ProfileView: View {
    @Environment(AuthViewModel.self)    private var auth
    @Environment(ProfileViewModel.self) private var vm

    @State private var selectedInvoice: Invoice?
    @State private var showLogoutAlert   = false
    @State private var showPolarDisconnectAlert = false
    @State private var polarToast: AppToast?

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
                ErrorStateView(message: err) {
                    Task { await vm.load(clientId: auth.clientId ?? "") }
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
                        polarToast = AppToast(message: "Polar-Trennung fehlgeschlagen", style: .error)
                    }
                }
            }
        } message: {
            Text("Polar-Verbindung wirklich trennen?")
        }
        .appToast($polarToast)
    }

    // MARK: - Demo-Modus

    /// Im Demo fehlen nur Konto- und Vertragsdaten — die funktionalen
    /// Bereiche (Trainingspläne, Sensoren) bleiben erreichbar.
    private var demoContent: some View {
        ScrollView {
            VStack(spacing: AppSpacing.stack) {
                EmptyStateView(
                    icon: "person.crop.circle.badge.questionmark",
                    message: "Konto- und Vertragsdaten sind im Demo-Modus nicht verfügbar."
                )
                .padding(.vertical, 12)

                trainingPlansRow

                sensorsRow

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
                    .padding(.bottom, 18)

                creditsSection
                creditsBuyRow
                invoicesSection
                filesSection
                connectionsSection
                glucoseRow

                trainingPlansRow

                sensorsRow
                notificationsSection

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
            title: "Meine Credits",
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

    // MARK: - Credits kaufen Row

    private var creditsBuyRow: some View {
        ProfileNavRow(icon: "cart", tint: AppColor.primary,
                      title: "Credits kaufen", subtitle: "Abos & Pakete ansehen") {
            CreditsView()
        }
    }

    // MARK: - Blutzucker Row (CGM — ehemals Tab 6; max. 5 Tabs, s. MainTabView)

    private var glucoseRow: some View {
        ProfileNavRow(icon: "waveform.path.ecg", tint: AppColor.red,
                      title: "Blutzucker", subtitle: "FreeStyle Libre CGM-Daten") {
            GlucoseView().navigationTitle("Blutzucker")
        }
    }

    // MARK: - Trainingspläne (aus dem Touren-Tab hierher verschoben)

    private var trainingPlansRow: some View {
        ProfileNavRow(icon: "list.clipboard", tint: AppColor.brass,
                      title: "Trainingspläne", subtitle: "Deine Pläne und das Coaching-Abo") {
            TrainingView().navigationTitle("Trainingspläne")
        }
    }

    // MARK: - Sensoren (aus dem Aufzeichnungs-Screen hierher verschoben)

    private var sensorsRow: some View {
        ProfileNavRow(icon: "sensor.tag.radiowaves.forward", tint: AppColor.primary,
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
            title: "Files",
            subtitle: vm.countLabel(vm.files.count, "Datei", "Dateien")
        ) {
            if vm.files.isEmpty {
                EmptyHint(text: "Keine Dateien vorhanden")
            } else {
                ForEach(vm.files) { file in
                    FileRow(file: file, token: auth.token)
                        .padding(.bottom, 8)
                }
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
                connected: vm.polarConnected,
                loading: vm.polarLoading,
                onSync: {
                    Task {
                        guard let id = auth.clientId else { return }
                        do {
                            try await vm.syncPolar(clientId: id)
                            withAnimation { polarToast = AppToast(message: "Polar-Trainings synchronisiert!", style: .success) }
                        } catch {
                            withAnimation { polarToast = AppToast(message: "Polar-Sync fehlgeschlagen", style: .error) }
                        }
                    }
                },
                onDisconnect: { showPolarDisconnectAlert = true },
                onConnect: vm.polarConnectUrl.flatMap { URL(string: $0) }.map { url in
                    { UIApplication.shared.open(url) }
                }
            )
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        SectionDisclosure(
            icon: "bell.fill",
            title: "Benachrichtigungen"
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
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.app(16))
                Text("Abmelden")
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
    }
}

// MARK: - Collapsible Section

/// Wiederverwendbare aufklappbare Sektion — Pendant zu Flutter `_SectionTile` (ExpansionTile).
struct SectionDisclosure<Content: View>: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let content: () -> Content

    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Header / Tap-Target
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.app(18))
                        .foregroundStyle(AppColor.primary)
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
                        .font(.app(13))
                        .foregroundStyle(AppColor.muted)
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            // Body
            if expanded {
                Divider().background(AppColor.border)
                VStack(spacing: 0) {
                    content()
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 12)
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "creditcard")
                    .font(.app(16))
                    .foregroundStyle(AppColor.primary)
                Text(pack.title)
                    .font(.app(15, weight: .bold))
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
        }
        .padding(.vertical, 8)
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

        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: AppRadius.control)
                .fill(AppColor.primary.opacity(0.12))
                .frame(width: 40, height: 40)
                .overlay(Image(systemName: "receipt")
                    .font(.app(18))
                    .foregroundStyle(AppColor.primary))

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
                Text("\(invoice.currency) \(String(format: "%.2f", invoice.amount))")
                    .font(.app(16, weight: .heavy))
                    .foregroundStyle(AppColor.text)
                Text(isPaid ? "Bezahlt" : "Offen")
                    .font(.app(11, weight: .bold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Image(systemName: "chevron.right")
                .font(.app(14))
                .foregroundStyle(AppColor.muted)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

// MARK: - File Row

private struct FileRow: View {
    let file: ClientFile
    let token: String?

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "dd.MM.yyyy"; return f
    }()

    var body: some View {
        Button {
            openFile()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "doc.fill")
                    .font(.app(18))
                    .foregroundStyle(AppColor.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name)
                        .font(.app(13, weight: .semibold))
                        .foregroundStyle(AppColor.text)
                    Text(file.date.map { Self.dateFmt.string(from: $0) } ?? "-")
                        .font(.app(12))
                        .foregroundStyle(AppColor.muted)
                }
                Spacer()
                if file.hasUrl {
                    Image(systemName: "arrow.up.right.square")
                        .font(.app(16))
                        .foregroundStyle(AppColor.primary)
                }
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!file.hasUrl)
    }

    private func openFile() {
        guard let rawUrl = file.url, !rawUrl.isEmpty else { return }
        let fullUrl: String
        if rawUrl.hasPrefix("/api/") {
            let base = APIConfig.baseURL.absoluteString
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let sep = rawUrl.contains("?") ? "&" : "?"
            let tokenSuffix = token.map { "\(sep)token=\($0)" } ?? ""
            fullUrl = "\(base)\(rawUrl)\(tokenSuffix)"
        } else {
            fullUrl = rawUrl
        }
        guard let url = URL(string: fullUrl) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Polar Card

private struct PolarCard: View {
    let connected: Bool
    let loading: Bool
    let onSync: () -> Void
    let onDisconnect: () -> Void
    var onConnect: (() -> Void)? = nil

    private let polarRed = Color(hex: 0xD4002A)

    var body: some View {
        HStack(spacing: 14) {
            // Polar "P" Logo
            RoundedRectangle(cornerRadius: AppRadius.control)
                .fill(polarRed.opacity(0.12))
                .frame(width: 44, height: 44)
                .overlay(
                    Text("P")
                        .font(.app(22, weight: .black))
                        .foregroundStyle(polarRed)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Polar")
                    .font(.app(15, weight: .bold))
                    .foregroundStyle(AppColor.text)
                Text(connected ? "Verbunden" : "Nicht verbunden")
                    .font(.app(12))
                    .foregroundStyle(connected ? AppColor.green : AppColor.muted)
            }

            Spacer()

            if loading {
                ProgressView().tint(AppColor.primary).frame(width: 20, height: 20)
            } else if connected {
                HStack(spacing: 8) {
                    Button(action: onSync) {
                        Label("Sync", systemImage: "arrow.clockwise")
                            .font(.app(13, weight: .semibold))
                            .foregroundStyle(AppColor.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppColor.primary.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
                    }
                    .buttonStyle(.plain)

                    Button(action: onDisconnect) {
                        Label("Trennen", systemImage: "link.badge.minus")
                            .font(.app(13, weight: .semibold))
                            .foregroundStyle(AppColor.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppColor.red.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
                    }
                    .buttonStyle(.plain)
                }
            } else if let onConnect {
                // Getrennt: rechte Spalte zeigt die Aktion
                Button(action: onConnect) {
                    Label("Verbinden", systemImage: "link")
                        .font(.app(13, weight: .semibold))
                        .foregroundStyle(AppColor.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppColor.primary.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
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
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppColor.primary.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "bell.badge.fill")
                    .font(.app(18))
                    .foregroundStyle(AppColor.primary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Push-Benachrichtigungen")
                    .font(.app(15, weight: .bold))
                    .foregroundStyle(AppColor.text)
                // Zustand signalisiert der Toggle; Fließtext nur im denied-Fall.
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
                        .font(.app(12, weight: .semibold))
                        .foregroundStyle(AppColor.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppColor.primary.opacity(0.12))
                        .clipShape(Capsule())
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
        .padding(.vertical, 8)
    }
}

// MARK: - ProfileNavRow

/// Einheitliche Navigations-Zeile der Profilseite (Icon-Kachel, Titel,
/// Untertitel, Chevron) — eine Definition statt vier Kopien.
private struct ProfileNavRow<Destination: View>: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: AppRadius.control)
                    .fill(tint.opacity(0.14))
                    .frame(width: 36, height: 36)
                    .overlay(Image(systemName: icon)
                        .font(.app(16))
                        .foregroundStyle(tint))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.app(15, weight: .bold))
                        .foregroundStyle(AppColor.text)
                    Text(subtitle)
                        .font(.app(12))
                        .foregroundStyle(AppColor.muted)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.app(14))
                    .foregroundStyle(AppColor.muted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.border, lineWidth: 1))
        }
    }
}
