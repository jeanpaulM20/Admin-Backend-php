import SwiftUI

/// Aufzeichnungen eines Kunden — der Review-Teil aus
/// `workout_feedback_screen.dart`.
struct ClientReviewsView: View {
    let client: Client

    @StateObject private var model: ClientReviewsViewModel
    private let isPreview: Bool

    init(client: Client, isPreview: Bool) {
        self.client = client
        self.isPreview = isPreview
        _model = StateObject(wrappedValue: ClientReviewsViewModel(
            clientId: client.id, isPreview: isPreview
        ))
    }

    var body: some View {
        Group {
            if model.isLoading && model.reviews.isEmpty {
                LoadingState()
            } else if let error = model.error {
                MessageState(icon: "exclamationmark.triangle",
                             title: "Aufzeichnungen nicht geladen",
                             message: error)
            } else if model.reviews.isEmpty {
                MessageState(icon: "waveform.path.ecg",
                             title: "Keine Aufzeichnungen",
                             message: "Sobald \(client.name) ein Training aufzeichnet, erscheint es hier.")
            } else {
                List(model.reviews) { review in
                    NavigationLink {
                        ReviewDetailView(review: review,
                                         hrMax: client.maxHeartRate ?? 190,
                                         isPreview: isPreview)
                    } label: {
                        ReviewRow(review: review)
                    }
                    .listRowBackground(AppColor.background)
                    .listRowSeparatorTint(AppColor.border)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable { await model.load() }
            }
        }
        .background(AppColor.background)
        .navigationTitle("Aufzeichnungen")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }
}

private struct ReviewRow: View {
    let review: Review

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.path.ecg")
                .font(.app(15))
                .foregroundStyle(AppColor.primary)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.app(15, weight: .semibold))
                    .foregroundStyle(AppColor.text)
                if let subtitle {
                    Text(subtitle)
                        .font(.app(13))
                        .foregroundStyle(AppColor.muted)
                }
            }
            Spacer(minLength: 0)
            if let hr = review.heartRate, hr > 0 {
                Text("\(Int(hr)) bpm")
                    .font(.app(13, weight: .semibold))
                    .foregroundStyle(AppColor.brass)
            }
        }
        .padding(.vertical, 3)
    }

    private var title: String {
        review.trainingType ?? "Aufzeichnung"
    }

    private var subtitle: String? {
        var parts: [String] = []
        if let date = review.date { parts.append(ReviewFormatters.date.string(from: date)) }
        if let duration = review.duration, !duration.isEmpty { parts.append(duration) }
        if let distance = review.distance, distance > 0 {
            parts.append(String(format: "%.1f km", distance / 1000))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

enum ReviewFormatters {
    static let date: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_CH")
        f.dateFormat = "EE d. MMM yyyy"
        return f
    }()

    static let time: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_CH")
        f.dateFormat = "HH:mm"
        return f
    }()
}
