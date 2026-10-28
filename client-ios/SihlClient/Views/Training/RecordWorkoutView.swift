import SwiftUI

// MARK: - RecordWorkoutView (Einstieg: Aktivität wählen und starten)

/// Training-Tracking: Herzfrequenz (Polar H10 / BLE-Gurt) + GPS-Route
/// bei Outdoor-Aktivitäten. Die Sensor-Einrichtung liegt im Profil
/// (Profil → Sensoren) — hier wird gewählt und gestartet. „Trainingspläne"
/// ist ein Reiter in derselben Reihe: gewählt zeigt er die Pläne an Stelle
/// von Start-Knopf und Galerie und sortiert sich wie die Aktivitäten nach
/// letzter Nutzung.
struct RecordWorkoutView: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(RecordingLauncher.self) private var launcher
    @Environment(TrainingViewModel.self) private var training

    /// Route, der gefolgt wird (T3/Phase 5): kommt über den Startbefehl
    /// von Planer, Tour-Detail oder Assistent und bleibt bis zum Ende der
    /// Aufzeichnung (oder bis sie hier entfernt wird).
    @State private var tour: TourRoute?
    /// Countdown vor dem Autostart einer übergebenen Route (3 → 1), nil = keiner
    @State private var countdown: Int?
    @State private var countdownTask: Task<Void, Never>?
    /// Sichtbar? Mit gepushtem Profil im Start-Tab liegt diese Ansicht
    /// verdeckt darunter — dann kein Autostart ins Unsichtbare
    @State private var isVisible = false

    @State private var activity: WorkoutActivity = WorkoutActivity.lastUsed ?? .joggen
    /// Neu sortiert bei jedem Erscheinen der Startseite — nach Rückkehr aus
    /// den Plänen, nach Tab-Wechsel und nach dem Ende einer Aufzeichnung
    /// (die gestartete Aktivität rückt dann nach vorne). Nie beim Antippen,
    /// sonst tauschten die Chips unter dem Finger die Plätze.
    @State private var chipOrder: [StartChip] = StartChip.ordered(selected: WorkoutActivity.lastUsed ?? .joggen)
    /// Reiter „Trainingspläne" gewählt? Startet so, wie zuletzt verlassen.
    @State private var showingPlans = StartChip.plansFirst
    /// Erhöhen lädt die Galerie neu (Ziehen zum Aktualisieren)
    @State private var galleryReload = 0
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
        .navigationTitle(showingPlans ? "Trainingspläne" : "Training aufzeichnen")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if recorder == nil {
                recorder = WorkoutRecorder(
                    source: Self.makeHeartRateSource(demo: isDemo),
                    gpsSource: Self.makeLocationSource(demo: isDemo)
                )
            }
            // Eine liegende Route hält ihre Aktivität vorne (abgebrochener
            // Countdown, Tab-Wechsel) — bis sie gestartet oder entfernt ist
            chipOrder = StartChip.ordered(selected: activity, routeActivity: tour?.workoutActivity)
            if !showSession { refreshRecovered() }
            isVisible = true
            takeLaunchedRoute()
        }
        // „Tour starten" aus Planer/Detail/Assistent, während die Startseite
        // schon sichtbar ist (der Tab-Wechsel allein löst kein onAppear aus)
        .onChange(of: launcher.requestCount) { _, _ in takeLaunchedRoute() }
        .onDisappear {
            isVisible = false
            // Tab gewechselt während des Countdowns: nicht im Hintergrund
            // starten — die Route bleibt liegen, „Training starten" nimmt sie
            cancelCountdown()
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

                    if showingPlans {
                        // Reiter „Trainingspläne": die Pläne an Stelle von
                        // Start-Knopf und Galerie
                        TrainingView(embedded: true)
                            .padding(.top, 4)
                    } else {
                        Button("Training starten") { beginRecording() }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.top, 12)

                        Text("Der in Profil → Sensoren gewählte Gurt verbindet sich beim Start. Ohne Gurt werden nur Dauer\(activity.usesGPS ? " und Route" : "") erfasst.")
                            .font(.caption)
                            .foregroundStyle(AppColor.muted)
                            .frame(maxWidth: .infinity, alignment: .center)

                        // Trainings-Galerie (F1): Fotos der gewählten Aktivität
                        WorkoutGalleryView(activity: activity, reloadToken: galleryReload) { photo in
                            repeatFromGallery(photo.workoutActivity)
                        }
                        .padding(.top, AppSpacing.card)
                    }
                }
                .padding(.horizontal, AppSpacing.screen)
                .padding(.top, 16)
                .padding(.bottom, AppSpacing.bottomInset)
        }
        // Ziehen lädt, was gerade gezeigt wird: Pläne bzw. Galerie
        .refreshable {
            if showingPlans {
                if !isDemo, let id = auth.clientId { await training.fetch(clientId: id) }
            } else {
                galleryReload += 1
            }
        }
    }

    // MARK: Übergabe einer Route (Phase 5.1)

    /// Route vom Startbefehl übernehmen: in den Recorder laden, Aktivität
    /// vorwählen und mit Countdown starten. „Tour starten" war bereits der
    /// Startbefehl — ein zweites „Training starten" entfällt.
    private func takeLaunchedRoute() {
        // Erst prüfen, dann abholen — sonst ginge die Route verloren. Ist die
        // Startseite (noch) nicht sichtbar — Tab-Wechsel läuft, oder ein
        // gepushtes Profil liegt darüber —, bleibt die Route liegen und wird
        // beim nächsten Erscheinen übernommen.
        guard isVisible, let recorder, !showSession, let route = launcher.takePendingRoute() else { return }
        tour = route
        recorder.setRoute(route)
        activity = route.workoutActivity
        // Route kommt → zurück auf die Aktivität (auch wenn Pläne gewählt waren)
        if showingPlans {
            showingPlans = false
            StartChip.noteSelectedActivity()
        }
        chipOrder = StartChip.ordered(selected: activity, routeActivity: activity)
        // Liegt ein unterbrochenes Training zur Rückfrage an, nicht automatisch
        // starten: Alert und Vollbild-Session zugleich würden sich blockieren.
        // Die Route bleibt liegen — „Training starten" nimmt sie mit.
        refreshRecovered()
        guard recovered == nil else { return }
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

    /// „Nochmal starten" aus der Galerie: dieselbe Einheit wie auf dem Foto.
    /// Entscheid: Das Foto bestimmt die Aktivität. Eine liegende Route mit
    /// anderer Aktivität gehört nicht zu dieser Einheit und wird verworfen;
    /// passt sie, wird ihr gefolgt. Gestartet wird wie überall über
    /// `beginRecording()` (Prüfung Wiederherstellung/laufende Session).
    private func repeatFromGallery(_ photoActivity: WorkoutActivity) {
        if let tour, tour.workoutActivity != photoActivity { removeRoute() }
        cancelCountdown()
        activity = photoActivity
        Task { @MainActor in
            // Detail-Sheet erst schliessen lassen, dann das Vollbild zeigen
            try? await Task.sleep(nanoseconds: 400_000_000)
            beginRecording()
        }
    }

    /// Offenes Training des angemeldeten Kontos zur Rückfrage holen.
    private func refreshRecovered() {
        guard !isDemo else { recovered = nil; return }
        // Laufende bzw. gerade beendete eigene Aufzeichnung ist kein „unterbrochenes" Training
        var excluded = RecoveryUploads.inFlight
        if let active = recorder?.recordingId { excluded.insert(active) }
        recovered = WorkoutRecorder.pendingSnapshot(for: auth.clientId, excluding: excluded)
    }

    private func beginRecording() {
        guard !showSession, recovered == nil else { return }
        // Ein offenes Training zuerst klären (Speichern/Verwerfen) — sonst
        // bliebe es neben der neuen Aufzeichnung ungeklärt liegen
        refreshRecovered()
        guard recovered == nil else { return }
        StartChip.noteStarted(activity)
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
    /// „Trainingspläne" ist ein Reiter wie die anderen: gewählt grün
    /// hervorgehoben, zeigt die Pläne darunter und wandert nach Nutzung nach
    /// vorne.
    private var activityGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chipOrder) { chip in
                    switch chip {
                    case .plans:           trainingPlansChip
                    case .activity(let a): activityChip(a)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screen)
        }
        .padding(.horizontal, -AppSpacing.screen)
    }

    private func activityChip(_ a: WorkoutActivity) -> some View {
        let selected = !showingPlans && a == activity
        return Button {
            activity = a
            if showingPlans {
                showingPlans = false
                StartChip.noteSelectedActivity()
            }
        } label: {
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
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint(selected ? "" : "Wählt \(a.rawValue) für das nächste Training")
    }

    /// Reiter wie die Aktivitäts-Chips: gewählt grün hervorgehoben (Icon
    /// dann weiss statt Brass). Wählen zählt als Nutzung — beim nächsten
    /// Erscheinen steht der Chip vorne und ist wieder gewählt.
    private var trainingPlansChip: some View {
        let selected = showingPlans
        return Button {
            guard !showingPlans else { return }
            showingPlans = true
            StartChip.noteSelectedPlans()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "list.clipboard").font(.app(13))
                    .foregroundStyle(selected ? AppColor.white : AppColor.brass)
                Text("Trainingspläne").font(.footnote.weight(selected ? .bold : .medium))
                    .foregroundStyle(selected ? AppColor.white : AppColor.muted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(selected ? AppColor.primary : AppColor.surface,
                        in: RoundedRectangle(cornerRadius: AppRadius.control))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.control)
                .stroke(selected ? AppColor.primary : AppColor.border, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint(selected ? "" : "Zeigt deine Trainingspläne")
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

/// Wiederherstellungen, deren Upload gerade läuft — der Snapshot bleibt bis
/// zum Erfolg liegen, soll aber nicht erneut zur Rückfrage erscheinen.
@MainActor
enum RecoveryUploads {
    static var inFlight: Set<String> = []
}

/// Crash-/Kill-Recovery: liegen gebliebenes Training nachreichen oder verwerfen.
/// Es erscheinen nur Snapshots des angemeldeten Kontos (siehe
/// `pendingSnapshot(for:)`); fremde bleiben für ihr Konto liegen.
private struct RecoveryAlert: ViewModifier {
    @Binding var recovered: WorkoutRecorder.Snapshot?
    let isDemo: Bool
    let clientId: String?

    @State private var failure: String?

    func body(content: Content) -> some View {
        content.alert("Unterbrochenes Training gefunden", isPresented: Binding(
            get: { recovered != nil }, set: { if !$0 { recovered = nil } }
        ), presenting: recovered) { (snap: WorkoutRecorder.Snapshot) in
            Button("Speichern") {
                recovered = nil
                save(snap)
            }
            Button("Verwerfen", role: .destructive) {
                WorkoutRecorder.clearSnapshot(recordingId: snap.recordingId)
                WorkoutPhotoService.clearActivePhoto(recordingId: snap.recordingId)
                recovered = nil
            }
            Button("Später", role: .cancel) {}
        } message: { (snap: WorkoutRecorder.Snapshot) in
            Text("\(snap.activity.rawValue) · \(RecordWorkoutView.format(snap.elapsed)) · \(snap.samples.count) HF-Punkte\n\nEin neues Training startet erst, wenn dieses gespeichert oder verworfen ist.")
        }
        .alert("Training nicht gespeichert", isPresented: Binding(
            get: { failure != nil }, set: { if !$0 { failure = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(failure ?? "")
        }
    }

    private func save(_ snap: WorkoutRecorder.Snapshot) {
        let rid = snap.recordingId
        // Doppelte Absicherung: nur unter dem eigenen Konto nachreichen.
        // Sonst nichts löschen — der Snapshot gehört einem echten Konto.
        guard !isDemo, let clientId, let rid,
              snap.ownerClientId == nil || snap.ownerClientId == clientId else { return }
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
        RecoveryUploads.inFlight.insert(rid)
        Task { @MainActor in
            defer { RecoveryUploads.inFlight.remove(rid) }
            let reviewId: Int?
            do {
                reviewId = try await WorkoutUploadService.shared.upload(payload)
            } catch {
                if case .rejected(let reason) = WorkoutUploadService.classify(error) {
                    // Endgültig abgelehnt: Snapshot bleibt, Nutzer entscheidet
                    failure = "\(reason). Das Training bleibt auf dem Gerät, bis du es verwirfst."
                    return
                }
                reviewId = nil
            }
            guard let reviewId else {
                // Netz/Sitzung oder ohne id: Training UND Foto in die Warteschlange
                if let photoData {
                    payload.photoFile = WorkoutUploadService.shared.stashPhoto(photoData)
                }
                guard WorkoutUploadService.shared.queue(payload) else { return }
                WorkoutPhotoService.clearActivePhoto(recordingId: rid)
                WorkoutRecorder.clearSnapshot(recordingId: rid)
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
            WorkoutRecorder.clearSnapshot(recordingId: rid)
        }
    }
}
