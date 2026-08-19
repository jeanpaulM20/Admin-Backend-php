# SihlClient — Native iOS App (SwiftUI)

Native Swift/SwiftUI-Portierung der Flutter-App in [`client-flutter/`](../client-flutter).
Gleicher Funktionsumfang, gleiches Backend (Railway NestJS), gleiches dunkles Brand-Theme.

## Aktueller Stand

✅ **Fertig (Fundament + Start-Screen):**

| Bereich | Datei | Flutter-Quelle |
|---|---|---|
| Theme/Farben | `Config/Theme.swift` | `config/app_colors.dart` |
| API-Config | `Config/APIConfig.swift` | `config/api_config.dart` |
| HTTP-Client | `Networking/APIClient.swift` | `services/api_client.dart` |
| Token-Speicher | `Auth/KeychainStore.swift` | (ersetzt `SharedPreferences`) |
| Auth-Model | `Auth/AuthToken.swift` | `models/auth_token.dart` |
| Auth-Service | `Auth/AuthService.swift` | `services/auth_service.dart` |
| Auth-State | `Auth/AuthViewModel.swift` | `providers/auth_provider.dart` |
| App-Entry | `App/SihlClientApp.swift` | `main.dart` |
| Auth-Gate | `App/RootView.swift` | `main.dart` (Consumer) |
| Login | `Views/LoginView.swift` | `screens/login_screen.dart` |
| Tab-Shell | `Views/MainTabView.swift` | `screens/main_screen.dart` |
| Appointment-Model | `Models/Appointment.swift` | `models/appointment.dart` |
| DailyQuote-Model | `Models/DailyQuote.swift` | `models/daily_quote.dart` |
| AppointmentService | `Services/AppointmentService.swift` | `services/appointment_service.dart` |
| DailyQuoteService | `Services/DailyQuoteService.swift` | `services/daily_quote_service.dart` |
| StartViewModel | `ViewModels/StartViewModel.swift` | `providers/appointment_provider.dart` + `daily_quote_provider.dart` |
| Start-Screen | `Views/Start/StartView.swift` | `screens/start_screen.dart` |
| LoadingView / ErrorStateView | `Views/Start/StartView.swift` | `widgets/loading_indicator.dart` + `widgets/error_view.dart` |

⏳ **Noch zu übersetzen:** Profil & Abo → Kalender → Training → Chat → Analytics

## Setup auf dem Mac (einmalig)

1. **Repo pullen:**
   ```bash
   git pull
   cd Admin-Backend-php/client-ios
   ```

2. **Xcode-Projekt erstellen:** Xcode → `File → New → Project → iOS → App`
   - Product Name: `SihlClient`
   - Interface: **SwiftUI**, Language: **Swift**
   - Minimum Deployment: **iOS 17.0** (wegen `@Observable`)
   - Speicherort: direkt in `client-ios/` (sodass der `SihlClient/`-Ordner daneben/darin liegt)

3. **Quellen einbinden:** Den vorhandenen `SihlClient/`-Ordner per Drag&Drop in den
   Xcode Navigator ziehen → *„Create groups"* wählen, *„Copy items if needed"* **abwählen**
   (Dateien liegen schon im Repo). Die von Xcode generierte Default-`ContentApp.swift`/
   `ContentView.swift` löschen — `SihlClientApp.swift` ist der `@main`-Entry.

4. **Signing:** Target → *Signing & Capabilities* → dein Apple-Developer-Team wählen.

5. **Build & Run** (⌘R) auf Simulator oder Gerät. Login mit echten Zugangsdaten oder
   *„Demo ansehen"* (Mock-Pfad — Mock-Daten werden später übersetzt).

> **Hinweis:** Es gibt bewusst keine `.xcodeproj` im Repo — die wird auf dem Mac generiert.
> So bleibt das Repo plattformneutral und konfliktfrei.

## Architektur-Konventionen

- **State:** `@Observable`-Klassen (iOS 17), injiziert via `.environment(...)`,
  gelesen via `@Environment(SomeViewModel.self)`. 1:1-Ersatz für Flutter `ChangeNotifier` + `Provider`.
- **Networking:** `APIClient.shared` (actor) mit async/await. JSON via `Codable`.
- **Tokens:** Keychain (nicht UserDefaults). clientId (nicht sensibel) in UserDefaults.
- **Sprache:** UI-Texte Deutsch, exakt wie im Flutter-Original.
- **Farben:** immer `AppColor.*` — niemals hartkodierte Hex-Werte in Views.

## Weiterarbeiten (auf dem Mac mit Claude Desktop)

Pro Screen ein klarer Auftrag, z.B.:
> „Übersetze `client-flutter/lib/screens/calendar_screen.dart` und die zugehörigen
> `appointment_provider.dart` + `appointment_service.dart` + Models nach SwiftUI,
> nach dem Muster von `AuthViewModel`/`LoginView`. Lege die Dateien in
> `SihlClient/Views/`, `SihlClient/ViewModels/`, `SihlClient/Models/` ab."

Empfohlene Reihenfolge: **Start → Profil → Kalender (Kernflow) → Training → Chat → Analytics → Credits/Invoices.**
