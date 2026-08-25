import SwiftUI
import MapKit

// MARK: - RecordWorkoutView (Einstieg: Aktivität wählen + Sensoren)

/// Training-Tracking: Herzfrequenz (Polar H10 / BLE-Gurt) + GPS-Route
/// bei Outdoor-Aktivitäten. Wird aus dem Training-Tab gepusht.
struct RecordWorkoutView: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.dismiss) private var dismiss

    /// Optional: Tour, der gefolgt wird (T3 — Overlay + Off-Route-Hinweis).
    var tour: TourRoute? = nil

    @State private var activity: WorkoutActivity = .joggen
    @State private var recorder: WorkoutRecorder?
    @State private var showSession = false
    @State private var recovered: WorkoutRecorder.Snapshot?

    private var isDemo: Bool { auth.clientId == "demo" }

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.stack) {
                    if let tour { tourCard(tour) }

                    Text("Aktivität")
                        .font(.subheadline.bold())
                        .foregroundStyle(AppColor.text)

                    activityGrid

                    Text("Sensoren")
                        .font(.subheadline.bold())
                        .foregroundStyle(AppColor.text)
                        .padding(.top, 8)

                    sensorCard
                    if activity.usesGPS { gpsCard }

                    Button("Training starten") {
                        recorder?.startRecording(activity)
                        showSession = true
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 12)

                    if !(recorder?.hrState.isConnected ?? false) {
                        Text("Du kannst auch ohne Gurt starten — dann werden nur Dauer\(activity.usesGPS ? " und Route" : "") erfasst.")
                            .font(.caption)
                            .foregroundStyle(AppColor.muted)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(.horizontal, AppSpacing.screen)
                .padding(.top, 16)
                .padding(.bottom, AppSpacing.bottomInset)
            }
        }
        .navigationTitle("Training aufzeichnen")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if recorder == nil {
                recorder = WorkoutRecorder(
                    source: Self.makeHeartRateSource(demo: isDemo),
                    gpsSource: Self.makeLocationSource(demo: isDemo)
                )
                if let tour {
                    recorder?.setRoute(tour)
                    activity = tour.workoutActivity
                }
            }
            if activity.usesGPS { recorder?.prepareGPS() }
            recovered = WorkoutRecorder.pendingSnapshot()
        }
        .onChange(of: activity) { _, newActivity in
            newActivity.usesGPS ? recorder?.prepareGPS() : recorder?.stopGPSPreparation()
        }
        .onDisappear {
            // Nur aufräumen, wenn keine Session läuft
            if !showSession { recorder?.teardown() }
        }
        .fullScreenCover(isPresented: $showSession) {
            if let recorder {
                WorkoutSessionView(recorder: recorder, isDemo: isDemo) {
                    showSession = false
                    dismiss()
                }
            }
        }
        // Crash-/Kill-Recovery: liegen gebliebenes Training nachreichen
        .alert("Unterbrochenes Training gefunden", isPresented: Binding(
            get: { recovered != nil }, set: { if !$0 { recovered = nil } }
        ), presenting: recovered) { snap in
            Button("Speichern") {
                let payload = WorkoutUploadService.Payload(
                    clientId: auth.clientId ?? "",
                    trainingType: snap.activity.rawValue,
                    startedAt: snap.startedAt,
                    duration: Self.format(snap.elapsed),
                    samples: snap.samples,
                    track: snap.track,
                    distanceMeters: snap.distanceMeters,
                    elevationGain: snap.elevationGain
                )
                WorkoutRecorder.clearSnapshot()
                recovered = nil
                Task {
                    if (try? await WorkoutUploadService.shared.upload(payload)) == nil {
                        WorkoutUploadService.shared.queue(payload)
                    }
                }
            }
            Button("Verwerfen", role: .destructive) {
                WorkoutRecorder.clearSnapshot()
                recovered = nil
            }
            Button("Abbrechen", role: .cancel) {}
        } message: { snap in
            Text("\(snap.activity.rawValue) · \(Self.format(snap.elapsed)) · \(snap.samples.count) HF-Punkte")
        }
    }

    // MARK: Bausteine

    private func tourCard(_ tour: TourRoute) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.control)
                    .fill(AppColor.primary.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "map")
                    .font(.app(18))
                    .foregroundStyle(AppColor.primary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(tour.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(AppColor.text)
                    .lineLimit(2)
                Text("Route wird auf der Karte angezeigt\(tour.distanceKm.map { String(format: " · %.1f km", $0) } ?? "")")
                    .font(.caption)
                    .foregroundStyle(AppColor.muted)
            }
            Spacer()
        }
        .padding(AppSpacing.card)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.primary, lineWidth: 1))
    }

    /// Aktivitätsauswahl im selben Kachel-Schema wie die Touren-Discovery
    /// (scrollbare Chip-Reihe) — einheitlicher Look über beide Screens.
    private var activityGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(WorkoutActivity.allCases) { a in
                    let selected = a == activity
                    HStack(spacing: 6) {
                        Image(systemName: a.icon).font(.app(13))
                        Text(a.rawValue).font(.footnote.weight(selected ? .bold : .medium))
                    }
                    .foregroundStyle(selected ? AppColor.white : AppColor.muted)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(selected ? AppColor.primary : AppColor.surface,
                                in: RoundedRectangle(cornerRadius: AppRadius.control))
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.control)
                        .stroke(selected ? AppColor.primary : AppColor.border, lineWidth: 1))
                    .contentShape(Rectangle())
                    .onTapGesture { activity = a }
                }
            }
            .padding(.horizontal, AppSpacing.screen)
        }
        .padding(.horizontal, -AppSpacing.screen)
    }

    private var sensorCard: some View {
        let state = recorder?.hrState ?? .idle
        return HStack(spacing: 12) {
            Image(systemName: state.isConnected ? "heart.fill" : "heart")
                .font(.app(20))
                .foregroundStyle(state.isConnected ? AppColor.red : AppColor.muted)
            VStack(alignment: .leading, spacing: 2) {
                Text(state.label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColor.text)
                if state.isConnected, let hr = recorder?.currentHR {
                    Text("\(hr) bpm")
                        .font(.caption)
                        .foregroundStyle(AppColor.red)
                } else if !state.isConnected {
                    Text("Polar H10 anlegen und Elektroden anfeuchten")
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                }
            }
            Spacer()
            if !state.isConnected {
                Button("Verbinden") { recorder?.connectSensor() }
                    .buttonStyle(OutlineButtonStyle())
            }
        }
        .padding(AppSpacing.card)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.border, lineWidth: 1))
    }

    private var gpsCard: some View {
        let state = recorder?.gpsState ?? .idle
        return HStack(spacing: 12) {
            Image(systemName: state.isActive ? "location.fill" : "location")
                .font(.app(20))
                .foregroundStyle(state.isActive ? AppColor.green : AppColor.muted)
            VStack(alignment: .leading, spacing: 2) {
                Text(state.label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColor.text)
                if case .denied = state {
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

    // MARK: Helfer

    static func makeHeartRateSource(demo: Bool) -> HeartRateSource {
        #if targetEnvironment(simulator)
        return SimulatedHeartRateSource()
        #else
        return demo ? SimulatedHeartRateSource() : BleHeartRateSource()
        #endif
    }

    static func makeLocationSource(demo: Bool) -> LocationSource {
        #if targetEnvironment(simulator)
        return SimulatedLocationSource()
        #else
        return demo ? SimulatedLocationSource() : CoreLocationSource()
        #endif
    }

    static func format(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
}
