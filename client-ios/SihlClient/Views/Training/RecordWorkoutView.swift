import SwiftUI

// MARK: - RecordWorkoutView (Einstieg: Aktivität wählen + Gurt verbinden)

/// Phase-1-Training-Tracking: Herzfrequenz-Aufzeichnung mit Polar H10
/// (bzw. jedem BLE-Gurt). Wird aus dem Training-Tab gepusht.
struct RecordWorkoutView: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var activity: WorkoutActivity = .kraft
    @State private var recorder: WorkoutRecorder?
    @State private var showSession = false
    @State private var recovered: WorkoutRecorder.Snapshot?

    private var isDemo: Bool { auth.clientId == "demo" }

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.stack) {
                    Text("Aktivität")
                        .font(.subheadline.bold())
                        .foregroundStyle(AppColor.text)

                    activityGrid

                    Text("Herzfrequenz-Sensor")
                        .font(.subheadline.bold())
                        .foregroundStyle(AppColor.text)
                        .padding(.top, 8)

                    sensorCard

                    Button("Training starten") {
                        recorder?.startRecording(activity)
                        showSession = true
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 12)

                    if !(recorder?.hrState.isConnected ?? false) {
                        Text("Du kannst auch ohne Gurt starten — dann wird nur die Dauer erfasst.")
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
                recorder = WorkoutRecorder(source: Self.makeSource(demo: isDemo))
            }
            recovered = WorkoutRecorder.pendingSnapshot()
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
                    samples: snap.samples
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
        } message: { snap in
            Text("\(snap.activity.rawValue) · \(Self.format(snap.elapsed)) · \(snap.samples.count) HF-Punkte")
        }
    }

    // MARK: Bausteine

    private var activityGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: AppSpacing.stack),
                            GridItem(.flexible())], spacing: AppSpacing.stack) {
            ForEach(WorkoutActivity.allCases) { a in
                let selected = a == activity
                VStack(spacing: 8) {
                    Image(systemName: a.icon)
                        .font(.system(size: 26))
                        .foregroundStyle(selected ? AppColor.primary : AppColor.muted)
                    Text(a.rawValue)
                        .font(.footnote.weight(selected ? .bold : .regular))
                        .foregroundStyle(selected ? AppColor.text : AppColor.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.card)
                .background(AppColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.card)
                    .stroke(selected ? AppColor.primary : AppColor.border, lineWidth: selected ? 1.5 : 1))
                .contentShape(Rectangle())
                .onTapGesture { activity = a }
            }
        }
    }

    private var sensorCard: some View {
        let state = recorder?.hrState ?? .idle
        return HStack(spacing: 12) {
            Image(systemName: state.isConnected ? "heart.fill" : "heart")
                .font(.system(size: 20))
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

    // MARK: Helfer

    static func makeSource(demo: Bool) -> HeartRateSource {
        #if targetEnvironment(simulator)
        return SimulatedHeartRateSource()
        #else
        return demo ? SimulatedHeartRateSource() : BleHeartRateSource()
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
    }

    // MARK: Live

    private var liveView: some View {
        VStack(spacing: 24) {
            HStack {
                Label(recorder.activity.rawValue, systemImage: recorder.activity.icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.muted)
                Spacer()
                sensorBadge
            }
            .padding(.top, 24)

            Spacer()

            // Dauer
            Text(recorder.durationString)
                .font(.system(size: 56, weight: .heavy).monospacedDigit())
                .foregroundStyle(AppColor.text)

            // Herzfrequenz gross
            VStack(spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(AppColor.red)
                    Text(recorder.currentHR.map { "\($0)" } ?? "–")
                        .font(.system(size: 88, weight: .black).monospacedDigit())
                        .foregroundStyle(AppColor.red)
                    Text("bpm")
                        .font(.title3)
                        .foregroundStyle(AppColor.muted)
                }
                HStack(spacing: 20) {
                    statMini("Ø", recorder.avgHR)
                    statMini("Max", recorder.maxHR)
                }
            }

            Spacer()

            // Steuerung
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
        .alert("Training beenden?", isPresented: $confirmStop) {
            Button("Weiter aufzeichnen", role: .cancel) {}
            Button("Beenden") { recorder.finish() }
        }
    }

    private var sensorBadge: some View {
        let state = recorder.hrState
        return HStack(spacing: 6) {
            Circle()
                .fill(state.isConnected ? AppColor.green : AppColor.orange)
                .frame(width: 8, height: 8)
            Text(state.isConnected ? "Gurt verbunden" : state.label)
                .font(.caption)
                .foregroundStyle(AppColor.muted)
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

                // Statistiken
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
                            .frame(height: 200)
                    }
                    .padding(AppSpacing.card)
                    .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.card))
                } else {
                    Text("Keine Herzfrequenz-Daten aufgezeichnet")
                        .font(.footnote)
                        .foregroundStyle(AppColor.muted)
                        .frame(maxWidth: .infinity)
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
                .font(.system(size: 18, weight: .black).monospacedDigit())
                .foregroundStyle(color)
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
            samples: recorder.samples
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
