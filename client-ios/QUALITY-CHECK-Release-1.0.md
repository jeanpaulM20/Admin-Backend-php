# Quality Check vor App-Store-Release 1.0 (Build 4)

Stand: 28.10.2026, Commit 87d426a5. Drei unabhängige Prüfungen: App-Store-Richtlinien, Release-Konfiguration und Sicherheit, Funktion und Stabilität. Die mit ✔ markierten Befunde sind zusätzlich direkt im Code nachgeprüft.

## A. Ablehnungsgründe bei Apple (vor Einreichung zu lösen)

| # | Befund | Guideline | Entscheid nötig |
|---|---|---|---|
| A1 ✔ | Coaching-Abo schaltet Trainingspläne in der App frei, Zahlung extern über Saferpay im Browser (CoachingPaywallView, CreditsView „Abo kaufen", Banner „1 Monat gratis testen", „Freischalten", „Verlängern"). Ablehnung sehr wahrscheinlich. | 3.1.1 | Ja: Kauf aus der App entfernen oder In-App-Abo |
| A2 ✔ | Blutzucker über die inoffizielle LibreLinkUp-API; die App gibt sich per Header als Abbotts App aus (`product: llu.ios`). | 5.2.2, 1.4.1 | Ja: für 1.0 ausblenden empfohlen |
| A3 ✔ | Keine Datenschutzerklärung in der App verlinkt (nur AGB-Punkt 10). | 5.1.1(i) | Ja: URL der Datenschutzerklärung |
| A4 | KI-Assistent sendet Chattexte an Anthropic ohne Hinweis und Einwilligung. | 5.1.2(i) | Nein, umsetzbar |
| A5 ✔ | Push-Entitlement fehlt (keine .entitlements-Datei); Push kann nie funktionieren, der Schalter im Profil springt zurück. | 2.1 | Explizite App-ID mit Push nötig (Apple Developer) |
| A6 ✔ | Privacy Manifest (PrivacyInfo.xcprivacy) fehlt; UserDefaults braucht Grund CA92.1. | ITMS-91053 | Nein, umsetzbar |
| A7 | Prüfung braucht ein echtes Prüfkonto; Kalender, Chat, Pläne und Profil sind im Demo-Modus gesperrt. | 2.1 | Ja: Prüfkonto mit Daten anlegen |
| A8 | Hintergrundmodus `remote-notification` ohne Funktion; Standort-Zweckstring nennt Touren/Navigation nicht. | 2.5.4, 5.1.1 | Nein, umsetzbar |

## B. Kaputte Kernabläufe

| # | Befund | Ort |
|---|---|---|
| B1 ✔ | Login zeigt nie eine Fehlermeldung (falsches Passwort → nur Spinner stoppt). | LoginView, AuthViewModel |
| B2 ✔ | Chat-Senden geht an `POST chat/:clientId/messages`, das Backend kennt nur `…/messages/:trainerId` → jede Nachricht 404. | ChatService |
| B3 ✔ | `trainer_id` wird als String gelesen, kommt als Zahl → leere Trainer-ID, Thread leer, Gelesen-Markierung kaputt. | ChatMessage |
| B4 ✔ | Terminzeiten ohne Zeitzone als UTC gelesen → in der Schweiz 1–2 h falsch, Absagefrist falsch berechnet. | Appointment, Kalender-Formatter |
| B5 | `training_type_id`/`location_id` als String gelesen → falsche Trainingsart gebucht, Puffer falsch. | CalendarData, PreferenceService |
| B6 | Ungültige Sitzung: jeder 401 heisst „E-Mail oder Passwort falsch", kein automatisches Abmelden, im Profil-Fehlerzustand kein Abmelden-Knopf. | APIClient, ProfileView |

## C. Datenschutz und Datenverlust

- C1: Logout lässt Libre-Daten, Push-Anmeldung, wartende Trainings, Foto- und HTTP-Cache liegen → nächstes Konto sieht Daten des vorigen.
- C2: Offline-Warteschlange lädt Trainings mit fremdem Token hoch und löscht sie nach 20 Fehlversuchen (auch reine Offline-Fehler).
- C3: Voller Auth-Token in URLs an Safari (Dateien, iCal) und im SSE-Query.
- C4: Gesundheitsdateien ohne Dateischutz, Keychain-Token wandert per Backup und überlebt Neuinstallation.
- C5: Polar-Anmeldung nutzt geteilte Browser-Sitzung; Gurt-Kopplung nimmt den erstbesten Gurt.

## D. Abstürze

- D1: GPX-Import mit `NaN`/`inf` bei Höhe → Absturz bei `Int(...)`.
- D2: Gerät mit hebräischem Kalender → Index-Absturz in der Auswertung (Monatsnamen).

## E. Mittel

Unterbrochenes Training geht bei „Abbrechen" verloren; jeder Upload-Fehler heisst „Kein Netz"; Nachreichen nur beim Kaltstart; Krafttraining ohne Gurt nicht wiederherstellbar; Übungs-Timer steht beim Scrollen und gesperrtem Bildschirm; verwaiste SSE-Verbindungen (Plan, Chat); Kommentar geht offline still verloren; Preise gerundet (49.90 → 50); Touren: alte Antworten überschreiben neue, Fehler verdeckt Liste, Rundtour öffnet ungefragt Detail; Chat-Zeitstempel mit Millisekunden nicht gelesen; Credits am letzten Gültigkeitstag als abgelaufen; Zahlungs-Polling ohne Ende; Push-Banner im Vordergrund fehlen; Querformat nicht gesperrt.

## F. Texte

„Schließen"/„Schließe" (5 Stellen), englische Begriffe (Files, Sync, Load, Avg, HR), ausgeschriebene Umlaute (Intensitaet, Liegestuetz, Koerperfett), „Mar", „Sehr Hart".

## Für App Store Connect

- App-Datenschutz: Kontaktdaten, Gesundheit und Fitness, genauer Standort, Fotos, andere Nutzerinhalte, Kaufhistorie, User-ID, Geräte-ID (Push); alles mit Identität verknüpft, kein Tracking.
- Altersfreigabe: Wellness/Fitness, Chat; voraussichtlich 13+.
- Prüfhinweise: Prüfkonto, keine Registrierung in der App (Konten vom Studio), Lektionen = Training vor Ort (3.1.3(e)), Hintergrundmodi mit Testweg, KI-Assistent mit Anbieter.
