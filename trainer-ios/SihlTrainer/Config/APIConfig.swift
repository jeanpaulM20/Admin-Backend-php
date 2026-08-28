import Foundation

/// API-Konfiguration — zeigt auf dasselbe Railway-NestJS-Backend wie die
/// Flutter-Trainer-App und die Client-App.
/// Pendant zu `trainer-flutter/lib/config/api_config.dart`.
enum APIConfig {
    static let baseURL = URL(string: "https://admin-backend-php-production.up.railway.app/api/")!

    /// Auth-Header-Name (token-basierte Auth)
    static let authHeader = "X-Auth-Token"

    /// Request-Timeout
    static let timeout: TimeInterval = 30

    /// Salt des Legacy-PHP-Auth-Schemas: Token = md5(salt + passcode).
    /// Steht so auch im Flutter-Client — in der Web-App liegt er im
    /// ausgelieferten JS-Bundle offen. Die Sicherheit hängt allein an der
    /// Passcode-Entropie; das Schema wandert mit, damit die App gegen das
    /// bestehende Backend funktioniert.
    static let salt = #"sKLUIE7dfwo4hn23l;idfj[028325p*^&)(op"#

    // MARK: - Endpunkte (Reihenfolge wie in api_config.dart)

    static let trainerMe          = "trainer/me"
    static let aboutUs            = "trainer/aboutus"
    static let locationList       = "location"
    static let client             = "client"
    static let availability       = "trainer-availability"
    static let availabilitySerial = "trainer-availability/serial"
    static let training           = "training"
    static let feedback           = "feedback"
    static let trainingPlan       = "training-plan"
    static let exercise           = "exercise"
    static let exerciseGroups     = "exercise/groups"
    static let metric             = "metric"
    static let performance        = "performance_test"
    static let anamnese           = "anamnese"
    static let review             = "review"
    static let file               = "file"
    static let sendFile           = "file/send"
    static let trainerQR          = "trainer/qr"
    static let preference         = "preference"
    static let changePassword     = "trainer/password"
}
