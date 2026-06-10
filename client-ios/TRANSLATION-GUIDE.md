# Übersetzungs-Guide: Flutter → SwiftUI

Datei-für-Datei-Mapping für die restliche Portierung. Folge dem Muster aus dem
bereits übersetzten Auth-Slice (`AuthViewModel` ↔ `auth_provider.dart`,
`LoginView` ↔ `login_screen.dart`).

## Konzept-Mapping

| Flutter / Dart | SwiftUI / Swift |
|---|---|
| `StatelessWidget` | `struct: View` |
| `StatefulWidget` + `setState` | `@State` in einem `View` |
| `ChangeNotifier` + `notifyListeners()` | `@Observable final class` (Mutation triggert UI) |
| `Provider` / `context.watch` / `context.read` | `.environment(...)` + `@Environment(VM.self)` |
| `Model.fromJson(Map)` | `struct: Decodable` (`init(from:)` bei flexiblen Typen) |
| `http` package | `APIClient.shared` (URLSession async/await) |
| `FutureBuilder` / `await load()` in initState | `.task { await vm.load() }` |
| `SharedPreferences` | `UserDefaults` (unsensibel) / `KeychainStore` (Token) |
| `Navigator.push(MaterialPageRoute)` | `NavigationStack` + `.navigationDestination` |
| `Column` / `Row` / `Stack` | `VStack` / `HStack` / `ZStack` |
| `SizedBox(height: 16)` | `.padding(.top, 16)` bzw. `Spacer()` |
| `Container(decoration: BoxDecoration)` | `.background().clipShape().overlay(stroke)` |
| `Icons.*` (Material) | SF Symbols (`Image(systemName:)`) |
| `GoogleFonts.inter(...)` | `.font(.system(size:weight:))` (oder Inter als Custom Font einbinden) |
| `ScaffoldMessenger ... SnackBar` | `.alert(...)` oder Toast-Overlay |
| `debugPrint` | `print` / `Logger` |

## Standard-Vorgehen pro Feature

Ein Feature = **Model(s) + Service + Provider→ViewModel + Screen(s)**. Immer in dieser
Reihenfolge übersetzen (Datenfluss von unten nach oben):

1. **Models** → `SihlClient/Models/*.swift` als `Decodable` (Achtung: `id` oft Int *oder* String → flexibler Decoder wie in `AuthToken.swift`).
2. **Service** → Methoden auf `APIClient.shared` (`get/post/put/delete`), JSON-Decoding.
3. **Provider → ViewModel** → `@MainActor @Observable final class`, `load()` als `async`-Methode, `isLoading`/`error`-Felder wie beim Original.
4. **Screen → View** → SwiftUI, Daten via `@Environment(VM.self)`, Laden via `.task { }`.
5. **Registrieren:** neues ViewModel in `SihlClientApp.swift` als `@State` + `.environment(...)` ergänzen; Platzhalter in `MainTabView.swift` durch den echten View ersetzen.

## Feature-Inventar (zu übersetzen)

### Tab 1 — Start
- `screens/start_screen.dart`
- `providers/appointment_provider.dart` (liefert `startData`), `providers/daily_quote_provider.dart`
- `services/appointment_service.dart`, `services/daily_quote_service.dart`
- `models/daily_quote.dart`, Teile von `models/appointment.dart`

### Tab 2 — Training
- `screens/training_plan_list_screen.dart`, `training_plan_detail_screen.dart`
- `providers/training_plan_provider.dart`, `providers/exercise_timer.dart`
- `services/training_plan_service.dart`
- `models/training_plan.dart`

### Tab 3 — Kalender (Kernflow: Buchen/Stornieren)
- `screens/calendar_screen.dart`
- `providers/appointment_provider.dart`
- `services/appointment_service.dart`
- `models/appointment.dart`, `calendar_data.dart`, `trainer.dart`, `training_type.dart`

### Tab 4 — Chat
- `screens/chat_screen.dart`
- `providers/chat_provider.dart`
- `services/chat_service.dart`, `services/realtime_service.dart` (Realtime → URLSession WebSocket bzw. Polling)
- `models/chat_message.dart`
- Unread-Badge: in `MainTabView` via `.badge(...)` am `tabItem`.

### Tab 5 — Analytics / Performance
- `screens/performance_screen.dart`, `performance_detail_screen.dart`, `training_compare_screen.dart`
- `providers/performance_provider.dart`
- `services/performance_service.dart`
- `models/performance_section.dart`, `metric_history.dart`, `training_review.dart`
- Charts: Apple **Swift Charts** (`import Charts`) statt Flutter-Chart-Widgets.

### Profil & Abo
- `screens/profile_screen.dart`, `credits_screen.dart`, `coaching_paywall_screen.dart`, `invoices_screen.dart`
- `providers/profile_provider.dart`, `credits_provider.dart`, `invoice_provider.dart`, `preference_provider.dart`
- `services/profile_service.dart`, `credits_service.dart`, `payment_service.dart`, `invoice_service.dart`, `preference_service.dart`
- `models/profile_data.dart`, `credit_pack.dart`, `buyable_credit.dart`, `subscription.dart`, `invoice.dart`, `client_file.dart`
- `widgets/invoice_detail_sheet.dart` → `.sheet { }`

### Querschnitt
- `widgets/empty_view.dart`, `error_view.dart`, `loading_indicator.dart` → wiederverwendbare SwiftUI-Views in `SihlClient/Components/`.
- `services/mock_data.dart` → Demo-Modus (`token == "demo-token-preview"`). Optional, niedrige Priorität.
- **Push:** `services/push_notification_*.dart` → native `UNUserNotificationCenter` + APNs (separater Schritt, braucht Apple Push Certificate / Backend-Anpassung).

## API-Endpunkte (Referenz)

Basis: `https://admin-backend-php-production.up.railway.app/`, Header `X-Auth-Token`.

| Methode | Pfad | Zweck |
|---|---|---|
| POST | `api/client/token` | Login (`{email, passcode}` → `{token, client:{id,firstname,lastname}}`) |
| GET | `api/client/me` | eigene clientId (Recovery) |
| GET | `api/client/start/{clientId}` | Start-Screen-Daten |
| GET | `api/client/calendar/{clientId}` | Kalender, Trainer, Typen, Verfügbarkeit |
| GET | `api/client/profile/{clientId}` | Profil + Credit-Packs |
| GET | `api/client/credits/{clientId}` | kaufbare Abos |
| GET | `api/client/invoices/{clientId}` | Rechnungen |
| GET | `api/client/tests/{clientId}` | Performance-Tests |
| POST | `api/client/appointment/{clientId}` | Training buchen |
| PUT | `api/client/appointment/{appointmentId}` | Notizen ändern |
| DELETE | `api/client/appointment/{clientId}/{appointmentId}` | stornieren |

> Endpunkte gegen den aktuellen Code in `client-flutter/lib/services/*.dart` verifizieren —
> der Service-Layer dort ist die maßgebliche Quelle der Wahrheit.
