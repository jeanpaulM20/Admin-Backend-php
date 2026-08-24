import SwiftUI

// MARK: - AnalyticsView (Hauptliste)

/// Pendant zu `PerformanceScreen` in Flutter `performance_screen.dart`.
/// Zeigt Performance-Sektionen (klappbar) + Trainingsaufzeichnungen.
struct AnalyticsView: View {
    @Environment(AuthViewModel.self)    private var auth
    @Environment(AnalyticsViewModel.self) private var analytics

    // Zustand für Trainingsvergleich
    @State private var compareMode     = false
    @State private var selectedReviews = Set<String>()   // IDs
    @State private var compareTarget:  CompareSelection? = nil

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()

            if analytics.isLoading && analytics.sections.isEmpty {
                ProgressView("Lade Leistungsdaten…").tint(AppColor.primary)
            } else if let e = analytics.error {
                ErrorStateView(message: e) {
                    Task { await analytics.fetch(clientId: auth.clientId ?? "") }
                }
            } else if analytics.sections.isEmpty && analytics.reviews.isEmpty {
                EmptyStateView(
                    icon:    "chart.line.uptrend.xyaxis",
                    message: "Noch keine Leistungstests erfasst."
                )
            } else {
                contentList
            }
        }
        .task {
            if analytics.sections.isEmpty && analytics.reviews.isEmpty {
                await analytics.fetch(clientId: auth.clientId ?? "")
            }
        }
        .refreshable {
            await analytics.fetch(clientId: auth.clientId ?? "")
        }
        .sheet(item: $compareTarget) { sel in
            TrainingCompareView(reviews: sel.reviews)
        }
        // NavigationDestinations werden im NavigationStack von MainTabView registriert
        .navigationDestination(for: PerformanceNavTarget.self) { target in
            PerformanceDetailView(item: target.item, sectionTitle: target.sectionTitle)
        }
        .navigationDestination(for: TrainingReview.self) { review in
            TrainingReviewDetailView(review: review)
        }
    }

    // MARK: - Content list

    private var contentList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Performance-Sektionen
                ForEach(analytics.sections) { section in
                    PerformanceSectionCard(section: section)
                }

                // Trainingsaufzeichnungen
                if !analytics.reviews.isEmpty {
                    TrainingReviewSectionCard(
                        reviews:          analytics.reviews,
                        compareMode:      $compareMode,
                        selectedIds:      $selectedReviews,
                        onCompare: {
                            let selected = analytics.reviews.filter { selectedReviews.contains($0.id) }
                            compareTarget = selected.isEmpty ? nil : CompareSelection(reviews: selected)
                        }
                    )
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.top, 16)
        }
    }
}

// MARK: - PerformanceSectionCard

/// Pendant zu `PerformanceSectionTile` — aufklappbare Karte mit Metrikwerten.
private struct PerformanceSectionCard: View {
    let section: PerformanceSection
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Header (Tap zum Auf-/Zuklappen)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppRadius.control)
                            .fill(AppColor.primary.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(AppColor.primary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.title)
                            .font(.subheadline.bold())
                            .foregroundStyle(AppColor.text)
                        Text("\(section.items.count) Messwert\(section.items.count == 1 ? "" : "e")")
                            .font(.caption)
                            .foregroundStyle(AppColor.muted)
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            // Items
            if expanded {
                Divider().background(AppColor.muted.opacity(0.2))
                ForEach(section.items.indices, id: \.self) { idx in
                    let item = section.items[idx]
                    NavigationLink(value: PerformanceNavTarget(sectionTitle: section.title, item: item)) {
                        PerformanceItemRow(
                            item:   item,
                            isLast: idx == section.items.count - 1
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppColor.muted.opacity(0.15), lineWidth: 1))
    }
}

// MARK: - PerformanceItemRow

/// Eine Zeile in der aufgeklappten Sektion: Name | Aktuell | Vorher | Trend.
struct PerformanceItemRow: View {
    let item:   PerformanceItem
    var isLast: Bool = false

    var body: some View {
        HStack {
            Text(item.name)
                .font(.callout)
                .foregroundStyle(AppColor.muted)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(item.value)
                .font(.callout.bold())
                .foregroundStyle(AppColor.text)
                .frame(width: 70, alignment: .center)

            Text(item.previousValue)
                .font(.callout)
                .foregroundStyle(AppColor.muted)
                .frame(width: 70, alignment: .center)

            HStack(spacing: 2) {
                changeIcon
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(AppColor.muted.opacity(0.5))
            }
            .frame(width: 40, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(AppColor.muted.opacity(0.1)).frame(height: 1)
            }
        }
    }

    @ViewBuilder
    private var changeIcon: some View {
        let c = item.change.lowercased()
        if c == "up" || c == "increase" || c == "+" || (c.hasPrefix("+") && c.count > 1) {
            Image(systemName: "arrow.up").font(.caption).foregroundStyle(.green)
        } else if c == "down" || c == "decrease" || c == "-" || c.hasPrefix("-") {
            Image(systemName: "arrow.down").font(.caption).foregroundStyle(.red)
        } else if !item.change.isEmpty && item.change != "0" {
            Text(item.change).font(.caption.bold()).foregroundStyle(item.changeColor)
        }
    }
}

// MARK: - TrainingReviewSectionCard

/// Pendant zu `TrainingReviewSectionTile` — Trainingsaufzeichnungen mit Vergleichsmodus.
private struct TrainingReviewSectionCard: View {
    let reviews: [TrainingReview]
    @Binding var compareMode: Bool
    @Binding var selectedIds: Set<String>
    let onCompare: () -> Void

    private let minCompare = 2
    @State private var expanded = false

    private var comparableCount: Int { reviews.filter(\.hasChartData).count }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.control)
                        .fill(AppColor.red.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 18))
                        .foregroundStyle(AppColor.red)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Training")
                        .font(.subheadline.bold())
                        .foregroundStyle(AppColor.text)
                    Text("\(reviews.count) Einheit\(reviews.count == 1 ? "" : "en")")
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                }
                Spacer()

                // Vergleichen-Button (nur wenn genug vergleichbare Reviews vorhanden)
                if comparableCount >= minCompare {
                    Button(compareMode ? "Abbrechen" : "Vergleichen") {
                        withAnimation {
                            compareMode.toggle()
                            selectedIds.removeAll()
                        }
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(compareMode ? AppColor.primary : AppColor.surface)
                    .foregroundStyle(compareMode ? AppColor.white : AppColor.text)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.control).stroke(
                        compareMode ? AppColor.primary : AppColor.muted.opacity(0.3), lineWidth: 1))
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                } label: {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption).foregroundStyle(AppColor.muted)
                }
            }
            .padding(16)

            if expanded {
                Divider().background(AppColor.muted.opacity(0.2))

                // Status-Leiste im Vergleichsmodus
                if compareMode {
                    HStack {
                        Image(systemName: selectedIds.count < minCompare
                              ? "info.circle" : "checkmark.circle")
                            .font(.caption).foregroundStyle(AppColor.primary)
                        Text(selectedIds.count < minCompare
                             ? "Wähle mind. \(minCompare) Trainings"
                             : "\(selectedIds.count) ausgewählt")
                            .font(.caption.bold()).foregroundStyle(AppColor.primary)
                        Spacer()
                        if selectedIds.count >= minCompare {
                            Button("Vergleichen", action: onCompare)
                                .font(.caption.bold())
                                .padding(.horizontal, 14).padding(.vertical, 6)
                                .background(AppColor.primary)
                                .foregroundStyle(AppColor.white)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppColor.primary.opacity(0.08))
                }

                // Listeneinträge
                ForEach(reviews.indices, id: \.self) { idx in
                    let review = reviews[idx]
                    let isLast = idx == reviews.count - 1
                    let isDisabled = compareMode && !review.hasChartData
                    let isSelected = selectedIds.contains(review.id)

                    if compareMode {
                        // Vergleichsmodus: Tap toggelt die Auswahl
                        ReviewRowView(
                            review:     review,
                            isLast:     isLast,
                            compareMode: compareMode,
                            isSelected: isSelected,
                            isDisabled: isDisabled
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard !isDisabled else { return }
                            withAnimation {
                                if selectedIds.contains(review.id) {
                                    selectedIds.remove(review.id)
                                } else {
                                    selectedIds.insert(review.id)
                                }
                            }
                        }
                    } else {
                        // Normalmodus: ganze Zeile ist der NavigationLink zum Detail
                        NavigationLink(value: review) {
                            ReviewRowView(
                                review:     review,
                                isLast:     isLast,
                                compareMode: compareMode,
                                isSelected: isSelected,
                                isDisabled: isDisabled
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(
            AppColor.muted.opacity(0.15), lineWidth: 1))
    }
}

// MARK: - ReviewRowView

private struct ReviewRowView: View {
    let review:      TrainingReview
    let isLast:      Bool
    let compareMode: Bool
    let isSelected:  Bool
    let isDisabled:  Bool

    var body: some View {
        HStack(spacing: 12) {
            if compareMode {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? AppColor.primary : AppColor.muted, lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColor.primary)
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.caption.bold()).foregroundStyle(.white)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(review.trainingType)
                    .font(.callout.bold())
                    .foregroundStyle(AppColor.text)
                Text(review.formattedDate())
                    .font(.caption)
                    .foregroundStyle(AppColor.muted)
            }
            Spacer()
            if let max = review.hrMax {
                Text("\(max) bpm")
                    .font(.callout.bold())
                    .foregroundStyle(AppColor.red)
            }
            if !compareMode {
                Image(systemName: "chevron.right")
                    .font(.caption2).foregroundStyle(AppColor.muted.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isSelected ? AppColor.primary.opacity(0.1) : Color.clear)
        .opacity(isDisabled ? 0.4 : 1)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(AppColor.muted.opacity(0.1)).frame(height: 1)
            }
        }
    }
}


// MARK: - CompareSelection (sheet item wrapper)

struct CompareSelection: Identifiable {
    let id      = UUID()
    let reviews: [TrainingReview]
}
