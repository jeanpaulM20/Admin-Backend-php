import SwiftUI
import Observation

// MARK: - Modell

/// Hält die Sensor-Quellen für die Einstellungsseite. Bewusst eigenständig:
/// Die Kopplung des Brustgurts gehört zum Gerät, nicht zu einer einzelnen
/// Aufzeichnung — der Recorder verbindet sich beim Training automatisch mit
/// dem hier gekoppelten Gurt (gemerkte Kennung).
@Observable
final class SensorSettingsModel {
    private(set) var hrState: HeartRateSourceState = .idle
    private(set) var currentHR: Int?
    private(set) var gpsState: LocationSourceState = .idle

    @ObservationIgnored private var hrSource: HeartRateSource?
    @ObservationIgnored private var gpsSource: LocationSource?

    @MainActor
    func start(demo: Bool) {
        guard hrSource == nil else { return }
        let hr = demo ? SimulatedHeartRateSource() as HeartRateSource : BleHeartRateSource()
        hr.onStateChange = { [weak self] state in self?.hrState = state }
        hr.onSample = { [weak self] bpm in self?.currentHR = bpm }
        hrSource = hr

        let gps = demo ? SimulatedLocationSource() as LocationSource : CoreLocationSource()
        gps.onStateChange = { [weak self] state in self?.gpsState = state }
        gpsSource = gps
        gps.start()
    }

    @MainActor
    func connectSensor() {
        hrSource?.start()
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
    }
}

// MARK: - SensorSettingsView

/// Sensoren einrichten: Herzfrequenz-Gurt koppeln und Standort-Status
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
                    gpsCard

                    Text("Der gekoppelte Gurt wird beim nächsten Training automatisch verbunden. Ohne Gurt zeichnet die App Dauer und Route auf.")
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
                Text(model.hrState.label)
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
            if !model.hrState.isConnected {
                Button("Verbinden") { model.connectSensor() }
                    .buttonStyle(OutlineButtonStyle())
            }
        }
        .padding(AppSpacing.card)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.border, lineWidth: 1))
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
