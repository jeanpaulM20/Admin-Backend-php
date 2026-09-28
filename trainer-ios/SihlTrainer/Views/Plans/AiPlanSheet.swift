import SwiftUI

/// KI-Plan generieren — Pendant zum KI-Dialog der Flutter-App, erweitert um
/// Modalität und Belastungsschema (Etappe 3 des Programm-Generators).
struct AiPlanSheet: View {
    let client: Client
    let isPreview: Bool
    let onGenerated: (TrainingPlan) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var request = AiPlanRequest()
    @State private var isGenerating = false
    @State private var outcome: AiPlanOutcome?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if let outcome {
                    result(outcome)
                } else {
                    form
                }
            }
            .background(AppColor.background)
            .navigationTitle(outcome == nil ? "KI-Plan" : "Plan erstellt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(outcome == nil ? "Abbrechen" : "Schliessen") { dismiss() }
                        .foregroundStyle(AppColor.muted)
                }
            }
            .interactiveDismissDisabled(isGenerating)
        }
    }

    // MARK: - Eingabe

    private var form: some View {
        Form {
            Section("Trainingswelt") {
                Picker("Modalität", selection: $request.modality) {
                    ForEach(AiPlanRequest.Modality.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(AppColor.surface)

                if request.modality == .fitness {
                    Picker("Belastungsschema", selection: $request.strengthGoal) {
                        ForEach(AiPlanRequest.StrengthGoal.allCases) { Text($0.title).tag($0) }
                    }
                    .listRowBackground(AppColor.surface)
                }
                if request.modality == .reformer {
                    Picker("Level", selection: $request.level) {
                        ForEach(AiPlanRequest.ReformerLevel.allCases) { Text($0.title).tag($0) }
                    }
                    .listRowBackground(AppColor.surface)
                }
            }

            Section("Ausrichtung") {
                // Reformer: Reihenfolge, Federn und Gerät kommen aus dem
                // Repertoire — nur die Dauer bleibt zu wählen.
                if request.modality != .reformer {
                    Picker("Trainingstyp", selection: $request.trainingType) {
                        ForEach(AiPlanRequest.TrainingType.allCases) { Text($0.title).tag($0) }
                    }
                    .listRowBackground(AppColor.surface)

                    if request.trainingType == .ausdauer {
                        Picker("Intensität", selection: $request.ausdauerIntensity) {
                            ForEach(AiPlanRequest.AusdauerIntensity.allCases) { Text($0.title).tag($0) }
                        }
                        .listRowBackground(AppColor.surface)
                    }
                }

                Picker("Dauer", selection: $request.duration) {
                    Text("frei").tag(Int?.none)
                    ForEach([30, 45, 60], id: \.self) { Text("\($0) Min").tag(Int?.some($0)) }
                }
                .listRowBackground(AppColor.surface)
            }

            if request.modality != .reformer {
            Section("Geräte (leer = KI wählt)") {
                // Fünf Kacheln passen nicht nebeneinander in eine Form-Zeile —
                // scrollen statt Wörter umbrechen.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(AiPlanRequest.Equipment.allCases) { item in
                            FilterChip(title: item.title, isActive: request.equipment.contains(item)) {
                                if request.equipment.contains(item) { request.equipment.remove(item) }
                                else { request.equipment.insert(item) }
                            }
                            .fixedSize()
                        }
                    }
                    .padding(.vertical, 2)
                }
                .listRowBackground(AppColor.surface)
            }
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Der Plan wird aus Leistungstest, Anamnese, Messwerten und Zielen von \(client.name) erstellt und als Entwurf gespeichert. Kontraindizierte Übungen werden vor der Auswahl entfernt.")
                        .font(.app(12))
                        .foregroundStyle(AppColor.muted)
                    if let error {
                        Text(error).font(.app(13)).foregroundStyle(AppColor.red)
                    }
                }
                .listRowBackground(AppColor.surface)
            }

            Section {
                Button(action: { Task { await generate() } }) {
                    HStack {
                        if isGenerating {
                            ProgressView().tint(AppColor.white)
                            Text("Plan wird erstellt … das dauert bis zu einer Minute")
                                .font(.app(14))
                        } else {
                            Label("Plan generieren", systemImage: "sparkles")
                                .font(.app(15, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .disabled(isGenerating)
                .foregroundStyle(AppColor.white)
                .listRowBackground(isGenerating ? AppColor.surface2 : AppColor.cta)
            }
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: - Ergebnis

    private func result(_ outcome: AiPlanOutcome) -> some View {
        ScrollView {
            VStack(spacing: AppSpacing.stack) {
                Card {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(outcome.plan.name ?? "KI-Trainingsplan")
                            .font(.app(17, weight: .bold))
                            .foregroundStyle(AppColor.text)
                        Text("\(outcome.plan.values.totalRows) Übungen · als Entwurf gespeichert")
                            .font(.app(13))
                            .foregroundStyle(AppColor.muted)
                        if outcome.isRuleBased {
                            Label("KI nicht erreichbar — regelbasiert erstellt", systemImage: "exclamationmark.triangle")
                                .font(.app(12))
                                .foregroundStyle(AppColor.orange)
                        }
                    }
                }

                if !outcome.reasoning.isEmpty {
                    infoCard("Begründung", outcome.reasoning)
                }
                if !outcome.weaknesses.isEmpty {
                    infoCard("Adressierte Schwächen", outcome.weaknesses.joined(separator: " · "))
                }
                if !outcome.contraindications.isEmpty {
                    infoCard("Berücksichtigte Befunde", outcome.contraindications.joined(separator: " · "))
                }
                if !outcome.excluded.isEmpty {
                    infoCard("Vorab ausgeschlossen (\(outcome.excluded.count))",
                             outcome.excluded.map { "\($0.name) — \($0.reason)" }.joined(separator: "\n"))
                }

                Button {
                    onGenerated(outcome.plan)
                    dismiss()
                } label: {
                    Text("Plan öffnen")
                        .font(.app(15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(AppColor.cta)
                        .foregroundStyle(AppColor.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
                }
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.vertical, AppSpacing.stack)
        }
    }

    private func infoCard(_ title: String, _ text: String) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.app(13, weight: .semibold))
                    .foregroundStyle(AppColor.muted)
                Text(text)
                    .font(.app(14))
                    .foregroundStyle(AppColor.text)
            }
        }
    }

    private func generate() async {
        isGenerating = true
        error = nil
        defer { isGenerating = false }
        #if DEBUG
        if isPreview {
            try? await Task.sleep(for: .seconds(1))
            outcome = PreviewData.aiOutcome(for: client, request: request)
            return
        }
        #endif
        do {
            outcome = try await AiPlanService().generate(clientId: client.id, request: request)
        } catch let apiError as APIError {
            error = apiError.message
        } catch {
            self.error = "Der Plan konnte nicht erstellt werden."
        }
    }
}
