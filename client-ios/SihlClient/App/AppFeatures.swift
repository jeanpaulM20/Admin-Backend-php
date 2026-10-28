import Foundation

/// Zentrale Funktionsschalter je Release.
enum AppFeatures {
    /// Blutzucker (FreeStyle Libre) — für Version 1.0 ausgeblendet. Der Code
    /// bleibt erhalten; solange aus, lädt Libre nichts und vorhandene
    /// Libre-Daten auf dem Gerät werden beim Start gelöscht.
    static let glucose = false
}
