# App-Store-Einreichung SIHLMOVE 1.0

Angaben zum Übertragen in App Store Connect → SIHLMOVE → Vertrieb → iOS-App 1.0.

---

## App-Informationen

- **Name:** SIHLMOVE
- **Untertitel (max. 30 Zeichen):** Training, Touren & Coaching
- **Kategorie:** Gesundheit und Fitness (Zweitkategorie: Navigation oder Sport)
- **Datenschutzrichtlinie-URL:** https://admin-backend-php-production.up.railway.app/legal/datenschutz.html
- **Support-URL:** https://sihltraining.ch
- **Copyright:** 2026 Jean Paul Mvongo, Personal Training

## Werbetext (max. 170 Zeichen)

Zeichne Läufe, Velotouren und Wanderungen auf, plane Routen per Fingertipp und folge ihnen mit Abbiegehinweisen – dein Training bei Jean Paul Mvongo, immer dabei.

## Beschreibung

SIHLMOVE ist die App für Kundinnen und Kunden von Jean Paul Mvongo, Personal Training in Zürich. Sie verbindet dein persönliches Training mit Bewegung draussen: Du zeichnest Läufe, Velotouren und Wanderungen mit GPS und Herzfrequenz auf, planst neue Routen per Fingertipp und folgst ihnen unterwegs mit Abbiegehinweisen und Sprachansagen. Dein Trainer sieht deine Fortschritte und bleibt per Chat erreichbar.

TRAINING AUFZEICHNEN
Joggen, Radfahren, Wandern oder Krafttraining mit Dauer, Distanz, Tempo, Höhenmetern und Herzfrequenz vom Brustgurt. Nach dem Training ein Foto dazu – fertig.

TOUREN ENTDECKEN UND PLANEN
Wanderungen, Bergtouren, Lauf- und Velostrecken in deiner Umgebung mit Dauer, Höhenprofil und Schwierigkeit. Start, Zwischenziele und Ziel auf die Karte tippen, die Route wird automatisch berechnet. Rundkurs auf Knopfdruck, Routen speichern und wiederverwenden.

WIE MIT EINEM NAVI
Die geplante Route begleitet dich in der Aufzeichnung: Reststrecke, Resthöhenmeter, Ankunftszeit und Abbiegehinweise, auf Wunsch gesprochen – auch mit gesperrtem Bildschirm.

TOUREN-ASSISTENT
Beschreibe deine Wunschtour in eigenen Worten und erhalte einen fertigen Routenvorschlag.

TRAININGSPLAN, KALENDER UND CHAT
Die Übungen deines Trainers mit Bildern, Timer und Hinweisen. Lektionen im Studio buchen, Termine im Blick, Fragen direkt an deinen Trainer.

AUSWERTUNG
Körperwerte und Trainings im Verlauf, einzelne Einheiten vergleichen.

Für die Anmeldung brauchst du ein Konto von Jean Paul Mvongo, Personal Training. Mit „Demo ansehen“ kannst du die App ohne Konto ausprobieren.

## Schlüsselwörter (max. 100 Zeichen)

Training,Wandern,Joggen,Velo,Route,Navi,Herzfrequenz,Personal Training,Zürich,Coaching,GPS,Touren

---

## App-Datenschutz (Fragebogen)

**Tracking:** Nein.

Alle folgenden Datentypen: **mit Identität verknüpft**, Zweck **App-Funktionalität**, nicht für Tracking.

| Kategorie | Datentyp |
|---|---|
| Kontaktinformationen | Name, E-Mail-Adresse |
| Gesundheit und Fitness | Gesundheit (Herzfrequenz), Fitness (Trainings) |
| Standort | Genauer Standort |
| Benutzerinhalte | Fotos oder Videos, Andere Benutzerinhalte (Chat, Kommentare, Fragen an den Assistenten) |
| Käufe | Kaufhistorie (Lektionen-Pakete) |
| Kennungen | Benutzer-ID, Geräte-ID (Push-Token) |

Nicht erhoben: Zahlungsinformationen (keine Zahlung in der App, Rechnung mit QR-Einzahlungsschein), Diagnose- und Absturzdaten, Browserverlauf, Suchverlauf, Kontakte.

## Altersfreigabe

- Medizinische oder Wellness-Themen: **Ja** (Fitness, Herzfrequenz).
- Nachrichten und Chat: **Ja** (privater Chat mit dem Trainer, KI-Assistent).
- Nutzergenerierte Inhalte für andere sichtbar: **Nein** (nur privat zwischen Kunde und Trainer).
- Uneingeschränkter Webzugang, Werbung, Glücksspiel, Gewalt, Sexualität, Alkohol/Tabak: **Nein**.
- Erwartetes Ergebnis: 13+ (je nach Antwort zu Chat/KI evtl. 12+/13+).

## Informationen für die App-Prüfung

**Anmeldeinformationen:** Prüfkonto (E-Mail und Passwort) mit Terminen, Chatverlauf, freigeschaltetem Trainingsplan und Trainings – vom Inhaber direkt in App Store Connect eintragen.

**Hinweise (auf Englisch für das Review-Team):**

SIHLMOVE is the companion app for clients of Jean Paul Mvongo, Personal Training, an independent personal trainer in Zurich, Switzerland. Accounts are created by the trainer after a client signs up in person; there is no in-app registration. "Demo ansehen" on the login screen shows sample data without an account. Please use the review account provided for full access.

Payments: The app sells no digital content and processes no payments. "Lektionen & Guthaben" are packages for one-on-one personal-training sessions that take place in person at the studio (guideline 3.1.3(e)); ordering one creates an invoice with a Swiss QR payment slip, paid outside the app. Online coaching content (training plans) is arranged with the trainer outside the app and only displayed in the app.

Background modes:
- Location: recording the route and turn-by-turn guidance during an active workout only (blue indicator).
- Bluetooth: heart-rate chest strap (e.g. Polar H10). Without a strap the app records duration and route only.
- Audio: spoken turn instructions. To test: Touren tab → "Route planen" → tap start and destination → "Tour starten" → tap the speaker icon in the recording to enable voice → lock the screen.

AI: The tour assistant (sparkle icon in the Touren tab) sends the user's messages via our server to Anthropic (Claude). The app asks for consent before first use and shows that answers may contain errors. Limit: 30 questions per day.

Push notifications are optional (Profil → Benachrichtigungen) and used for trainer messages and appointment reminders only.

Account deletion: Profil → "Konto löschen".

---

## Vor dem Einreichen prüfen

1. Build 5 in TestFlight verarbeitet, keine Warn-Mails von Apple (ITMS-…).
2. Datenschutzerklärung unter der URL erreichbar und inhaltlich geprüft.
3. Prüfkonto funktioniert, Abo läuft nicht ab, kein Ablauf-Hinweis.
4. Screenshots 6,9" (1320×2868) ohne Blutzucker und ohne Coaching-Kauf.
5. Unter „Preise und Verfügbarkeit": kostenlos, Länder wählen.
