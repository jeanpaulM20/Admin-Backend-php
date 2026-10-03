import SwiftUI

// MARK: - RecordWorkoutView (Einstieg: Aktivität wählen und starten)

/// Training-Tracking: Herzfrequenz (Polar H10 / BLE-Gurt) + GPS-Route
/// bei Outdoor-Aktivitäten. Die Sensor-Einrichtung liegt im Profil
/// (Profil → Sensoren) — hier wird nur gewählt und gestartet.
struct RecordWorkoutView: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(RecordingLauncher.self) private var launcher

    /// Route, der gefolgt wird (T3/Phase 5): kommt über den Startbefehl
    /// von Planer, Tour-Detail oder Assistent und bleibt bis zum Ende der
    /// Aufzeichnung (oder bis sie hier entfernt wird).
    @State private var tour: TourRoute?
    /// Countdown vor dem Autostart einer übergebenen Route (3 → 1), nil = keiner
    @State private var countdown: Int?
    @State private var countdownTask: Task<Void, Never>?

    @State private var activity: WorkoutActivity = WorkoutActivity.lastUsed ?? .joggen
    /// Einmal beim Erscheinen festgelegt — sonst würden die Chips während
    /// der Auswahl unter dem Finger die Plätze tauschen.
    @State private var activityOrder: [WorkoutActivity] = WorkoutActivity.orderedByRecency()
    @State private var recorder: WorkoutRecorder?
    @State private var showSession = false
    @State private var recovered: WorkoutRecorder.Snapshot?

    private var isDemo: Bool { auth.clientId == "demo" }

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            content
            if let countdown { countdownOverlay(countdown) }
        }
        .navigationTitle("Training aufzeichnen")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if recorder == nil {
                recorder = WorkoutRecorder(
                    source: Self.makeHeartRateSource(demo: isDemo),
                    gpsSource: Self.makeLocationSource(demo: isDemo)
                )
                activityOrder = WorkoutActivity.orderedByRecency(preferring: activity)
            }
            recovered = WorkoutRecorder.pendingSnapshot()
            takeLaunchedRoute()
        }
        // „Tour starten" aus Planer/Detail/Assistent, während die Startseite
        // schon sichtbar ist (der Tab-Wechsel allein löst kein onAppear aus)
        .onChange(of: launcher.requestCount) { _, _ in takeLaunchedRoute() }
        .onDisappear {
            // Nur aufräumen, wenn keine Session läuft
            if !showSession { recorder?.teardown() }
        }
        .fullScreenCover(isPresented: $showSession, onDismiss: {
            // Frisch für die nächste Aufzeichnung — dieselbe Instanz bleibt
            // bestehen; eine übergebene Route ist mit der Session erledigt
            recorder?.reset()
            recorder?.clearRoute()
            tour = nil
        }) {
            if let recorder {
                WorkoutSessionView(recorder: recorder, isDemo: isDemo) {
                    showSession = false
                }
            } else {
                Color.clear.onAppear { showSession = false }
            }
        }
        .modifier(RecoveryAlert(recovered: $recovered, isDemo: isDemo, clientId: auth.clientId))
    }

    private var content: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.stack) {
                    if let tour { tourCard(tour) }

                    Text("Aktivität")
                        .font(.subheadline.bold())
                        .foregroundStyle(AppColor.text)

                    activityGrid

                    Button("Training starten") { beginRecording() }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 12)

                    Text("Der gekoppelte Gurt verbindet sich beim Start. Ohne Gurt werden nur Dauer\(activity.usesGPS ? " und Route" : "") erfasst.")
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                        .frame(maxWidth: .infinity, alignment: .center)

                    // Trainings-Galerie (F1): Fotos der gewählten Aktivität
                    WorkoutGalleryView(activity: activity) { photo in
                        activity = photo.workoutActivity
                        WorkoutActivity.rememberUsed(photo.workoutActivity)
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 400_000_000)
                            recorder?.startRecording(photo.workoutActivity, clientId: auth.clientId)
                            showSession = true
                        }
                    }
                    .padding(.top, AppSpacing.card)
                }
                .padding(.horizontal, AppSpacing.screen)
                .padding(.top, 16)
                .padding(.bottom, AppSpacing.bottomInset)
        }
    }

    // MARK: Übergabe einer Route (Phase 5.1)

    /// Route vom Startbefehl übernehmen: in den Recorder laden, Aktivität
    /// vorwählen und mit Countdown starten. „Tour starten" war bereits der
    /// Startbefehl — ein zweites „Training starten" entfällt.
    private func takeLaunchedRoute() {
        guard let route = launcher.takePendingRoute(), let recorder, !showSession else { return }
        tour = route
        recorder.setRoute(route)
        activity = route.workoutActivity
        activityOrder = WorkoutActivity.orderedByRecency(preferring: activity)
        startCountdown()
    }

    private func startCountdown() {
        countdownTask?.cancel()
        countdown = 3
        countdownTask = Task { @MainActor in
            for value in stride(from: 3, through: 1, by: -1) {
                countdown = value
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
            }
            countdown = nil
            beginRecording()
        }
    }

    /// Abbrechen lässt die Route auf der Startseite — „Training starten"
    /// nimmt sie dann manuell mit, „Route entfernen" lässt sie weg.
    private func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        countdown = nil
    }

    private func beginRecording() {
        WorkoutActivity.rememberUsed(activity)
        recorder?.startRecording(activity, clientId: auth.clientId)
        showSession = true
    }

    private func removeRoute() {
        cancelCountdown()
        recorder?.clearRoute()
        tour = nil
    }

    private func countdownOverlay(_ value: Int) -> some View {
        ZStack {
            AppColor.background.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 18) {
                Text(tour?.name ?? "Route")
                    .font(.headline)
                    .foregroundStyle(AppColor.text)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.screen)
                Text("\(value)")
                    .font(.app(96, weight: .black))
                    .foregroundStyle(AppColor.cta)
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.easeOut(duration: 0.25), value: value)
                Text("Aufzeichnung startet …")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.muted)
                Button("Abbrechen") { cancelCountdown() }
                    .buttonStyle(OutlineButtonStyle())
                    .padding(.horizontal, 60)
                    .padding(.top, 10)
            }
        }
        .transition(.opacity)
        .accessibilityLabel("Aufzeichnung startet in \(value) Sekunden")
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
            Button { removeRoute() } label: {
                Image(systemName: "xmark")
                    .font(.app(12, weight: .semibold))
                    .foregroundStyle(AppColor.muted)
                    .frame(width: 32, height: 32)
                    .background(AppColor.surface2, in: Circle())
            }
            .accessibilityLabel("Route entfernen")
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
                ForEach(activityOrder) { a in
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

// MARK: - RecoveryAlert

/// Crash-/Kill-Recovery: liegen gebliebenes Training nachreichen oder verwerfen.
private struct RecoveryAlert: ViewModifier {
    @Binding var recovered: WorkoutRecorder.Snapshot?
    let isDemo: Bool
    let clientId: String?

    func body(content: Content) -> some View {
        content.alert("Unterbrochenes Training gefunden", isPresented: Binding(
            get: { recovered != nil }, set: { if !$0 { recovered = nil } }
        ), presenting: recovered) { (snap: WorkoutRecorder.Snapshot) in
            Button("Speichern") {
                let rid = snap.recordingId
                WorkoutRecorder.clearSnapshot()
                recovered = nil
                // Fremdes oder Demo-Konto: nicht nachreichen, nur aufräumen
                guard !isDemo, let clientId,
                      snap.ownerClientId == nil || snap.ownerClientId == clientId else {
                    WorkoutPhotoService.clearActivePhoto(recordingId: rid)
                    return
                }
                var payload = WorkoutUploadService.Payload(
                    clientId: clientId,
                    trainingType: snap.activity.rawValue,
                    startedAt: snap.startedAt,
                    duration: RecordWorkoutView.format(snap.elapsed),
                    samples: snap.samples,
                    track: snap.track,
                    distanceMeters: snap.distanceMeters,
                    elevationGain: snap.elevationGain
                )
                payload.clientRecordingId = rid
                let photoData = WorkoutPhotoService.activePhotoData(recordingId: rid)
                Task {
                    let reviewId: Int?
                    do {
                        reviewId = try await WorkoutUploadService.shared.upload(payload)
                    } catch {
                        reviewId = nil
                    }
                    guard let reviewId else {
                        // Offline oder ohne id: Training UND Foto in die Warteschlange
                        if let photoData {
                            payload.photoFile = WorkoutUploadService.shared.stashPhoto(photoData)
                        }
                        WorkoutUploadService.shared.queue(payload)
                        WorkoutPhotoService.clearActivePhoto(recordingId: rid)
                        return
                    }
                    if let photoData, let image = UIImage(data: photoData) {
                        do {
                            try await WorkoutPhotoService.shared.upload(
                                clientId: clientId, reviewId: reviewId, image: image)
                        } catch {
                            let name = WorkoutUploadService.shared.stashPhoto(photoData)
                            WorkoutUploadService.shared.queuePhoto(
                                clientId: clientId, reviewId: reviewId, photoFile: name)
                        }
                    }
                    WorkoutPhotoService.clearActivePhoto(recordingId: rid)
                }
            }
            Button("Verwerfen", role: .destructive) {
                WorkoutRecorder.clearSnapshot()
                WorkoutPhotoService.clearActivePhoto(recordingId: snap.recordingId)
                recovered = nil
            }
            Button("Abbrechen", role: .cancel) {}
        } message: { (snap: WorkoutRecorder.Snapshot) in
            Text("\(snap.activity.rawValue) · \(RecordWorkoutView.format(snap.elapsed)) · \(snap.samples.count) HF-Punkte")
        }
    }
}
