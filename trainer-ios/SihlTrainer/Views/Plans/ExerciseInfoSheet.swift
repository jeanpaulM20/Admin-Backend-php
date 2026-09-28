import SwiftUI

/// Anleitung und Trainer-Cues einer Katalogübung — die deutschen Texte aus
/// dem RepDB-Import bzw. der eigenen Erfassung.
struct ExerciseInfoSheet: View {
    let exercise: Exercise
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.stack) {
                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(exercise.name)
                                .font(.app(18, weight: .bold))
                                .foregroundStyle(AppColor.text)
                            HStack(spacing: 8) {
                                if let level = exercise.levelTitle { tag(level) }
                                if let equipment = exercise.equipmentTitle { tag(equipment) }
                                if let muscle = exercise.primaryMuscleGroup { tag(muscle) }
                            }
                        }
                    }
                    if let steps = exercise.instructionsDe, !steps.isEmpty {
                        section("Ausführung", steps.split(separator: "\n").map(String.init))
                    }
                    if let cues = exercise.cuesDe, !cues.isEmpty {
                        section("Cues", cues.split(separator: "\n").map(String.init))
                    }
                }
                .padding(.horizontal, AppSpacing.screen)
                .padding(.vertical, AppSpacing.stack)
            }
            .background(AppColor.background)
            .navigationTitle("Übung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }.foregroundStyle(AppColor.primary)
                }
            }
        }
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.app(11, weight: .semibold))
            .foregroundStyle(AppColor.brass)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(AppColor.brass.opacity(0.14))
            .clipShape(Capsule())
    }

    private func section(_ title: String, _ lines: [String]) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.app(13, weight: .semibold))
                    .foregroundStyle(AppColor.muted)
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .font(.app(13, weight: .semibold))
                            .foregroundStyle(AppColor.primary)
                            .frame(width: 20, alignment: .trailing)
                        Text(line.trimmingCharacters(in: .whitespaces))
                            .font(.app(14))
                            .foregroundStyle(AppColor.text)
                    }
                }
            }
        }
    }
}
