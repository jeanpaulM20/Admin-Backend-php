import SwiftUI

/// Sternebewertungen der Kunden. Pendant zu `screens/feedback_screen.dart`.
struct FeedbackView: View {
    let isPreview: Bool

    @State private var items: [FeedbackItem] = []
    @State private var showUnreadOnly = true
    @State private var isLoading = true
    @State private var error: String?

    private var visible: [FeedbackItem] {
        showUnreadOnly ? items.filter { !$0.isRead } : items
    }

    var body: some View {
        VStack(spacing: 10) {
            Picker("Ansicht", selection: $showUnreadOnly) {
                Text("Ungelesen").tag(true)
                Text("Alle").tag(false)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, AppSpacing.screen)

            content
        }
        .padding(.top, 8)
        .background(AppColor.background)
        .navigationTitle("Bewertungen")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder private var content: some View {
        if isLoading {
            LoadingState()
        } else if let error {
            MessageState(icon: "exclamationmark.triangle", title: "Bewertungen nicht geladen", message: error)
        } else if visible.isEmpty {
            MessageState(icon: "star",
                         title: showUnreadOnly ? "Nichts Ungelesenes" : "Keine Bewertungen",
                         message: showUnreadOnly
                            ? "Alle Bewertungen sind gelesen."
                            : "Sobald Kunden ein Training bewerten, erscheint es hier.")
        } else {
            List(visible) { item in
                row(item)
                    .listRowBackground(AppColor.background)
                    .listRowSeparatorTint(AppColor.border)
                    .contentShape(Rectangle())
                    .onTapGesture { Task { await markRead(item) } }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .refreshable { await load() }
        }
    }

    private func row(_ item: FeedbackItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Avatar(initials: item.clientName.initials, size: 36)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.clientName)
                        .font(.app(15, weight: .semibold))
                        .foregroundStyle(AppColor.text)
                    if !item.isRead {
                        Circle().fill(AppColor.primary).frame(width: 7, height: 7)
                    }
                }
                StarRating(rating: item.rating)
                if !item.comment.isEmpty {
                    Text(item.comment)
                        .font(.app(13))
                        .foregroundStyle(AppColor.muted)
                }
                if let date = item.date {
                    Text(date)
                        .font(.app(11))
                        .foregroundStyle(AppColor.muted)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    /// Antippen markiert als gelesen — wie in der Flutter-App, dort über
    /// POST feedback/:id/read.
    private func markRead(_ item: FeedbackItem) async {
        guard !item.isRead, let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isRead = true
        #if DEBUG
        if isPreview { return }
        #endif
        do {
            try await FeedbackRatingService().markRead(id: item.id)
        } catch {
            items[index].isRead = false
        }
    }

    private func load() async {
        defer { isLoading = false }
        #if DEBUG
        if isPreview {
            items = PreviewData.ratings
            return
        }
        #endif
        do {
            items = try await FeedbackRatingService().ratings()
        } catch let apiError as APIError {
            error = apiError.message
        } catch {
            self.error = "Bewertungen konnten nicht geladen werden"
        }
    }
}

/// Fünf Sterne, gefüllt bis zur Bewertung.
struct StarRating: View {
    let rating: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .font(.app(11))
                    .foregroundStyle(index <= rating ? AppColor.brass : AppColor.muted)
            }
        }
    }
}
