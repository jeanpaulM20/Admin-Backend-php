import Foundation

// MARK: - TourFormat

/// Geteilte Präsentations-Formatierung für Touren (Dauer, Distanz) —
/// genutzt von Discovery, Detail und Assistent. Eigener Helfer statt
/// Querabhängigkeit zwischen Views (Clean-Architecture-Check 2026-08-25).
enum TourFormat {
    static func duration(_ minutes: Int) -> String {
        minutes >= 60 ? "\(minutes / 60) Std \(minutes % 60) Min" : "\(minutes) Min"
    }

    /// Kurze Bahnen metergenau, Routen in Kilometern.
    static func distance(_ km: Double) -> String {
        km < 1 ? "\(Int((km * 1000).rounded())) m" : String(format: "%.1f km", km)
    }
}
