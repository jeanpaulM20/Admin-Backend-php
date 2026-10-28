import SwiftUI
import Observation

// MARK: - Modell

/// Hält die Sensor-Quellen für die Einstellungsseite. Bewusst eigenständig:
/// Die Wahl des Brustgurts gehört zum Gerät, nicht zu einer einzelnen
/// Aufzeichnung — der Recorder verbindet sich beim Training nur mit dem
/// hier gewählten Gurt (gemerkte Kennung).
@Observable
final class SensorSettingsModel {
    private(set) var hrState: HeartRateSourceState = .idle
    private(set) var currentHR: Int?
    private(set) var gpsState: LocationSourceState = .idle
    /// Gefundene Gurte, stärkstes Signal zuerst
    private(set) var straps: [DiscoveredStrap] = []
    private(set) var isSearching = false
    private(set) var rememberedId: UUID? = BleHeartRateSource.rememberedId
    private(set) var rememberedName: String? = BleHeartRateSource.rememberedName

    @ObservationIgnored private var hrSource: HeartRateSource?
    @ObservationIgnored private var gpsSource: LocationSource?

    @MainActor
    func start(demo: Bool) {
        guard hrSource == nil else { return }
        let hr = demo ? SimulatedHeartRateSource() as HeartRateSource : BleHeartRateSource()
        hr.onStateChange = { [weak self] state in self?.hrState = state }
        hr.onSample = { [weak self] bpm in self?.currentHR = bpm }
        (hr as? BleHeartRateSource)?.onStrapsChange = { [weak self] list in self?.straps = list }
        hrSource = hr

        let gps = demo ? SimulatedLocationSource() as LocationSource : CoreLocationSource()
        gps.onStateChange = { [weak self] state in self?.gpsState = state }
        gpsSource = gps
        gps.start()
    }

    /// Gurte in Reichweite suchen (Demo: simulierter Gurt).
    @MainActor
    func search() {
        isSearching = true
        if let ble = hrSource as? BleHeartRateSource {
            ble.startDiscovery()
        } else {
            hrSource?.start()
        }
    }

    @MainActor
    func select(_ strap: DiscoveredStrap) {
        (hrSource as? BleHeartRateSource)?.select(strap.id)
        refreshRemembered()
    }

    @MainActor
    func forget() {
        (hrSource as? BleHeartRateSource)?.forget()
        currentHR = nil
        refreshRemembered()
    }

    private func refreshRemembered() {
        rememberedId = BleHeartRateSource.rememberedId
        rememberedName = BleHeartRateSource.rememberedName
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
        straps = []
        isSearching = false
    }
}

// MARK: - SensorSettingsView

/// Sensoren einrichten: Herzfrequenz-Gurt wählen und Standort-Status
/// prüfen. Aus dem Aufzeichnungs-Screen hierher verschoben, weil es
/// Geräte-Einstellungen sind und nicht Teil des Trainingsstarts.
struct SensorSettingsView: View {
    @Environment(AuthViewModel.self) private var auth
    @State private var model = SensorSettingsModel()

    private var isDemo: Bool { auth.clientId == "demo" }

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.stack) {
                    heartRateCard
                    if model.isSearching, !isDemo { strapList }
                    gpsCard

                    Text("Beim Training verbindet sich nur der hier gewählte Gurt. Ohne gewählten Gurt verbindet die App nur, wenn genau ein Gurt in Reichweite ist — sonst zeichnet sie Dauer und Route ohne Puls auf.")
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
    }

    private var heartRateCard: some View {
        HStack(spacing: 12) {
            Image(systemName: model.hrState.isConnected ? "heart.fill" : "heart")
                .font(.app(20))
                .foregroundStyle(model.hrState.isConnected ? AppColor.red : AppColor.muted)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.isSearching || model.hrState.isConnected
                     ? model.hrState.label
                     : (model.rememberedName.map { "Gewählt: \($0)" } ?? "Kein Gurt gewählt"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColor.text)
                if model.hrState.isConnected, let hr = model.currentHR {
                    Text("\(hr) bpm")
                        .font(.caption)
                        .foregroundStyle(AppColor.red)
                } else if !model.hrState.isConnected {
                    Text("Polar H10 anlegen und Elektroden anfeuchten")
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                }
            }
            Spacer()
            if !model.isSearching {
                Button(model.rememberedId == nil ? "Gurt suchen" : "Gurt wechseln") { model.search() }
                    .buttonStyle(OutlineButtonStyle())
            } else if model.rememberedId != nil, !isDemo {
                Button("Vergessen") { model.forget() }
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppColor.muted)
                    .accessibilityLabel("Gewählten Gurt vergessen")
            }
        }
        .padding(AppSpacing.card)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.border, lineWidth: 1))
    }

    /// Gefundene Gurte zur Auswahl: Name und Signalstärke — der eigene ist
    /// meist der mit dem stärksten Signal (am Körper).
    private var strapList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("Gurte in Reichweite")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppColor.muted)
                ProgressView().controlSize(.small).tint(AppColor.muted)
            }
            .padding(.horizontal, AppSpacing.card)
            .padding(.vertical, 10)

            if model.straps.isEmpty {
                Text("Noch kein Gurt gefunden — Gurt anlegen, er sendet erst mit Hautkontakt.")
                    .font(.caption)
                    .foregroundStyle(AppColor.muted)
                    .padding(.horizontal, AppSpacing.card)
                    .padding(.bottom, AppSpacing.card)
            }
            ForEach(model.straps) { strap in
                Divider().overlay(AppColor.border)
                strapRow(strap)
            }
        }
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.border, lineWidth: 1))
    }

    private func strapRow(_ strap: DiscoveredStrap) -> some View {
        let chosen = strap.id == model.rememberedId
        return Button { model.select(strap) } label: {
            HStack(spacing: 12) {
                Image(systemName: "cellularbars", variableValue: Double(strap.signalLevel) / 3)
                    .font(.app(16))
                    .foregroundStyle(AppColor.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(strap.name)
                        .font(.subheadline.weight(chosen ? .semibold : .regular))
                        .foregroundStyle(AppColor.text)
                    Text("Signal \(strap.signalLabel)")
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                }
                Spacer()
                if chosen {
                    Image(systemName: "checkmark")
                        .font(.app(14, weight: .semibold))
                        .foregroundStyle(AppColor.primary)
                }
            }
            .padding(.horizontal, AppSpacing.card)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(strap.name), Signal \(strap.signalLabel)")
        .accessibilityAddTraits(chosen ? .isSelected : [])
        .accessibilityHint(chosen ? "" : "Wählt diesen Gurt für das Training")
    }

    private var gpsCard: some View {
        HStack(spacing: 12) {
            Image(systemName: model.gpsState.isActive ? "location.fill" : "location")
                .font(.app(20))
                .foregroundStyle(model.gpsState.isActive ? AppColor.green : AppColor.muted)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.gpsState.label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColor.text)
                if case .denied = model.gpsState {
                    Text("Standort in den iOS-Einstellungen erlauben")
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                }
            }
            Spacer()
        }
        .padding(AppSpacing.card)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.border, lineWidth: 1))
    }
}
