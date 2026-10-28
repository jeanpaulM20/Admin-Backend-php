import SwiftUI
import Observation

// MARK: - Modell

/// Hält die Sensor-Quellen für die Einstellungsseite. Bewusst eigenständig:
/// Die gespeicherten Sensoren gehören zum Gerät, nicht zu einer einzelnen
/// Aufzeichnung — der Recorder verbindet sich beim Training nur mit ihnen.
@Observable
final class SensorSettingsModel {
    private(set) var hrState: HeartRateSourceState = .idle
    private(set) var currentHR: Int?
    private(set) var gpsState: LocationSourceState = .idle
    /// Gurte in Reichweite, stärkstes Signal zuerst
    private(set) var straps: [DiscoveredStrap] = []
    /// Suche nach neuen Sensoren offen (Liste „In Reichweite")
    private(set) var isAdding = false
    private(set) var saved: [SavedStrap] = SavedStraps.all
    /// Gerade verbundener gespeicherter Sensor
    private(set) var connectedId: UUID?

    @ObservationIgnored private var hrSource: HeartRateSource?
    @ObservationIgnored private var gpsSource: LocationSource?

    /// Gurte in Reichweite, die noch nicht gespeichert sind
    var newStraps: [DiscoveredStrap] {
        let ids = Set(saved.map(\.id))
        return straps.filter { !ids.contains($0.id) }
    }

    @MainActor
    func start(demo: Bool) {
        guard hrSource == nil else { return }
        let hr = demo ? SimulatedHeartRateSource() as HeartRateSource : BleHeartRateSource()
        hr.onStateChange = { [weak self] state in
            guard let self else { return }
            self.hrState = state
            self.connectedId = (self.hrSource as? BleHeartRateSource)?.connectedId
            if !state.isConnected { self.currentHR = nil }
            self.saved = SavedStraps.all   // Name/zuletzt verbunden nachführen
        }
        hr.onSample = { [weak self] bpm in self?.currentHR = bpm }
        (hr as? BleHeartRateSource)?.onStrapsChange = { [weak self] list in self?.straps = list }
        hrSource = hr

        let gps = demo ? SimulatedLocationSource() as LocationSource : CoreLocationSource()
        gps.onStateChange = { [weak self] state in self?.gpsState = state }
        gpsSource = gps
        gps.start()

        // Gespeicherte Sensoren gleich verbinden, damit Status und Puls
        // sichtbar sind (Demo: simulierter Gurt)
        if demo {
            hr.start()
        } else if !saved.isEmpty {
            (hr as? BleHeartRateSource)?.startDiscovery()
        }
    }

    /// Liste „In Reichweite" öffnen, um einen neuen Sensor hinzuzufügen.
    @MainActor
    func beginAdding() {
        isAdding = true
        (hrSource as? BleHeartRateSource)?.startDiscovery()
    }

    @MainActor
    func endAdding() { isAdding = false }

    @MainActor
    func add(_ strap: DiscoveredStrap) {
        (hrSource as? BleHeartRateSource)?.add(strap.id)
        saved = SavedStraps.all
        isAdding = false
    }

    @MainActor
    func remove(_ strap: SavedStrap) {
        (hrSource as? BleHeartRateSource)?.remove(strap.id)
        if connectedId == strap.id { connectedId = nil; currentHR = nil }
        saved = SavedStraps.all
    }

    /// Beim Verlassen der Seite alles freigeben — sonst konkurriert die
    /// Einstellungsseite mit der Aufzeichnung um denselben Gurt.
    @MainActor
    func stop() {
        hrSource?.stop()
        gpsSource?.stop()
        hrSource = nil
        gpsSource = nil
        hrState = .idle
        gpsState = .idle
        currentHR = nil
        connectedId = nil
        straps = []
        isAdding = false
    }
}

// MARK: - SensorSettingsView

/// Sensoren verwalten: gespeicherte Herzfrequenz-Sensoren sehen, neue
/// hinzufügen, nicht mehr genutzte entfernen; dazu der Standort-Status.
struct SensorSettingsView: View {
    @Environment(AuthViewModel.self) private var auth
    @State private var model = SensorSettingsModel()
    @State private var removeCandidate: SavedStrap?

    private var isDemo: Bool { auth.clientId == "demo" }

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.stack) {
                    OverlineHeader(title: "Herzfrequenz-Sensoren")
                    if isDemo {
                        demoCard
                    } else {
                        savedCard
                        if model.isAdding {
                            nearbyCard
                        } else {
                            addButton
                        }
                    }

                    OverlineHeader(title: "Standort")
                    gpsCard

                    Text("Beim Training verbindet sich die App nur mit gespeicherten Sensoren – mit dem zuletzt genutzten zuerst. Ohne gespeicherten Sensor zeichnet sie Dauer und Route ohne Puls auf.")
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                        .padding(.top, 4)
                }
                .padding(.horizontal, AppSpacing.screen)
                .padding(.top, AppSpacing.card)
                .padding(.bottom, AppSpacing.bottomInset)
            }
        }
        .navigationTitle("Sensoren")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.start(demo: isDemo) }
        .onDisappear { model.stop() }
        .alert("Sensor entfernen?", isPresented: Binding(
            get: { removeCandidate != nil },
            set: { if !$0 { removeCandidate = nil } }
        ), presenting: removeCandidate) { strap in
            Button("Abbrechen", role: .cancel) {}
            Button("Entfernen", role: .destructive) { model.remove(strap) }
        } message: { strap in
            Text("„\(strap.name)“ verbindet sich danach nicht mehr automatisch. Du kannst ihn jederzeit wieder hinzufügen.")
        }
    }

    // MARK: Gespeicherte Sensoren

    private var savedCard: some View {
        VStack(spacing: 0) {
            if model.saved.isEmpty {
                HStack(spacing: ProfileGrid.gap) {
                    ProfileIconTile(icon: "heart", tint: AppColor.muted)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Kein Sensor gespeichert")
                            .font(.app(15, weight: .bold))
                            .foregroundStyle(AppColor.text)
                        Text("Füge deinen Brustgurt hinzu, damit das Training den Puls aufzeichnet.")
                            .font(.app(12))
                            .foregroundStyle(AppColor.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, AppSpacing.card)
                .padding(.vertical, ProfileGrid.rowVertical)
            }
            ForEach(Array(model.saved.enumerated()), id: \.element.id) { i, strap in
                if i > 0 { Divider().overlay(AppColor.border) }
                savedRow(strap)
            }
        }
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.border, lineWidth: 1))
    }

    private func savedRow(_ strap: SavedStrap) -> some View {
        let connected = model.connectedId == strap.id && model.hrState.isConnected
        return HStack(spacing: ProfileGrid.gap) {
            ProfileIconTile(icon: connected ? "heart.fill" : "heart",
                            tint: connected ? AppColor.red : AppColor.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(strap.name)
                    .font(.app(15, weight: .bold))
                    .foregroundStyle(AppColor.text)
                    .lineLimit(1)
                Text(status(of: strap, connected: connected))
                    .font(.app(12))
                    .foregroundStyle(connected ? AppColor.green : AppColor.muted)
            }
            Spacer(minLength: 0)
            Button { removeCandidate = strap } label: {
                Image(systemName: "minus.circle")
                    .font(.app(18))
                    .foregroundStyle(AppColor.red)
                    .frame(width: ProfileGrid.control, height: ProfileGrid.control)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(strap.name) entfernen")
        }
        .padding(.leading, AppSpacing.card)
        .padding(.trailing, 4)
        .padding(.vertical, ProfileGrid.itemVertical)
        .accessibilityElement(children: .contain)
    }

    private func status(of strap: SavedStrap, connected: Bool) -> String {
        if connected {
            return model.currentHR.map { "Verbunden · \($0) bpm" } ?? "Verbunden"
        }
        if let last = strap.lastUsed {
            return "Gespeichert · zuletzt verbunden \(last.formatted(.relative(presentation: .named)))"
        }
        return "Gespeichert"
    }

    // MARK: Neuen Sensor hinzufügen

    private var addButton: some View {
        Button { model.beginAdding() } label: {
            Label("Neuen Sensor hinzufügen", systemImage: "plus")
                .font(.app(14, weight: .semibold))
                .foregroundStyle(AppColor.primary)
                .frame(maxWidth: .infinity, minHeight: ProfileGrid.control)
                .background(AppColor.primary.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
        }
        .buttonStyle(.plain)
    }

    /// Gurte in Reichweite, die noch nicht gespeichert sind — der eigene ist
    /// meist der mit dem stärksten Signal (am Körper).
    private var nearbyCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("Gurte in Reichweite")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppColor.muted)
                ProgressView().controlSize(.small).tint(AppColor.muted)
                Spacer()
                Button("Fertig") { model.endAdding() }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppColor.primary)
                    .frame(minHeight: ProfileGrid.control)
            }
            .padding(.horizontal, AppSpacing.card)

            if model.newStraps.isEmpty {
                Text("Noch kein neuer Gurt gefunden — Gurt anlegen und Elektroden anfeuchten, er sendet erst mit Hautkontakt.")
                    .font(.caption)
                    .foregroundStyle(AppColor.muted)
                    .padding(.horizontal, AppSpacing.card)
                    .padding(.bottom, AppSpacing.card)
            }
            ForEach(model.newStraps) { strap in
                Divider().overlay(AppColor.border)
                nearbyRow(strap)
            }
        }
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.border, lineWidth: 1))
    }

    private func nearbyRow(_ strap: DiscoveredStrap) -> some View {
        Button { model.add(strap) } label: {
            HStack(spacing: ProfileGrid.gap) {
                ProfileIconTile(tint: AppColor.primary) {
                    Image(systemName: "cellularbars", variableValue: Double(strap.signalLevel) / 3)
                        .font(.app(16))
                        .foregroundStyle(AppColor.primary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(strap.name)
                        .font(.app(15, weight: .bold))
                        .foregroundStyle(AppColor.text)
                        .lineLimit(1)
                    Text("Signal \(strap.signalLabel)")
                        .font(.app(12))
                        .foregroundStyle(AppColor.muted)
                }
                Spacer(minLength: 0)
                Text("Hinzufügen")
                    .font(.app(14, weight: .semibold))
                    .foregroundStyle(AppColor.primary)
            }
            .padding(.horizontal, AppSpacing.card)
            .padding(.vertical, ProfileGrid.itemVertical)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(strap.name), Signal \(strap.signalLabel)")
        .accessibilityHint("Fügt diesen Gurt als Sensor hinzu")
    }

    // MARK: Demo

    private var demoCard: some View {
        HStack(spacing: ProfileGrid.gap) {
            ProfileIconTile(icon: "heart.fill", tint: AppColor.red)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.hrState.label)
                    .font(.app(15, weight: .bold))
                    .foregroundStyle(AppColor.text)
                Text(model.currentHR.map { "\($0) bpm" } ?? "Demo: simulierter Puls")
                    .font(.app(12))
                    .foregroundStyle(AppColor.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.card)
        .padding(.vertical, ProfileGrid.rowVertical)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.border, lineWidth: 1))
    }

    // MARK: Standort

    private var gpsCard: some View {
        HStack(spacing: ProfileGrid.gap) {
            ProfileIconTile(icon: model.gpsState.isActive ? "location.fill" : "location",
                            tint: model.gpsState.isActive ? AppColor.green : AppColor.muted)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.gpsState.label)
                    .font(.app(15, weight: .bold))
                    .foregroundStyle(AppColor.text)
                if case .denied = model.gpsState {
                    Text("Standort in den iOS-Einstellungen erlauben")
                        .font(.app(12))
                        .foregroundStyle(AppColor.muted)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.card)
        .padding(.vertical, ProfileGrid.rowVertical)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.border, lineWidth: 1))
    }
}
