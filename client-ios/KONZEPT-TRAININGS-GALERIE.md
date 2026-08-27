# Konzept: Trainings-Galerie („Reels") auf dem Start-Tab

Stand: 2026-08-27 · Status: Konzept, vor Umsetzung zu prüfen

## 1. Ziel

Unter dem Startknopf entsteht eine visuelle Erinnerung an absolvierte
Trainings: hochformatige Fotokarten im Reel-Format, gefiltert nach der
oben gewählten Aktivität. Ein Tipp öffnet die Details der damaligen
Einheit — samt Knopf, **dieselbe Einheit erneut zu starten**.

Nutzen: Der leere Bereich wird zum Motivations- und Wiedereinstiegs-
Punkt. Statt „was mache ich heute?" sieht man „das war schön — nochmal".

## 2. Ablauf (User Flow)

```
Training beenden → Zusammenfassung
   │  neu: „Foto hinzufügen" (Kamera oder Mediathek, optional)
   ▼
Foto wird auf 9:16 zugeschnitten und lokal gespeichert,
verknüpft mit: Aktivität · Datum · Dauer · Distanz · Höhenmeter ·
Ø-Puls · Routenverlauf (falls GPS)
   ▼
Start-Tab: Galerie unter dem Startknopf
   │  zeigt nur Fotos der oben gewählten Aktivität
   │  („Krafttraining" gewählt → nur Kraft-Fotos)
   ▼
Tipp auf Karte → Detailansicht (grosses Bild, Kennzahlen, Karte)
   │
   ├─ „Nochmal starten" → Aufzeichnung mit gleicher Aktivität;
   │   bei GPS-Trainings wird die damalige Route als Vorlage übernommen
   └─ Foto löschen
```

## 3. Bildformat (Vorbild Instagram Reels)

- **9:16 hochkant**, horizontal scrollende Karten mit Einrasten
- Kartenbreite ~150 pt (drei angeschnittene Karten sichtbar → lädt zum
  Wischen ein), Höhe ~265 pt
- Auf dem Bild unten ein weicher Verlauf, darin: Aktivitäts-Symbol,
  Datum, wichtigste Kennzahl (Distanz oder Dauer)
- Ecken im App-Radius, gleiche Kachel-Sprache wie die Aktivitäts-Chips

## 4. Datenhaltung — Empfehlung: zunächst lokal

Der Bestand gibt keinen Bildspeicher her: Die `file`-Tabelle des
Backends **verweist nur auf externe URLs** (der Controller reicht sie
durch), und auf Railway ist weder ein Volume noch ein Objektspeicher
eingerichtet. Fotos serverseitig zu halten hiesse also: neuer Speicher
(Volume oder S3/R2), Kosten, Migration.

**Phase F1 speichert darum auf dem Gerät:**

```
Documents/workout-photos/
   index.json          ← Liste der Einträge (Metadaten)
   <uuid>.jpg          ← Bild, 1080×1920, JPEG ~0.8 Qualität (~300 KB)
```

Ein Eintrag im Index:

```json
{ "id": "…", "reviewId": 4711, "activity": "Wandern",
  "date": "2026-08-27T15:33:00Z", "durationSec": 5280,
  "distanceM": 8300, "elevationGain": 420, "avgHR": 128,
  "routeFile": "<uuid>.route.json" }
```

- **Vorteile:** sofort umsetzbar, keine Serverkosten, Fotos verlassen
  das Gerät nicht (Datenschutz), funktioniert offline
- **Grenze, ehrlich benannt:** Beim Gerätewechsel oder Neuinstallation
  sind die Fotos weg. Wer sie sichern will, nutzt bis dahin die
  iCloud-Gerätesicherung (Documents wird mitgesichert).
- **Phase F3** kann das später serverseitig spiegeln, wenn ein
  Objektspeicher steht — das Datenmodell ist darauf vorbereitet
  (`reviewId` verknüpft schon mit der Aufzeichnung im Backend).

## 5. Was ohne Foto passiert

Nur Einheiten **mit Foto** erscheinen in der Galerie — keine
Platzhalterkarten, keine Lücken. Ist noch kein Foto vorhanden, steht
statt der Reihe ein einzeiliger, ruhiger Hinweis:
„Nach dem Training ein Foto aufnehmen — es erscheint hier."

Optional für Phase F2: Bei GPS-Trainings ohne Foto lässt sich ein
Kartenbild der Route als Karte erzeugen (MapKit-Snapshot), damit auch
fotolose Touren sichtbar werden.

## 6. Berechtigungen und Datenschutz

- Neu im Info.plist: `NSCameraUsageDescription` und
  `NSPhotoLibraryUsageDescription` mit klaren deutschen Texten
- Das Foto ist **freiwillig**: Die Zusammenfassung speichert das
  Training auch ohne Bild, der Knopf ist ein Angebot, keine Pflicht
- Kein Upload, keine Weitergabe (Phase F1); Löschen jederzeit möglich

## 7. Phasen

- **F1 — Kern:** Foto in der Zusammenfassung aufnehmen/auswählen,
  lokale Ablage, Galerie auf dem Start-Tab mit Aktivitätsfilter,
  Detailansicht mit Kennzahlen und Karte, „Nochmal starten"
- **F2 — Komfort:** Kartenbild als Ersatz bei fotolosen GPS-Trainings,
  mehrere Fotos je Einheit, Teilen-Funktion
- **F3 — Sicherung:** serverseitige Spiegelung (Objektspeicher),
  damit die Galerie den Gerätewechsel überlebt

## 8. Offene Punkte für die Abnahme

1. Lokale Ablage für F1 in Ordnung, oder soll gleich serverseitig
   gespeichert werden (Kosten, Einrichtung)?
2. Ein Foto je Training genügt für F1?
3. Soll „Nochmal starten" bei Touren die alte Route übernehmen (Vorschlag: ja)?
