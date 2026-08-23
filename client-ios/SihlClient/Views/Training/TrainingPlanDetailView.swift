import SwiftUI

// MARK: - Section Metadata

private struct SectionMeta {
    let key:   String
    let label: String
    let color: Color
}

private let planSections: [SectionMeta] = [
    .init(key: "sonsomo",  label: "Aufwärmen",     color: AppColor.primary),
    .init(key: "main",     label: "Haupttraining", color: AppColor.blue),
    .init(key: "core",     label: "Core",           color: AppColor.green),
    .init(key: "mobility", label: "Mobilität",      color: AppColor.orange),
]

// MARK: - Local ViewModel

/// Plan-Detail ViewModel — lokal pro Screen-Instanz (nicht per Environment).
@MainActor @Observable
private final class PlanDetailViewModel {
    var isLoading   = false
    var error: String?
    var plan:  ClientTrainingPlan?
    var likes: [String: String]   = [:]
    var commentCounts: [String: Int] = [:]

    private let planId:  Int
    private let service = TrainingPlanService()

    init(planId: Int) { self.planId = planId }

    func load() async {
        isLoading = plan == nil; error = nil
        do {
            let p = try await service.getPlan(planId)
            likes = p.clientLikes
            await loadCommentCounts()
            plan      = p
            isLoading = false
        } catch let e as APIError {
            error = e.message; isLoading = false
        } catch {
            self.error = "Plan konnte nicht geladen werden"; isLoading = false
        }
    }

    func loadCommentCounts() async {
        guard planId > 0 else { return }
        if let counts = try? await service.getCommentCounts(planId: planId) {
            commentCounts = counts
        }
    }

    func toggleLike(exerciseKey: String, type: String) async {
        // Optimistic
        let prev = likes
        if likes[exerciseKey] == type { likes.removeValue(forKey: exerciseKey) }
        else { likes[exerciseKey] = type }
        do {
            let updated = try await service.toggleLike(
                planId: planId, exerciseKey: exerciseKey, type: type)
            likes = updated
        } catch {
            likes = prev // rollback
        }
    }
}

// MARK: - TrainingPlanDetailView

/// Pendant zu `screens/training_plan_detail_screen.dart`.
struct TrainingPlanDetailView: View {
    let planId:       Int
    let planName:     String?
    let exerciseIdMap: [String: Int]

    @Environment(AuthViewModel.self) private var auth

    @State private var vm: PlanDetailViewModel
    @State private var timer = ExerciseTimer()
    @State private var selectedSection = "sonsomo"
    @State private var expanded = Set<String>()
    @State private var commentsTarget: CommentsSheetItem?
    @State private var sse = SSEClient()

    init(planId: Int, planName: String?, exerciseIdMap: [String: Int]) {
        self.planId        = planId
        self.planName      = planName
        self.exerciseIdMap = exerciseIdMap
        _vm = State(initialValue: PlanDetailViewModel(planId: planId))
    }

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            Group {
                if vm.isLoading && vm.plan == nil {
                    LoadingView(message: "Lade Plan…")
                } else if let err = vm.error, vm.plan == nil {
                    ErrorStateView(message: err) { Task { await vm.load() } }
                } else if let plan = vm.plan {
                    if plan.locked || plan.values == nil {
                        lockedView(plan: plan)
                    } else {
                        planContent(plan: plan)
                    }
                }
            }
        }
        .navigationTitle(planName ?? "Trainingsplan")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await vm.load()
            await subscribeRealtime()
        }
        .onDisappear {
            Task { await sse.disconnect() }
        }
        .sheet(item: $commentsTarget) { item in
            CommentsSheet(
                planId:       item.planId,
                exerciseKey:  item.exerciseKey,
                exerciseName: item.exerciseName
            ) {
                Task { await vm.loadCommentCounts() }
            }
        }
    }

    // MARK: - Realtime

    /// Pendant zu Flutter `_subscribeRealtime()` — lädt den Plan bei
    /// `plan_updated` / `plan_comment` Events auf `client_<clientId>` neu.
    private func subscribeRealtime() async {
        guard let clientId = auth.clientId,
              let token = auth.token, !token.isEmpty else { return }
        await sse.connect(channel: "client_\(clientId)", token: token) {
            [self] eventType in
            guard eventType == "plan_updated" || eventType == "plan_comment" else { return }
            Task { @MainActor in
                await self.vm.load()
            }
        }
    }

    // MARK: - Plan Content

    private func planContent(plan: ClientTrainingPlan) -> some View {
        VStack(spacing: 0) {
            sectionTabBar
            timerWidget
            TabView(selection: $selectedSection) {
                ForEach(planSections, id: \.key) { meta in
                    exerciseList(meta: meta, values: plan.values!)
                        .tag(meta.key)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }

    // MARK: - Section Tab Bar

    private var sectionTabBar: some View {
        VStack(spacing: 0) {
            Divider().background(AppColor.border)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(planSections, id: \.key) { meta in
                        let isSelected = meta.key == selectedSection
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedSection = meta.key
                            }
                        } label: {
                            VStack(spacing: 0) {
                                Text(meta.label.uppercased())
                                    .font(.system(size: 12,
                                                  weight: isSelected ? .bold : .regular))
                                    .foregroundStyle(isSelected ? AppColor.text : AppColor.muted)
                                    .padding(.horizontal, 16).padding(.vertical, 10)
                                Rectangle()
                                    .fill(isSelected ? AppColor.primary : Color.clear)
                                    .frame(height: 2.5)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .background(AppColor.background)
        }
    }

    // MARK: - Timer Widget

    private var timerWidget: some View {
        let isFinished = timer.isCountdown && timer.countdownRemaining == 0 && !timer.isRunning
        let timeColor: Color = isFinished ? AppColor.red : timer.isRunning ? AppColor.primary : AppColor.text
        let running = timer.isRunning

        return HStack(spacing: 16) {
            // Play / Pause
            Button { timer.toggle() } label: {
                ZStack {
                    Circle()
                        .fill(running ? AppColor.primary : AppColor.surface2)
                        .frame(width: 44, height: 44)
                    Image(systemName: running ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(running ? AppColor.white : AppColor.primary)
                }
            }
            .buttonStyle(.plain)

            // Zeit
            Spacer()
            Text(timer.display)
                .font(.system(size: 90, weight: .bold, design: .monospaced))
                .foregroundStyle(timeColor)
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .contentTransition(.numericText(countsDown: timer.isCountdown))
                .animation(.linear(duration: 0.5), value: timer.display)
            Spacer()

            // Reset
            Button { timer.reset() } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 18)).foregroundStyle(AppColor.muted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(AppColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(running ? AppColor.primary.opacity(0.7) : AppColor.border, lineWidth: running ? 1.5 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16).padding(.top, 12)
        .animation(.easeInOut(duration: 0.25), value: running)
    }

    // MARK: - Exercise List

    private func exerciseList(meta: SectionMeta, values: TrainingPlanValues) -> some View {
        let rows = values.rows(for: meta.key)
        return Group {
            if rows.isEmpty {
                VStack {
                    Spacer()
                    Text("Keine Übungen in diesem Abschnitt")
                        .font(.system(size: 13)).foregroundStyle(AppColor.muted)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                            ExerciseTile(
                                meta:         meta,
                                index:        i,
                                row:          row,
                                exerciseIdMap: exerciseIdMap,
                                likeType:     vm.likes["\(meta.key)-\(i)"],
                                commentCount: vm.commentCounts["\(meta.key)-\(i)"] ?? 0,
                                isExpanded:   expanded.contains("\(meta.key)-\(i)"),
                                timer:        timer,
                                onToggle: {
                                    let key = "\(meta.key)-\(i)"
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if expanded.contains(key) { expanded.remove(key) }
                                        else { expanded.insert(key) }
                                    }
                                },
                                onLike: { type in
                                    Task { await vm.toggleLike(exerciseKey: "\(meta.key)-\(i)", type: type) }
                                },
                                onComment: {
                                    commentsTarget = CommentsSheetItem(
                                        planId: planId,
                                        exerciseKey: "\(meta.key)-\(i)",
                                        exerciseName: row.exercise.isEmpty ? "Übung \(i+1)" : row.exercise
                                    )
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 80)
                }
            }
        }
    }

    // MARK: - Locked View

    private func lockedView(plan: ClientTrainingPlan) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 44)).foregroundStyle(AppColor.orange)
            Text("Dieser Plan ist gesperrt")
                .font(.system(size: 16, weight: .bold)).foregroundStyle(AppColor.text)
            Text("Schalte Online Coaching frei, um den Plan zu sehen.")
                .font(.system(size: 13)).foregroundStyle(AppColor.muted)
                .multilineTextAlignment(.center)
            NavigationLink(destination: CoachingPaywallView(plan: plan)) {
                Text("Freischalten")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppColor.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AppColor.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Exercise Tile

private struct ExerciseTile: View {
    let meta:          SectionMeta
    let index:         Int
    let row:           TrainingPlanRow
    let exerciseIdMap: [String: Int]
    let likeType:      String?
    let commentCount:  Int
    let isExpanded:    Bool
    let timer:         ExerciseTimer
    let onToggle:  () -> Void
    let onLike:    (String) -> Void
    let onComment: () -> Void

    private var key: String { "\(meta.key)-\(index)" }
    private var isLiked:    Bool { likeType == "like"    }
    private var isDisliked: Bool { likeType == "dislike" }
    private var isTimerActive: Bool {
        timer.isCountdown && timer.activePrefix == meta.key && timer.activeIndex == index
    }
    private var borderColor: Color {
        if isTimerActive { return meta.color }
        if isLiked    { return AppColor.green }
        if isDisliked { return AppColor.red   }
        return AppColor.border
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ────────────────────────────────────────────────────
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    ExerciseBadge(
                        exerciseName:  row.exercise.isEmpty ? nil : row.exercise,
                        exerciseIdMap: exerciseIdMap,
                        color:         meta.color,
                        index:         index,
                        liked:         isLiked,
                        disliked:      isDisliked,
                        size:          72
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.exercise.isEmpty ? "Übung \(index + 1)" : row.exercise)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppColor.text)
                            .multilineTextAlignment(.leading)

                        let parts = [row.device, row.sets, row.weight].filter { !$0.isEmpty }
                        if !parts.isEmpty {
                            Text(parts.joined(separator: " · "))
                                .font(.system(size: 11)).foregroundStyle(AppColor.muted)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    if commentCount > 0 {
                        Button(action: onComment) {
                            HStack(spacing: 2) {
                                Image(systemName: "bubble.left")
                                    .font(.system(size: 11)).foregroundStyle(meta.color.opacity(0.8))
                                Text("\(commentCount)")
                                    .font(.system(size: 11)).foregroundStyle(meta.color)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 4)
                    }

                    Image(systemName: "chevron.down")
                        .font(.system(size: 14)).foregroundStyle(AppColor.muted)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            // ── Expanded ──────────────────────────────────────────────────
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider().background(AppColor.border)

                    // Timer-Chips
                    let timerValues = row.timers.isEmpty ? [30, 60, 90, 120] : row.timers
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(timerValues, id: \.self) { secs in
                                TimerChip(
                                    seconds:    secs,
                                    meta:       meta,
                                    isActive:   isTimerActive && timer.countdownFrom == secs,
                                    onTap: {
                                        timer.selectCountdown(
                                            prefix:  meta.key, index: index,
                                            name:    row.exercise.isEmpty ? "Übung \(index+1)" : row.exercise,
                                            seconds: secs
                                        )
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // Like / Dislike / Kommentar
                    HStack(spacing: 8) {
                        ActionChip(
                            icon:   isLiked ? "heart.fill" : "heart",
                            label:  "Gefällt mir",
                            active: isLiked,
                            color:  AppColor.green,
                            onTap:  { onLike("like") }
                        )
                        ActionChip(
                            icon:   isDisliked ? "hand.thumbsdown.fill" : "hand.thumbsdown",
                            label:  "Passt nicht",
                            active: isDisliked,
                            color:  AppColor.red,
                            onTap:  { onLike("dislike") }
                        )
                        ActionChip(
                            icon:   "bubble.left",
                            label:  commentCount > 0 ? "\(commentCount)" : "Kommentar",
                            active: commentCount > 0,
                            color:  meta.color,
                            onTap:  onComment
                        )
                    }
                    .padding(.horizontal, 16)

                    // Coaching-Notiz (langer Text in position)
                    if row.position.count > 35 {
                        HStack(alignment: .top, spacing: 12) {
                            Rectangle()
                                .fill(AppColor.border).frame(width: 2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Hinweis")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(AppColor.muted)
                                Text(row.position)
                                    .font(.system(size: 12)).foregroundStyle(AppColor.text.opacity(0.75))
                                    .lineSpacing(3)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 4)
                }
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: isExpanded ? 1.5 : 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .animation(.easeInOut(duration: 0.2), value: borderColor.description)
    }
}

// MARK: - Timer Chip

private struct TimerChip: View {
    let seconds:  Int
    let meta:     SectionMeta
    let isActive: Bool
    let onTap:    () -> Void

    private func label() -> String {
        if seconds < 60 { return "\(seconds)s" }
        let m = seconds / 60; let r = seconds % 60
        return r == 0 ? "\(m)min" : "\(m):\(String(format: "%02d", r))"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                if isActive {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11)).foregroundStyle(meta.color)
                }
                Text(label())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isActive ? meta.color : AppColor.muted)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(isActive ? meta.color.opacity(0.18) : AppColor.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isActive ? meta.color : AppColor.border,
                            lineWidth: isActive ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isActive)
    }
}

// MARK: - Action Chip

private struct ActionChip: View {
    let icon:   String
    let label:  String
    let active: Bool
    let color:  Color
    let onTap:  () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12)).foregroundStyle(active ? color : AppColor.muted)
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(active ? color : AppColor.muted)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(active ? color.opacity(0.14) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(active ? color.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: active)
    }
}
