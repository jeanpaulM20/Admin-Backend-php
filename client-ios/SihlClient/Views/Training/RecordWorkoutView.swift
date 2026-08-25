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

// MARK: - WorkoutSessionView (Vollbild: Aufnahme → Zusammenfassung)

private struct WorkoutSessionView: View {
    @Environment(AuthViewModel.self) private var auth
    let recorder: WorkoutRecorder
    let isDemo: Bool
    let onDone: () -> Void

    @State private var confirmStop = false
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var confirmDiscard = false
    @State private var routeToast: AppToast?
    @State private var wasOffRoute = false

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            if recorder.phase == .finished {
                summary
            } else {
                liveView
            }
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        // Off-Route-Hinweis (T3): sanfter Toast bei Verlassen/Wiederfinden der Route
        .onChange(of: recorder.isOffRoute) { _, off in
            if off {
                wasOffRoute = true
                routeToast = AppToast(
                    message: "≈\(Int(recorder.offRouteDistance)) m neben der Route",
                    style: .neutral)
            } else if wasOffRoute {
                routeToast = AppToast(message: "Zurück auf der Route", style: .success)
            }
        }
        .appToast($routeToast, bottomPadding: 100)
    }

    // Kamera-Führung der Live-Karte: folgt der Position, bis der User
    // die Karte selbst bewegt; der Zentrier-Button holt ihn zurück.
    @State private var followUser = true
    @State private var liveCamera: MapCameraPosition = .automatic
    @State private var programmaticMove = false

    /// Für die Kartendarstellung reduzierte Koordinaten (Render-Kosten).
    private var displayCoordinates: [CLLocationCoordinate2D] {
        let coords = recorder.trackCoordinates
        guard coords.count > 600 else { return coords }
        let stride = coords.count / 500
        return coords.enumerated().compactMap { $0.offset % stride == 0 ? $0.element : nil }
    }

    // MARK: Live

    private var liveView: some View {
        VStack(spacing: 0) {
            // Live-Karte (nur Outdoor)
            if recorder.activity.usesGPS {
                liveMap
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                    .padding(.horizontal, AppSpacing.screen)
                    .padding(.top, 16)
            }

            VStack(spacing: 20) {
                HStack {
                    Label(recorder.activity.rawValue, systemImage: recorder.activity.icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.muted)
                    Spacer()
                    sensorBadge
                }
                .padding(.top, 16)

                Spacer(minLength: 4)

                Text(recorder.durationString)
                    .font(.app(recorder.activity.usesGPS ? 44 : 56,
                                  weight: .heavy).monospacedDigit())
                    .foregroundStyle(AppColor.text)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "heart.fill")
                        .font(.app(24))
                        .foregroundStyle(AppColor.red)
                    Text(recorder.currentHR.map { "\($0)" } ?? "–")
                        .font(.app(recorder.activity.usesGPS ? 56 : 88,
                                      weight: .black).monospacedDigit())
                        .foregroundStyle(AppColor.red)
                    Text("bpm")
                        .font(.title3)
                        .foregroundStyle(AppColor.muted)
                }

                if recorder.activity.usesGPS {
                    HStack(spacing: 0) {
                        liveStat("Distanz", recorder.distanceString)
                        liveStat(recorder.activity == .rad ? "Tempo" : "Pace", recorder.paceString)
                        liveStat("Höhenmeter", "\(Int(recorder.elevationGain)) m")
                    }
                } else {
                    HStack(spacing: 20) {
                        statMini("Ø", recorder.avgHR)
                        statMini("Max", recorder.maxHR)
                    }
                }

                Spacer(minLength: 4)

                HStack(spacing: AppSpacing.stack) {
                    Button(recorder.phase == .paused ? "Weiter" : "Pause") {
                        recorder.phase == .paused ? recorder.resume() : recorder.pause()
                    }
                    .buttonStyle(OutlineButtonStyle())
                    .frame(maxWidth: .infinity)

                    Button("Beenden") { confirmStop = true }
                        .buttonStyle(PrimaryButtonStyle(fill: AppColor.red))
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, AppSpacing.screen)
        }
        .alert("Training beenden?", isPresented: $confirmStop) {
            Button("Weiter aufzeichnen", role: .cancel) {}
            Button("Beenden") { recorder.finish() }
        }
    }

    private var liveMap: some View {
        Map(position: $liveCamera) {
            // Tour-Route (T3): geplante Route blau gestrichelt — klar
            // unterscheidbar von der eigenen (orangen) Spur
            ForEach(recorder.routeSegments.indices, id: \.self) { i in
                MapPolyline(coordinates: recorder.routeSegments[i])
                    .stroke(AppColor.blue.opacity(0.85),
                            style: StrokeStyle(lineWidth: 3, dash: [6, 4]))
            }
            // Start-/Ziel-Marker der Route (Rundtour: ein gemeinsamer Punkt)
            if let start = recorder.routeSegments.first?.first {
                Annotation(routeEndsMeet ? "Start/Ziel" : "Start", coordinate: start) {
                    routeFlag
                }
            }
            if !routeEndsMeet, let end = recorder.routeSegments.last?.last {
                Annotation("Ziel", coordinate: end) {
                    routeFlag
                }
            }
            if displayCoordinates.count >= 2 {
                MapPolyline(coordinates: displayCoordinates)
                    .stroke(AppColor.track, lineWidth: 4)
            }
            if let last = recorder.trackCoordinates.last {
                Annotation("", coordinate: last) {
                    ZStack {
                        Circle().fill(AppColor.track.opacity(0.3)).frame(width: 22, height: 22)
                        Circle().fill(AppColor.track).frame(width: 12, height: 12)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                    }
                }
            }
        }
        .mapStyle(.standard)
        // Manuelles Verschieben beendet die Verfolgung …
        .onMapCameraChange(frequency: .onEnd) { _ in
            if !programmaticMove { followUser = false }
        }
        // … neue GPS-Punkte zentrieren die Kamera, solange sie folgt
        .onChange(of: recorder.trackCoordinates.count) { _, _ in
            guard followUser, let last = recorder.trackCoordinates.last else { return }
            recenter(on: last, animated: false)
        }
        // Zentrier-Button: zurück zur eigenen Position
        .overlay(alignment: .bottomTrailing) {
            Button {
                followUser = true
                if let last = recorder.trackCoordinates.last {
                    recenter(on: last, animated: true)
                }
            } label: {
                Image(systemName: followUser ? "location.fill" : "location")
                    .font(.app(15, weight: .semibold))
                    .foregroundStyle(followUser ? AppColor.primary : AppColor.muted)
                    .frame(width: 40, height: 40)
                    .background(AppColor.surface, in: Circle())
                    .overlay(Circle().stroke(AppColor.border, lineWidth: 1))
            }
            .padding(10)
        }
    }

    /// Start und Ziel der Route liegen (fast) aufeinander → Rundtour.
    private var routeEndsMeet: Bool {
        guard let a = recorder.routeSegments.first?.first,
              let b = recorder.routeSegments.last?.last else { return true }
        return CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude)) < 50
    }

    private var routeFlag: some View {
        Image(systemName: "flag.fill")
            .font(.app(11, weight: .semibold))
            .foregroundStyle(AppColor.white)
            .frame(width: 24, height: 24)
            .background(AppColor.blue, in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: 1.5))
    }

    /// Kamera auf eine Koordinate setzen (~800-m-Ausschnitt).
    private func recenter(on coord: CLLocationCoordinate2D, animated: Bool) {
        programmaticMove = true
        let region = MKCoordinateRegion(
            center: coord,
            span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008))
        if animated {
            withAnimation(.easeInOut(duration: 0.4)) { liveCamera = .region(region) }
        } else {
            liveCamera = .region(region)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { programmaticMove = false }
    }

    private func liveStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.app(20, weight: .bold).monospacedDigit())
                .foregroundStyle(AppColor.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppColor.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private var sensorBadge: some View {
        let hr = recorder.hrState
        let gps = recorder.gpsState
        return HStack(spacing: 10) {
            HStack(spacing: 5) {
                Circle()
                    .fill(hr.isConnected ? AppColor.green : AppColor.orange)
                    .frame(width: 8, height: 8)
                Text("Gurt").font(.caption).foregroundStyle(AppColor.muted)
            }
            if recorder.activity.usesGPS {
                HStack(spacing: 5) {
                    Circle()
                        .fill(gps.isActive ? AppColor.green : AppColor.orange)
                        .frame(width: 8, height: 8)
                    Text("GPS").font(.caption).foregroundStyle(AppColor.muted)
                }
            }
        }
    }

    private func statMini(_ label: String, _ value: Int?) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.caption).foregroundStyle(AppColor.muted)
            Text(value.map { "\($0)" } ?? "–")
                .font(.callout.bold().monospacedDigit())
                .foregroundStyle(AppColor.text)
        }
    }

    // MARK: Zusammenfassung

    private var summary: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.stack) {
                HStack {
                    Label(recorder.activity.rawValue, systemImage: recorder.activity.icon)
                        .font(.headline)
                        .foregroundStyle(AppColor.text)
                    Spacer()
                    Text(recorder.durationString)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(AppColor.muted)
                }
                .padding(.top, 24)

                // Route (nur Outdoor mit Track); Tour-Route als gedeckte Linie dahinter
                if recorder.activity.usesGPS, displayCoordinates.count >= 2 {
                    Map {
                        ForEach(recorder.routeSegments.indices, id: \.self) { i in
                            MapPolyline(coordinates: recorder.routeSegments[i])
                                .stroke(AppColor.blue.opacity(0.85),
                                        style: StrokeStyle(lineWidth: 3, dash: [6, 4]))
                        }
                        MapPolyline(coordinates: displayCoordinates)
                            .stroke(AppColor.track, lineWidth: 4)
                    }
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                    .allowsHitTesting(false)
                }

                // Statistiken
                if recorder.activity.usesGPS {
                    HStack(spacing: AppSpacing.stack) {
                        summaryStat("Distanz", recorder.distanceString, "", AppColor.text)
                        summaryStat(recorder.activity == .rad ? "Tempo" : "Pace",
                                    recorder.paceString, "", AppColor.text)
                        summaryStat("Höhenmeter", "\(Int(recorder.elevationGain))", "m", AppColor.text)
                    }
                }
                HStack(spacing: AppSpacing.stack) {
                    summaryStat("Ø HF", recorder.avgHR.map { "\($0)" } ?? "–", "bpm", AppColor.primary)
                    summaryStat("Max HF", recorder.maxHR.map { "\($0)" } ?? "–", "bpm", AppColor.red)
                    summaryStat("Messwerte", "\(recorder.samples.count)", "", AppColor.muted)
                }

                // HF-Kurve (geteiltes Chart aus Analytics)
                if recorder.samples.count >= 2 {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Herzfrequenz-Verlauf (bpm)")
                            .font(.callout.bold())
                            .foregroundStyle(AppColor.text)
                        HrLineChart(chart: recorder.hrPoints)
                            .frame(height: 180)
                    }
                    .padding(AppSpacing.card)
                    .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.card))
                }

                if let err = saveError {
                    InlineErrorBanner(message: err)
                }

                Button(isSaving ? "Speichern…" : "Training speichern") { save() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isSaving)
                    .padding(.top, 8)

                Button("Verwerfen") { confirmDiscard = true }
                    .font(.subheadline)
                    .foregroundStyle(AppColor.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)

                if isDemo {
                    Text("Demo-Modus: Das Training wird nicht ans Backend übertragen.")
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.bottom, AppSpacing.bottomInset)
        }
        .alert("Training verwerfen?", isPresented: $confirmDiscard) {
            Button("Abbrechen", role: .cancel) {}
            Button("Verwerfen", role: .destructive) {
                WorkoutRecorder.clearSnapshot()
                onDone()
            }
        } message: {
            Text("Die Aufzeichnung wird endgültig gelöscht.")
        }
    }

    private func summaryStat(_ label: String, _ value: String, _ unit: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.app(17, weight: .black).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if !unit.isEmpty {
                Text(unit).font(.caption2).foregroundStyle(AppColor.muted)
            }
            Text(label).font(.caption2).foregroundStyle(AppColor.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.card))
    }

    // MARK: Speichern

    private func save() {
        guard let started = recorder.startedAt else { return }
        if isDemo {
            WorkoutRecorder.clearSnapshot()
            onDone()
            return
        }
        isSaving = true
        saveError = nil
        let payload = WorkoutUploadService.Payload(
            clientId: auth.clientId ?? "",
            trainingType: recorder.activity.rawValue,
            startedAt: started,
            duration: recorder.durationString,
            samples: recorder.samples,
            track: recorder.track.isEmpty ? nil : recorder.track,
            distanceMeters: recorder.distanceMeters > 0 ? recorder.distanceMeters : nil,
            elevationGain: recorder.elevationGain > 0 ? recorder.elevationGain : nil
        )
        Task {
            do {
                try await WorkoutUploadService.shared.upload(payload)
                WorkoutRecorder.clearSnapshot()
                onDone()
            } catch {
                // Offline o. Ä.: in die Warteschlange — wird beim nächsten
                // App-Start nachgereicht, nichts geht verloren.
                WorkoutUploadService.shared.queue(payload)
                WorkoutRecorder.clearSnapshot()
                saveError = "Kein Netz — Training gespeichert und wird automatisch nachgereicht."
                isSaving = false
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                onDone()
            }
        }
    }
}
