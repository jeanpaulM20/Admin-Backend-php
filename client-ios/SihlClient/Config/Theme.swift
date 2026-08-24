import SwiftUI

/// App-Farben — Marken-Palette von sihltraining.ch
/// (Pythia-Analyse 2026-08: grünstichige Dunkelflächen, warmes Off-White,
/// Salbeigrau, Marken-Olive; Erdton-Orange EXKLUSIV für den einen
/// Haupt-CTA pro Screen, Messing für Belege/Wertigkeit).
enum AppColor {
    // Brand olive (≈ Website #606C38)
    static let primary      = Color(hex: 0x636B2F)
    static let primaryLight = Color(hex: 0x7A8438)
    static let primaryDark  = Color(hex: 0x4D5324)

    // Dark surfaces — grünstichiges Nahschwarz (vorher Blaustich)
    static let background   = Color(hex: 0x12140F)
    static let surface      = Color(hex: 0x1B2016)
    static let surface2     = Color(hex: 0x252C1E)

    // Text — warmes Off-White + Salbeigrau
    static let text         = Color(hex: 0xF5F3EE)
    static let muted        = Color(hex: 0x9AA38C)

    // Border
    static let border       = Color(hex: 0x363E2A)

    // Erdton-Orange — NUR für die eine dominante Aktion pro Screen
    static let cta          = Color(hex: 0xC8532B)
    // Mattes Messing — Belege/Wertigkeit (Abo-Badge, Zertifikate, Messwerte)
    static let brass        = Color(hex: 0xB89A56)

    // Semantic
    static let green        = Color(hex: 0x34D399)
    static let red          = Color(hex: 0xF87171)
    static let orange       = Color(hex: 0xFFAA33)
    static let blue         = Color(hex: 0x60A5FA)

    // Neutral
    static let white        = Color.white
    static let black        = Color.black

    // Herzfrequenz-Zonen (Training-Reviews, Chat-Datenkarten)
    static let zoneMax       = Color(hex: 0xC2234D)
    static let zoneIntense   = Color(hex: 0xD18B37)
    static let zoneModerate  = Color(hex: 0x839C4D)
    static let zoneLight     = Color(hex: 0x03A4B6)
    static let zoneVeryLight = Color(hex: 0x9E9E9E)
}

/// Abstands-Raster (4er-Grid) — Designsystem-Tokens statt Literale in den Views.
enum AppSpacing {
    /// Horizontales Screen-Randpadding aller Haupt-Screens
    static let screen: CGFloat = 20
    /// Standard-Innenpadding von Cards
    static let card: CGFloat = 16
    /// Innenpadding von Hero-/Summary-Cards
    static let hero: CGFloat = 20
    /// Vertikaler Abstand zwischen Cards/Sektionen einer Liste
    static let stack: CGFloat = 12
    /// Abstand am Listenende (vor der TabBar)
    static let bottomInset: CGFloat = 24
    /// Bottom-Offset für Toasts
    static let toastBottom: CGFloat = 32
}

/// Eckenradien — zwei Arbeitsstufen plus Hero.
enum AppRadius {
    /// Cards & Container
    static let card: CGFloat = 14
    /// Buttons, Chips, Banner, kleine Controls
    static let control: CGFloat = 10
    /// Hero-Cards & Sheet-Flächen
    static let hero: CGFloat = 20
}

extension Color {
    /// Erzeugt eine Farbe aus einem 0xRRGGBB Integer (wie Flutter `Color(0xFF......)`).
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}
