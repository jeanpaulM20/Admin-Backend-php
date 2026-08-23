import SwiftUI

/// App-Farben — 1:1 übernommen aus Flutter `app_colors.dart`.
/// Brand-Olive von sihltraining.ch, dunkles Theme.
enum AppColor {
    // Brand olive
    static let primary      = Color(hex: 0x636B2F)
    static let primaryLight = Color(hex: 0x7A8438)
    static let primaryDark  = Color(hex: 0x4D5324)

    // Dark surfaces — leichter Blaustich für Kohärenz
    static let background   = Color(hex: 0x0D1117)
    static let surface      = Color(hex: 0x161D2E)
    static let surface2     = Color(hex: 0x1E2740)

    // Text
    static let text         = Color(hex: 0xE8EAF0)
    static let muted        = Color(hex: 0x8A9AB8)

    // Border
    static let border       = Color(hex: 0x2A3550)

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

extension Color {
    /// Erzeugt eine Farbe aus einem 0xRRGGBB Integer (wie Flutter `Color(0xFF......)`).
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}
