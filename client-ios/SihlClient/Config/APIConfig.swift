import Foundation

/// API-Konfiguration — zeigt auf das Railway NestJS Backend.
/// Pendant zu Flutter `api_config.dart`.
enum APIConfig {
    /// Railway NestJS backend
    static let baseURL = URL(string: "https://admin-backend-php-production.up.railway.app/")!

    /// Auth-Header-Name (token-basierte Auth)
    static let authHeader = "X-Auth-Token"

    /// Request-Timeout
    static let timeout: TimeInterval = 15
}
