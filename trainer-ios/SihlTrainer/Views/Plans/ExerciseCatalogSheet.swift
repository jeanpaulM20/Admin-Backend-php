import SwiftUI

/// Pendant zu `screens/exercise_catalog_sheet.dart`: Übung suchen, nach
/// Gruppe und Körperregion filtern, auswählen. Die Auswahl füllt Übung und
/// Gerät der Planzeile.
/// Noch nicht portiert: neue Übung anlegen, KI-Prüfung und Icon-Upload.
struct ExerciseCatalogSheet: View {
    let onSelect: (ExerciseSelection) -> Void

    @StateObject private var model: ExerciseCatalogViewModel
    @Environment(\.dismiss) private var dismiss

    init(isPreview: Bool, onSelect: @escaping (ExerciseSelection) -> Void) {
        self.onSelect = onSelect
        _model = StateObject(wrappedValue: ExerciseCatalogViewModel(isPreview: isPreview))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                SearchField(placeholder: "Übung suchen…", text: $model.query)
                    .padding(.horizontal, AppSpacing.screen)
                filterBar
                content
            }
            .padding(.top, 8)
            .background(AppColor.background)
            .navigationTitle("Übungskatalog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(AppColor.muted)
                }
            }
            .task { await model.load() }
        }
    }

    /// Kacheln wie in der Client-App: Körperregionen zuerst, dann Gruppen.
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.bodyRegions, id: \.self) { region in
                    FilterChip(title: region,
                               isActive: model.selectedBodyRegion == region) {
                        model.selectedBodyRegion = model.selectedBodyRegion == region ? nil : region
                    }
                }
                ForEach(model.groups) { group in
                    FilterChip(title: group.name,
                               isActive: model.selectedGroupId == group.id) {
                        model.selectedGroupId = model.selectedGroupId == group.id ? nil : group.id
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screen)
        }
    }

    @ViewBuilder private var content: some View {
        if model.isLoading && model.exercises.isEmpty {
            LoadingState()
        } else if let error = model.error {
            MessageState(icon: "exclamationmark.triangle",
                         title: "Katalog nicht verfügbar",
                         message: error)
        } else if model.filtered.isEmpty {
            MessageState(icon: "magnifyingglass",
                         title: "Kein Treffer",
                         message: "Für diese Suche gibt es keine Übung.")
        } else {
            List(model.filtered) { exercise in
                Button {
                    onSelect(ExerciseSelection(name: exercise.name,
                                               device: exercise.group?.name ?? ""))
                    dismiss()
                } label: {
                    ExerciseRow(exercise: exercise)
                }
                .listRowBackground(AppColor.background)
                .listRowSeparatorTint(AppColor.border)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}

private struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 12) {
            // Das Backend liefert nicht für jede Übung ein Symbol — ohne Bild
            // steht ein Platzhalter, damit die Zeilenhöhe gleich bleibt.
            AsyncImage(url: exercise.iconURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.app(16))
                        .foregroundStyle(AppColor.muted)
                }
            }
            .frame(width: 34, height: 34)
            .background(AppColor.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.app(15, weight: .semibold))
                    .foregroundStyle(AppColor.text)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.app(12))
                        .foregroundStyle(AppColor.muted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
    }

    private var subtitle: String? {
        let parts = [exercise.group?.name, exercise.subgroupName ?? exercise.primaryMuscleGroup]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// Filterkachel — dieselbe Form wie die Chips in der Client-App.
struct FilterChip: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.app(13, weight: .semibold))
                .foregroundStyle(isActive ? AppColor.white : AppColor.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isActive ? AppColor.primary : AppColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.control)
                        .stroke(isActive ? .clear : AppColor.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
