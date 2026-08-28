import SwiftUI

/// Pendant zu `screens/training_plan_detail_screen.dart`: die vier Abschnitte
/// eines Plans, Freigabe und Bearbeiten der Übungszeilen.
/// Noch nicht portiert: Übungskatalog als Auswahlhilfe, Timer-Vorgaben,
/// Kommentar-Zähler und die Termin-Spalten.
struct TrainingPlanDetailView: View {
    @StateObject private var model: TrainingPlanEditorViewModel
    /// Meldet den gespeicherten Stand an die Liste zurück.
    private let onChange: (TrainingPlan) -> Void

    init(plan: TrainingPlan, isPreview: Bool, onChange: @escaping (TrainingPlan) -> Void) {
        _model = StateObject(wrappedValue: TrainingPlanEditorViewModel(plan: plan, isPreview: isPreview))
        self.onChange = onChange
    }

    var body: some View {
        List {
            headerSection
            ForEach(PlanSection.allCases) { section in
                planSection(section)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColor.background)
        .environment(\.editMode, .constant(model.isEditing ? .active : .inactive))
        .navigationTitle(model.plan.name?.isEmpty == false ? model.plan.name! : "Trainingsplan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .alert("Fehler", isPresented: .constant(model.error != nil)) {
            Button("OK") { model.error = nil }
        } message: {
            Text(model.error ?? "")
        }
        .onChange(of: model.plan.status) { onChange(model.plan) }
    }

    // MARK: - Kopf

    private var headerSection: some View {
        Section {
            if model.isEditing {
                TextField("Plantitel", text: Binding(
                    get: { model.plan.name ?? "" },
                    set: { model.plan.name = $0 }
                ))
                .font(.app(16, weight: .semibold))
                .foregroundStyle(AppColor.text)
                .listRowBackground(AppColor.surface)
            }

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(model.plan.values.totalRows) Übungen")
                        .font(.app(14))
                        .foregroundStyle(AppColor.text)
                    if let created = model.plan.createdAt, let date = JSON.date(created) {
                        Text("Erstellt am \(PlanRowFormatters.date.string(from: date))")
                            .font(.app(12))
                            .foregroundStyle(AppColor.muted)
                    }
                }
                Spacer(minLength: 0)
                // Antippen gibt frei bzw. zieht zurück — wie die Pille im
                // Flutter-Detailscreen.
                Button {
                    Task { await model.togglePublished() }
                } label: {
                    StatusPill(isPublished: model.plan.isPublished)
                }
                .buttonStyle(.plain)
                .disabled(model.plan.id == nil)
            }
            .listRowBackground(AppColor.surface)
        }
    }

    // MARK: - Abschnitte

    @ViewBuilder private func planSection(_ section: PlanSection) -> some View {
        let rows = model.plan.values[section]
        if !rows.isEmpty || model.isEditing {
            Section {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    if model.isEditing {
                        RowEditor(row: Binding(
                            get: { model.plan.values[section][index] },
                            set: { model.plan.values[section][index] = $0 }
                        ))
                    } else {
                        RowDisplay(row: row)
                    }
                }
                .onDelete { offsets in
                    model.removeRows(at: offsets, in: section)
                }
                .listRowBackground(AppColor.surface)

                if model.isEditing {
                    Button {
                        model.addRow(to: section)
                    } label: {
                        Label("Übung hinzufügen", systemImage: "plus.circle")
                            .font(.app(14))
                            .foregroundStyle(AppColor.primary)
                    }
                    .listRowBackground(AppColor.surface)
                }
            } header: {
                Label(section.title, systemImage: section.icon)
                    .font(.app(12, weight: .semibold))
                    .foregroundStyle(AppColor.muted)
            }
        }
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        if model.isEditing {
            ToolbarItem(placement: .topBarLeading) {
                Button("Abbrechen") { model.discard() }
                    .foregroundStyle(AppColor.muted)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await model.save()
                        onChange(model.plan)
                    }
                } label: {
                    if model.isSaving {
                        ProgressView().tint(AppColor.primary)
                    } else {
                        Text("Sichern").font(.app(15, weight: .semibold))
                    }
                }
                .disabled(model.isSaving)
            }
        } else {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Bearbeiten") { model.isEditing = true }
            }
        }
    }
}

/// Zeile im Lesemodus: Übung oben, die Ausführungsangaben darunter.
private struct RowDisplay: View {
    let row: TrainingPlanRow

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(row.exercise.isEmpty ? "Ohne Namen" : row.exercise)
                    .font(.app(15, weight: .semibold))
                    .foregroundStyle(AppColor.text)
                if row.liked {
                    Image(systemName: "hand.thumbsup.fill")
                        .font(.app(11))
                        .foregroundStyle(AppColor.green)
                }
                if row.disliked {
                    Image(systemName: "hand.thumbsdown.fill")
                        .font(.app(11))
                        .foregroundStyle(AppColor.red)
                }
            }
            if let details {
                Text(details)
                    .font(.app(13))
                    .foregroundStyle(AppColor.muted)
            }
            if !row.comment.isEmpty {
                Text(row.comment)
                    .font(.app(12))
                    .foregroundStyle(AppColor.brass)
            }
        }
        .padding(.vertical, 2)
    }

    private var details: String? {
        let parts = [row.sets, row.weight, row.device, row.position].filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// Zeile im Bearbeitungsmodus. Übung breit, die kurzen Angaben paarweise —
/// auf dem iPhone bleibt so alles ohne Querscrollen erreichbar.
private struct RowEditor: View {
    @Binding var row: TrainingPlanRow

    var body: some View {
        VStack(spacing: 6) {
            field("Übung", text: $row.exercise, weight: .semibold)
            HStack(spacing: 8) {
                field("Sätze × Wdh.", text: $row.sets)
                field("Gewicht", text: $row.weight)
            }
            HStack(spacing: 8) {
                field("Gerät", text: $row.device)
                field("Position", text: $row.position)
            }
        }
        .padding(.vertical, 4)
    }

    private func field(_ placeholder: String, text: Binding<String>,
                       weight: Font.Weight = .regular) -> some View {
        TextField(placeholder, text: text)
            .font(.app(14, weight: weight))
            .foregroundStyle(AppColor.text)
            .autocorrectionDisabled()
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(AppColor.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

enum PlanRowFormatters {
    static let date: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_CH")
        f.dateFormat = "d. MMMM yyyy"
        return f
    }()
}
