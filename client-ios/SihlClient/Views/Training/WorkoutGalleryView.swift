import SwiftUI

// MARK: - WorkoutGalleryView (Trainings-Galerie, F1)

/// Kartenmass der Galerie: 9:16 wie ein Reel, so gross wie die Fläche
/// unter dem Startknopf es hergibt.
private enum GalleryCardSize {
    static let width: CGFloat = 200
    static let height: CGFloat = 356
}

/// Fotokarten der absolvierten Einheiten im Reel-Format (9:16),
/// gefiltert nach der oben gewählten Aktivität. Ein Tipp öffnet die
/// Details samt „Nochmal starten".
struct WorkoutGalleryView: View {
    @Environment(AuthViewModel.self) private var auth
    let activity: WorkoutActivity
    /// Startet dieselbe Einheit erneut (Aktivität übernehmen).
    let onRepeat: (WorkoutPhoto) -> Void

    @State private var photos: [WorkoutPhoto] = []
    @State private var isLoading = false
    @State private var detail: WorkoutPhoto?

    private var isDemo: Bool { auth.clientId == "demo" }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Deine \(activity.rawValue)-Einheiten")
                    .font(.subheadline.bold())
                    .foregroundStyle(AppColor.text)
                Spacer()
                if !photos.isEmpty {
                    Text("\(photos.count)")
                        .font(.footnote)
                        .foregroundStyle(AppColor.muted)
                }
            }

            if isLoading {
                ProgressView().tint(AppColor.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else if photos.isEmpty {
                // Platzhalter im selben Format: zeigt, wie die Galerie
                // aussehen wird, statt einer leeren Fläche
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.stack) {
                        PlaceholderCard(activity: activity, showsHint: true)
                        PlaceholderCard(activity: activity, showsHint: false)
                            .opacity(0.6)
                        PlaceholderCard(activity: activity, showsHint: false)
                            .opacity(0.3)
                    }
                    .padding(.horizontal, AppSpacing.screen)
                }
                .padding(.horizontal, -AppSpacing.screen)
                .allowsHitTesting(false)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.stack) {
                        ForEach(photos) { photo in
                            GalleryCard(photo: photo)
                                .onTapGesture { detail = photo }
                        }
                    }
                    .padding(.horizontal, AppSpacing.screen)
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .padding(.horizontal, -AppSpacing.screen)
            }
        }
        .task(id: activity) { await load() }
        .sheet(item: $detail) { photo in
            WorkoutPhotoDetailView(photo: photo) {
                detail = nil
                onRepeat(photo)
            } onDeleted: {
                detail = nil
                photos.removeAll { $0.id == photo.id }
            }
        }
    }

    private func load() async {
        guard !isDemo, let clientId = auth.clientId else { photos = []; return }
        isLoading = photos.isEmpty
        photos = (try? await WorkoutPhotoService.shared.list(
            clientId: clientId, activity: activity)) ?? []
        isLoading = false
    }
}

// MARK: - Platzhalter, solange keine Fotos da sind

private struct PlaceholderCard: View {
    let activity: WorkoutActivity
    let showsHint: Bool

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: showsHint ? "camera" : activity.icon)
                .font(.app(34))
                .foregroundStyle(AppColor.muted.opacity(0.55))
            if showsHint {
                Text("Nach dem Training\nein Foto aufnehmen")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppColor.muted)
                    .padding(.horizontal, 10)
            }
        }
        .frame(width: GalleryCardSize.width, height: GalleryCardSize.height)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .strokeBorder(AppColor.border,
                              style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        )
    }
}

// MARK: - Karte im Reel-Format

private struct GalleryCard: View {
    @Environment(AuthViewModel.self) private var auth
    let photo: WorkoutPhoto
    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                AppColor.surface2
            }
            LinearGradient(colors: [AppColor.black.opacity(0.75), .clear],
                           startPoint: .bottom, endPoint: .center)
            VStack(alignment: .leading, spacing: 2) {
                Label(photo.distanceText ?? photo.durationText ?? "",
                      systemImage: photo.workoutActivity.icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.white)
                if let date = photo.date {
                    Text(date, format: .dateTime.day().month(.abbreviated))
                        .font(.caption)
                        .foregroundStyle(AppColor.white.opacity(0.75))
                }
            }
            .padding(10)
        }
        .frame(width: GalleryCardSize.width, height: GalleryCardSize.height)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .contentShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .task {
            guard image == nil, let clientId = auth.clientId else { return }
            image = await WorkoutPhotoService.shared.image(clientId: clientId, photoId: photo.id)
        }
    }
}

// MARK: - Detailansicht

private struct WorkoutPhotoDetailView: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.dismiss) private var dismiss
    let photo: WorkoutPhoto
    let onRepeat: () -> Void
    let onDeleted: () -> Void

    @State private var image: UIImage?
    @State private var confirmDelete = false

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.stack) {
                    ZStack(alignment: .bottomLeading) {
                        Group {
                            if let image {
                                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                            } else {
                                AppColor.surface2
                            }
                        }
                        .frame(height: 320)
                        .clipped()
                        LinearGradient(colors: [AppColor.black.opacity(0.8), .clear],
                                       startPoint: .bottom, endPoint: .center)
                            .frame(height: 320)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(photo.activity)
                                .font(.headline)
                                .foregroundStyle(AppColor.white)
                            if let date = photo.date {
                                Text(date, format: .dateTime.weekday(.wide).day().month(.wide).year())
                                    .font(.caption)
                                    .foregroundStyle(AppColor.white.opacity(0.8))
                            }
                        }
                        .padding(AppSpacing.card)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))

                    HStack(spacing: AppSpacing.stack) {
                        if let d = photo.distanceText { stat(d, "Distanz") }
                        if let t = photo.durationText { stat(t, "Dauer") }
                        if let hr = photo.avgHr { stat("\(hr)", "Ø bpm", color: AppColor.red) }
                        if let gain = photo.elevationGain, gain > 0 { stat("\(gain) m", "Höhe") }
                    }

                    Button {
                        onRepeat()
                    } label: {
                        Label("Nochmal starten", systemImage: "record.circle")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 4)

                    Button("Foto löschen") { confirmDelete = true }
                        .font(.footnote)
                        .foregroundStyle(AppColor.muted)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, AppSpacing.screen)
                .padding(.vertical, AppSpacing.card)
            }
        }
        .task {
            guard let clientId = auth.clientId else { return }
            image = await WorkoutPhotoService.shared.image(clientId: clientId, photoId: photo.id)
        }
        .alert("Foto löschen?", isPresented: $confirmDelete) {
            Button("Abbrechen", role: .cancel) {}
            Button("Löschen", role: .destructive) {
                Task {
                    if let clientId = auth.clientId {
                        try? await WorkoutPhotoService.shared.delete(clientId: clientId, photoId: photo.id)
                    }
                    onDeleted()
                }
            }
        } message: {
            Text("Die Trainingsaufzeichnung selbst bleibt erhalten.")
        }
    }

    private func stat(_ value: String, _ label: String, color: Color = AppColor.text) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.app(17, weight: .bold).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.caption2).foregroundStyle(AppColor.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.stack)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.card))
    }
}
