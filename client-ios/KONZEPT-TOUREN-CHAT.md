# Konzept: Touren-Assistent (Chat) — „Beschreib deine Tour, ich finde die Route"

Stand: 2026-08-25 · Status: Konzept, verifiziert mit echten Daten

## 1. Ziel

Im Touren-Bereich beschreibt der Kunde seine Wunschtour in natürlicher Sprache —
die KI versteht Start, Ziel, Aktivität und Rahmenbedingungen, **berechnet echte
Routen**, prüft sie gegen die Wünsche und liefert einen startbaren Vorschlag
(Karte, Distanz, Höhenmeter, Dauer, „Tour starten").

**Referenzbeispiel** (vom Kunden):
> „Ich möchte mit Freunden zum Rigi Kulm wandern, Dauer 120 Minuten.
> Wir würden gerne in Vitznau starten und mit der Bahn runterfahren."

Verifizierter Ablauf mit echten Daten (2026-08-25):
- Geocoding: Vitznau (47.009, 8.485), Rigi Kulm (47.055, 8.484) — via Nominatim ✓
- Route Vitznau→Kulm: **8.3 km, 1321 Hm, SAC-Dauer 257 Min** — Wunsch (120 Min)
  ist **nicht machbar** → die KI darf das nicht schönreden
- Alternative (berechnet): Bahn bis **Rigi Kaltbad**, Wanderung Kaltbad→Kulm:
  **2.6 km, 292 Hm, 62 Min** ✓ — plus Abstieg nach Wunsch per Bahn
- → Ideale Antwort: ehrliche Einordnung + machbarer Gegenvorschlag mit Route

Genau diese Prüf- und Vorschlagslogik ist der Kern: **kein reines Sprachmodell-
Raten, sondern ein Werkzeug-Loop mit echten Berechnungen.**

## 2. Architektur

```
iOS TourChatView (Sheet im Touren-Bereich)
   │  POST /api/client/tours/assistant/:clientId
   │  { messages: [{role, content}, …] }        ← ganzer Verlauf (Follow-ups!)
   ▼
NestJS ToursAssistantService
   │  Claude (claude-haiku-4-5, Tool-Use-Loop, max. 8 Schritte)
   │  System-Prompt: Schweizer Outdoor-Assistent von Sihl Training,
   │    deutsch, ehrlich bei Dauer/Machbarkeit (SAC-Formel),
   │    fragt bei Unklarheit nach, endet wenn möglich mit EINER Route
   │
   ├─ Tool geocode(ort)        → Nominatim (1 req/s, User-Agent, CH-Bias)
   ├─ Tool route(a, b, aktivität) → BRouter A→B (hiking-beta/fastbike/gravel/mtb)
   │                              + SAC-Dauer, Distanz, Höhenmeter
   └─ Tool rundtour(start, km, aktivität) → bestehender Generator (T4)
   ▼
Antwort: { reply: String, route?: TourDetail-JSON }
   │  route = exakt das Schema des Rundtouren-Endpoints
   │  (segments mit ele, distanceKm, durationMin, elevationGain, name, activity)
   ▼
iOS: Chat-Blase (reply) + Routen-Karte (route) → TourDetailView(detail:)
   → Karte, Statistiken, Höhenprofil, GPX-Export, „Tour starten" (T3) —
   alles bereits vorhanden, null neue Detail-UI.
```

**Warum Tool-Loop statt einfacher Prompt:** Das Referenzbeispiel zeigt es —
das Modell muss Vitznau→Kulm erst rechnen, um zu wissen, dass 120 Min nicht
reichen, und dann Alternativen (höherer Start) durchprobieren. Ohne Werkzeuge
würde es plausibel klingende, falsche Touren erfinden.

**Warum im Backend:** ANTHROPIC_API_KEY liegt bereits auf Railway (Tageszitate),
der Schlüssel bleibt serverseitig; Nominatim/BRouter-Zugriffe laufen über die
bestehende User-Agent-Disziplin; Kosten und Limits zentral kontrollierbar.

## 3. UI-Konzept (iOS)

- **Einstieg:** Button im Touren-Kopf (Sparkles-Icon + „Fragen"), öffnet Sheet
  im bestehenden Kachel-Design. Kein zweiter CTA — ruhiger Surface-Chip neben
  GPX; „Rundtour" bleibt der eine CTA des Screens.
- **Chat:** Verlauf wie ChatThreadView (Blasen, Kachel-Radien, Screen-Rand-
  Token). Eingabefeld unten, Senden-Pfeil. Erste Ansicht zeigt 2–3 Beispiel-
  Chips („Panorama-Wanderung ab Zug, 2 h", „Gravel-Runde 40 km ab Adliswil").
- **Routen-Karte in der Antwort:** kompakte Karte (Mini-Map + Name + Distanz/
  Dauer/Höhenmeter) unter der Text-Blase; Tap → TourDetailView(detail:) →
  „Tour starten". Mehrere Vorschläge = mehrere Karten.
- **Follow-ups:** ganzer Verlauf geht mit („etwas kürzer", „lieber ab Weggis")
  → das Modell verfeinert mit denselben Werkzeugen.
- **Zustände:** Tipp-Indikator während der Berechnung (5–20 s wegen Tool-Loop,
  ehrlicher Hinweis „rechne Route…"); Fehler als Banner mit Retry; Demo-Modus
  antwortet mit vorbereitetem Beispiel ohne Backend.

## 4. Grenzen, Kosten, Datenschutz

- **ÖV („mit der Bahn runterfahren"):** Phase C1 versteht das als Einweg-Route
  (kein Rückweg-Routing) und erwähnt die Bahn textlich aus Modellwissen. Echte
  Fahrplandaten (transport.opendata.ch, gratis) sind Phase C3.
- **Kosten:** claude-haiku-4-5, max. 8 Tool-Schritte, max_tokens begrenzt;
  Limit pro Kunde (z. B. 20 Anfragen/Tag, in-memory) gegen Missbrauch.
- **Datenschutz:** Nur der Fragetext (Ortsnamen, Wünsche) geht an Anthropic —
  keine Kundendaten, keine Positionsdaten ausser explizit genannten Orten.
- **Ehrlichkeit:** System-Prompt verpflichtet auf berechnete Werte; keine
  Route ohne vorherigen route()-Aufruf; Machbarkeits-Urteil immer aus der
  SAC-Dauer, nie geschätzt.
- **Fehlertoleranz:** Tippfehler („Vetznau") korrigiert das Modell vor dem
  Geocoding; Nominatim-Miss → Rückfrage statt Raten.

## 5. Phasen

- **C1 — Kern (Beispiel funktioniert):** Backend-Endpoint mit Tool-Loop
  (geocode, route, rundtour), iOS-Chat-Sheet mit Routen-Karten, Übergabe an
  TourDetailView/„Tour starten". Verlauf = Multi-Turn.
- **C2 — Komfort:** Beispiel-Chips, Vorschlags-Chips unter Antworten
  („kürzer", „anderer Start", „als Rundtour"), 2 Varianten pro Antwort,
  Verlauf pro Gerät persistieren.
- **C3 — ÖV-Daten:** transport.opendata.ch als viertes Tool (nächste
  Bahn/Bus-Verbindung ab Zielort), Hinweis „Rigi-Bahn ab Kulm alle 30 Min".

## 6. Offene Punkte (bewusst)

- Mehrsprachigkeit: Antwortsprache folgt der Frage (Prompt-Regel), UI bleibt deutsch.
- Assistent könnte künftig auch bestehende OSM-Touren (T1) durchsuchen —
  als weiteres Tool denkbar, C2+.
