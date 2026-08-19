import Foundation

/// Pendant zu `services/daily_quote_service.dart`.
/// Zwei-Ebenen-Cache:
///   1. In-memory (pro App-Session, überlebt Tab-Wechsel)
///   2. UserDefaults (pro Kalendertag, überlebt Neustarts)
actor DailyQuoteService {
    static let shared = DailyQuoteService()

    private var memQuote: DailyQuote?
    private var memDate: String?

    // MARK: - Public

    func fetch() async throws -> DailyQuote? {
        let today = todayString()

        // 1. In-memory
        if let q = memQuote, memDate == today { return q }

        // 2. UserDefaults
        let defaults = UserDefaults.standard
        if defaults.string(forKey: "dq_date") == today,
           let text   = defaults.string(forKey: "dq_text"),
           let author = defaults.string(forKey: "dq_author"),
           !text.isEmpty {
            let q = DailyQuote(text: text, author: author)
            store(q, date: today)
            return q
        }

        // 3. API
        let data = try await APIClient.shared.get("api/daily-quote")
        guard
            let q = try? JSONDecoder().decode(DailyQuote.self, from: data),
            !q.text.isEmpty
        else { return nil }

        store(q, date: today)
        defaults.set(today,    forKey: "dq_date")
        defaults.set(q.text,   forKey: "dq_text")
        defaults.set(q.author, forKey: "dq_author")
        return q
    }

    // MARK: - Private

    private func store(_ quote: DailyQuote, date: String) {
        memQuote = quote
        memDate  = date
    }

    private func todayString() -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
}
