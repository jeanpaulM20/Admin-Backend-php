# Konzept: Route starten — Aufzeichnung mit Navigation

Stand: 4. Oktober 2026 · Status: Analyse und Konzept zur Freigabe
Ergänzt KONZEPT-ROUTENPLANER.md (Phase 5).

## 1. Beobachtung und Ursache

**Beobachtung:** Nach „Tour starten" aus dem Planer landet man wieder im
Routenplaner statt in der Aufzeichnung; die Route lässt sich nicht wie mit
einem Navigationssystem ablaufen.

**Ursache (Code):** Die Aufzeichnung hat in der App genau einen Ort — den
Tab „Start" mit `RecordWorkoutView` und dem `WorkoutRecorder`. „Tour
starten" aus Planer, Tour-Detail und Assistent schiebt aber jeweils eine
**zweite Kopie** von `RecordWorkoutView` in den Navigationsstapel des
Touren-Tabs (eigener Recorder, eigene Sensoren):

| Einstieg | Code | Folge |
|---|---|---|
| Planer-Panel | `TourDiscoveryView` → `navigationDestination(item: $startRoute)` | Kopie im Touren-Stapel |
| Tour-Detail | `TourDetailView` → `navigationDestination(isPresented: $showRecord)` | Kopie im Touren-Stapel |
| Assistent | `TourAssistantView` → `navigationDestination(isPresented: $showRecord)` | Kopie im Sheet des Assistenten |

Die Kopie zeigt die Session als `fullScreenCover`; beim Beenden ruft ihr
`onDismiss` **`dismiss()`** auf und poppt die Kopie — man steht wieder im
Planer. Der Start-Tab weiss von alledem nichts: Er zeigt währenddessen
seine leere Startseite, und die Übersicht nach dem Training erscheint im
falschen Tab. Zusätzlich braucht jeder Start aus den Touren einen zweiten
Tipp („Training starten"), obwohl „Tour starten" bereits der Start war.

**Was heute beim Folgen fehlt:** Die Session kennt nur die Routenlinie
(`TourRoute`: Name, Segmente, Distanz, Aktivität) und prüft alle fünf
GPS-Punkte den Abstand zur Linie (Hinweis ab 100 m, zurück unter 60 m).
Es gibt keinen Fortschritt auf der Route, keine Restdistanz, keine
Resthöhenmeter, keine Ankunftszeit, keine Richtung zurück zur Route, keine
Abbiegehinweise, keine Zielerkennung. Höhen und Dauer der geplanten Route
gehen bei der Übergabe verloren.

## 2. Ziel

„Tour starten" bringt mich **mit einem Tipp** in die Aufzeichnung — dort,
wo jedes Training läuft (Tab „Start") — mit der Route als Leitlinie, und
die Aufzeichnung führt mich wie ein Navi: Karte in Laufrichtung, Rest
bis zum Ziel, Hinweis beim Verlassen der Route mit Richtung zurück,
Ankunft am Ziel, auf Wunsch Abbiegehinweise mit Sprache.

## 3. Übergabe: ein Ort für die Aufzeichnung (Phase 5.1)

- **`RecordingLauncher`** (@Observable, app-weit in der Environment wie
  `StartViewModel`): `func start(_ route: PlannedTourRoute)`. Er merkt sich
  die Route als `pending` und setzt `requestedTab = .start`.
- **`MainTabView`** beobachtet `requestedTab` und wechselt die Auswahl auf
  „Start". Der Touren-Stapel bleibt, wie er ist (der Planer behält seine
  Punkte — man kann nach dem Training zurück und die Route speichern).
- **Start-Tab `RecordWorkoutView`** beobachtet `pending`: Route in den
  Recorder laden, Aktivität vorwählen, **Aufzeichnung sofort starten** —
  mit 3-Sekunden-Countdown und „Abbrechen" (Gurt verbindet, GPS holt den
  ersten Fix). „Tour starten" war der Startbefehl; ein zweites „Training
  starten" entfällt.
- **Alle drei Einstiege** (Planer, Tour-Detail, Assistent) rufen nur noch
  den Launcher. Die gepushten Kopien von `RecordWorkoutView` und das
  `dismiss()` im `onDismiss` entfallen. Nach dem Beenden bleibt man im
  Start-Tab mit der gewohnten Übersicht.
- **Läuft bereits eine Aufzeichnung** (Recorder-Phase ≠ idle): Rückfrage
  „Laufendes Training beenden und Route starten?" — nie zwei Sessions.
- **Übergabemodell `PlannedTourRoute`** ersetzt `TourRoute`: Name,
  Segmente **mit Höhen**, Distanz, Höhenmeter auf/ab, Dauer (SAC),
  Aktivität, Rundkurs, optional benannte Wegpunkte (Planer-Punkte,
  Assistenten-Orte). Damit hat die Navigation ihre Grundlage.

## 4. Navigation während der Aufzeichnung (Phase 5.2)

**Fortschritt auf der Route** (`RouteProgress` im Recorder, bei jedem
Track-Punkt, nicht nur alle fünf):
- Projektion der Position auf die Route: nächster Linienabschnitt, aber
  **monoton** (nie zurück auf einen früheren Abschnitt — wichtig bei
  Hin-und-zurück-Strecken und Rundkursen), mit Toleranz für Abkürzungen.
- Daraus: zurückgelegte Routendistanz, **Restdistanz**, **Resthöhenmeter
  auf/ab** (aus den Höhen ab der Projektion), **Ankunft ca.** (Rest nach
  SAC-Formel mit dem Tempo der Aktivität, gemischt mit dem eigenen
  bisherigen Schnitt, sobald > 500 m zurückgelegt), nächster Wegpunkt mit
  Distanz.

**Karte:**
- Laufrichtung-oben und Kamera-Folgen gibt es schon. Neu: der Kamera-
  Mittelpunkt liegt **etwas voraus** (Position im unteren Drittel), damit
  man sieht, was kommt.
- **Gelaufener Teil** der Route grau, **Rest** blau; nächster Wegpunkt
  als Marker mit Distanz; Ziel-Fahne mit Restdistanz.
- Kennzahlen-Kacheln der Session bekommen eine Routen-Zeile:
  „Noch 4.2 km · ↑180 m · Ankunft ca. 15:40". Der Mini-Höhenprofil-Streifen
  (aus dem Planer) zeigt die aktuelle Position als Marker.

**Verlassen der Route** (bestehende Hysterese 100 / 60 m bleibt):
- Zusätzlich **Haptik** (Warn-Taptic) und ein Pfeil im Positionsmarker,
  der zur nächsten Routenstelle zeigt, mit Abstand („120 m ↗ zur Route").
- Sprachhinweis optional (siehe 5.4), Standard aus.

**Ankunft:** Innerhalb 30 m vom Ziel und mindestens 90 % der Route
abgeschritten → „Ziel erreicht" (Haptik, Banner) mit Vorschlag „Beenden".
Beim Rundkurs zählt der Start als Ziel, aber erst nach 90 %.

**Ohne Route** ändert sich nichts an der Session.

## 5. Abbiegehinweise mit Sprache (Phase 5.3, optional)

- BRouter liefert mit `turnInstructionMode=2` je Route **Voice-Hints**
  (Abstand, Abbiegewinkel, Typ: links/rechts/halb/Kehre). Das Backend
  reicht sie als `hints: [{at: m, turn: "TL"|"TR"|"TSLL"|…, text}]` in
  der Tour-Form durch — für Planer, Rundtour, A→B und Assistent gleich.
- Die Session zeigt den nächsten Hinweis als Banner („In 180 m links")
  mit Pfeil-Symbol und spricht ihn **auf Wunsch** (AVSpeechSynthesizer,
  Deutsch) bei 150 m und bei 30 m; Haptik beim Abbiegepunkt. Schalter
  „Sprachhinweise" in der Session (merkt sich die Wahl).
- Grenze ehrlich benannt: Abbiegehinweise stammen aus OSM-Wegdaten und
  sind auf Wanderwegen gröber als auf Strassen; sie ergänzen die Karte,
  sie ersetzen sie nicht.

## 6. Regeln und Kanten

- **GPS-Lebenszyklus** bleibt: eingeschaltet nur während der Aufzeichnung
  (Entscheidung vom September). Der Countdown holt den ersten Fix.
- **Hintergrund:** Haptik und Sprache funktionieren mit gesperrtem
  Bildschirm (Audio-Session `.playback` mit Ducking), die Karte nicht —
  eine Live-Aktivität auf dem Sperrbildschirm (Restdistanz, nächster
  Hinweis) ist ein eigener späterer Schritt.
- **Rundkurs:** Start = Ziel; Fortschritt monoton, Zielerkennung erst
  nach 90 %.
- **Abkürzung/Umweg:** Projektion erlaubt Vorsprünge bis 300 m entlang
  der Route (Abkürzung); grössere Sprünge werden als Off-Route behandelt,
  bis man wieder nahe der Linie ist.
- **Demo-Modus:** Übergabe und Fortschritt funktionieren mit der
  Luftlinie, Hinweise nennen „Demo".
- **Speichern nach dem Training:** Die Route bleibt im Planer; die
  Zusammenfassung bietet „Route behalten" (speichert sie unter Meine
  Routen, falls noch nicht geschehen).

## 7. Phasen und Aufwand

| Phase | Inhalt | Aufwand |
|---|---|---|
| **5.1 Übergabe** | Launcher, Tab-Wechsel, Autostart mit Countdown, drei Einstiege umgestellt, Kopien und `dismiss()` entfernt, `PlannedTourRoute` mit Höhen/Dauer, Rückfrage bei laufender Session | 1 Tag |
| **5.2 Navigation** | Fortschritt (monotone Projektion), Rest/Ankunft/nächster Wegpunkt, Karte voraus und gelaufener Teil grau, Profil-Marker, Off-Route-Pfeil + Haptik, Ankunft | 1.5 Tage |
| **5.3 Abbiegehinweise** | BRouter-Hints im Backend, Banner, Sprache (optional), Haptik | 1.5–2 Tage |

5.1 behebt den gemeldeten Fehler vollständig und ist für sich nutzbar.

## 8. Offene Entscheidungen (bitte bestätigen)

1. **Autostart** mit 3-Sekunden-Countdown nach „Tour starten" (vorgeschlagen) — oder Landung auf der Startseite mit einem weiteren Tipp?
2. **Sprachhinweise** standardmässig **aus**, per Schalter in der Session (vorgeschlagen).
3. **Phase 5.3** gleich mit umsetzen oder nach Praxiserfahrung mit 5.1/5.2?
