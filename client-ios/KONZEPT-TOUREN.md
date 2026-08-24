# Konzept: Touren entdecken (Komoot-Vorbild)

*Stand: 2026-08-24 — Analyse & Ausarbeitung; baut auf KONZEPT-TRAINING-TRACKING.md
(Stufe B/C) auf und vertieft sie zu einem vollständigen Touren-Feature.*

## 1. Was der Komoot-Screenshot funktional zeigt

Dekomposition der Referenz (Touren-Tab, Suche „Zumikon"):

| Element im Screenshot | Funktion |
|---|---|
| Suchfeld „Zumikon" | Orts-Suche (Geocoding) als Kartenmittelpunkt |
| Aktivitäts-Picker (Wander-Icon ▾) | Filter: Wandern / Rad / Laufen |
| „in 9 km Umkreis" | Radius-Filter um den Suchort |
| „Filter" | Dauer/Distanz/Schwierigkeit einschränken |
| Rote Tourenlinie auf der Karte | Geometrie der ausgewählten Tour |
| Orange Augen-Pins („Blick auf Zürich…", „Sihl-Uferweg") | **Highlights** entlang der Route (Aussichtspunkte, besondere Orte) |
| Restaurant-/Gipfel-Pins | POIs entlang der Route |
| „Planen"-Button | Eigene Route erstellen (A→B / Rundtour) |
| Tour-Karte unten | Titel, Schwierigkeit („Schwer"), Bewertung (4.7), Community-Zahl (170), **Dauer · Distanz · Höhenmeter** (5Std 31Min · 18.2 km · 550 m), Foto |
| „In diesem Gebiet suchen" | Suche auf sichtbaren Kartenausschnitt |
| Tab „Aufzeichnen" | Übergang Tour → Live-Tracking (unser Phase-1/2-Recorder!) |

## 2. Die Datenfrage — was „von OpenMap" wirklich kommt (und was nicht)

Die Annahme „man erhält die Tour von OpenMap" stimmt **zur Hälfte**. Komoot
baut auf OpenStreetMap (OSM) auf — aber es sind zwei verschiedene Dinge:

### Was OSM/offene Quellen tatsächlich liefern ✅

| Baustein | Quelle | Zugang |
|---|---|---|
| **Wegenetz** (Wander-/Velowege, Trails inkl. Belag) | OSM | Grundlage aller Routing-Engines |
| **Markierte, benannte Routen** (Wanderland/Veloland Schweiz, regionale/lokale Wanderwege als `route=hiking`/`route=bicycle`-Relationen) | OSM | **Overpass API** oder **Waymarked Trails API** (Bounding-Box → Routen mit Name, Geometrie, Markierung) |
| **Schwierigkeit von Wegen** | OSM `sac_scale` (T1–T6), `mtb:scale` | direkt in den Wegdaten |
| **POIs/Highlights** (Aussichtspunkte `tourism=viewpoint`, Gipfel `natural=peak`, Restaurants, Feuerstellen) | OSM | Overpass API |
| **Routen-Generierung** (A→B und **Rundtouren**: Start + Wunschlänge → Loop) | OSM-basiert | **OpenRouteService** (`round_trip`-Option), GraphHopper, Valhalla — Profile Wandern/Rad/Laufen |
| **Höhenprofil** | SRTM/Kartendaten | ORS liefert Elevation direkt zur Route |
| **Karten-Kacheln** | OSM-Renderer | OpenTopoMap; für die Schweiz: **Swisstopo-WMTS ist frei** (seit 2021) — der „echte" Wanderkarten-Look |
| Orts-Suche | — | `MKLocalSearch` (Apple, gratis) oder Nominatim/Photon (OSM) |

### Was NICHT offen verfügbar ist ❌

**Komoots kuratierte Community-Touren** — genau das, was die Tour-Karte im
Screenshot zeigt (Bewertung 4.7, 170 Teilnehmer, Fotos, redaktionelle
Highlights): Das ist **proprietärer Komoot-Content**. Komoot hat keine
öffentliche API (nur Partner-Zugang); dieser Teil lässt sich nicht „beziehen",
nur funktional nachbauen. Einzelne Komoot-Touren kann ein Nutzer aber als
**GPX exportieren** und bei uns importieren.

**Konsequenz fürs Konzept:** Wir bauen die Komoot-*Mechanik* (Entdecken,
Filtern, Highlights, Kennzahlen, Tour starten) auf offenen Daten — und
ersetzen Komoots Community-Ebene durch etwas, das Komoot nicht hat: den
**Trainer** (kuratierte Touren-Empfehlungen im Coaching-Kontext).

## 3. Vier Touren-Quellen für SihlClient

1. **Markierte OSM-Routen** *(Kern der „Entdecken"-Ansicht)*
   Overpass/Waymarked-Trails-Abfrage im Umkreis: benannte Wander-/Velorouten
   mit Geometrie. Für den Raum Zürich sehr gut gepflegt (Zürcher Wanderwege,
   Wanderland-Routen, Velorouten).
2. **Generierte Rundtouren** *(das „Planen" im Screenshot)*
   ORS `round_trip`: Startpunkt + Wunschdistanz + Aktivität → Rundkurs mit
   Höhenprofil. Deckt „Ich will heute 10 km ab Haustür" ab.
3. **Eigene & Trainer-Touren** *(unser USP)*
   - Eigene Aufzeichnungen (Phase-2-GPS-Tracks) als wiederholbare Touren
   - **Trainer kuratiert Touren** und weist sie Clients zu („Diese Woche:
     Uetliberg-Runde als GA1") — erscheint als Empfehlungs-Sektion; passt
     exakt ins Coaching-Modell und in die bestehende Trainer-Beziehung
4. **GPX-Import** — auch aus Komoot exportierte Touren laufen so bei uns.

## 4. Feature-Mapping: Screenshot → Umsetzung

| Komoot-Feature | Unsere Umsetzung | Quelle |
|---|---|---|
| Orts-Suche | `MKLocalSearch` | Apple |
| Aktivitäts-Picker | Wandern/Rad/Laufen (deckt `WorkoutActivity` ab) | — |
| Umkreis + „in diesem Gebiet suchen" | Radius bzw. sichtbare Bounding-Box → Backend | Overpass |
| Tourenlinie auf Karte | `MKPolyline`-Overlay | Geometrie aus Quelle |
| Highlights (Augen-Pins) | Aussichtspunkte/Gipfel/Restaurants **entlang der Route** (Korridor-Abfrage ±300 m) | Overpass |
| Schwierigkeit „Schwer" | Heuristik aus Distanz + Höhenmetern + `sac_scale` (T1–T2 leicht, T3 mittel, ≥T4 schwer) | OSM + berechnet |
| Dauer „5Std 31Min" | **SAC-Wanderzeitformel** (4,2 km/h horizontal, 400 Hm/h auf, 800 Hm/h ab; Rad: eigene Faktoren) | berechnet |
| Distanz / Höhenmeter | aus Geometrie + Elevation | ORS/берechnet |
| Bewertung / Community | **entfällt** (proprietär) → ersetzt durch Trainer-Empfehlung + „von dir N× absolviert" | eigene Daten |
| Fotos | entfällt im MVP (evtl. später eigene Fotos je Tour) | — |
| „Tour starten" | Übergabe an den Workout-Recorder: Route als graue Linie, Live-Position darüber | Phase 2 |

## 5. Architektur

### Backend als Proxy + Cache (NestJS) — nicht die App direkt an Overpass/ORS

Gründe: API-Keys bleiben serverseitig, Rate-Limits werden zentral verwaltet,
Overpass-Antworten sind langsam/groß → **Cache** (Touren im Umkreis ändern
sich selten; TTL Tage), einheitliches schlankes JSON für die App.

```
GET  /api/client/tours?lat&lon&radiusKm&activity     → Liste (id, name, activity,
     distanceKm, elevationGain, durationMin, difficulty, previewPolyline)
GET  /api/client/tours/:id                           → Detail (volle Geometrie,
     Höhenprofil [d,ele], Highlights [{name,type,lat,lon}])
POST /api/client/tours/roundtrip                     → {start, distanceKm,
     activity} → generierte Tour (ORS round_trip), gleiches Detail-Format
später: Trainer-Touren-CRUD + Zuweisung (neue Tabelle tour + tour_assignment)
```

Neue Tabellen erst mit den Trainer-Touren nötig; Discovery/Rundtouren sind
zustandslos hinter dem Cache.

### iOS

```
Views/Touren/
 ├── TourDiscoveryView    (Karte + Suchfeld + Aktivität/Radius + Tour-Cards
 │                         als horizontale Karten unten — wie Screenshot,
 │                         aber in unserer Marken-Palette)
 ├── TourDetailView       (Karte mit Route + Highlight-Pins, Stats-Zeile,
 │                         Höhenprofil-Chart [Charts, wie HrLineChart],
 │                         Highlights-Liste, „Tour starten"-CTA)
 └── TourMapComponents    (Polyline-Overlay, Pin-Views)
Services/TourService      (Backend-Calls, Codable-Modelle)
```

**Einstieg — kein 6. Tab!** (Max-5-Tabs-Lektion.) Zwei natürliche Orte:
1. Training-Tab: „Touren entdecken"-Karte unter der Record-Karte
2. Im Aufnahme-Start (`RecordStartView`): bei Joggen/Rad/Wandern ein
   optionales Feld „Route wählen" → öffnet die Discovery

**Karten-Look:** MVP mit Standard-MapKit (kostenlos, keine
Attribution-Pflicht). Später optional Swisstopo-WMTS via `MKTileOverlay`
für den echten Wanderkarten-Look (frei, aber Attribution „© swisstopo").

### Abhängigkeit zu Phase 2 (GPS-Tracking)

„Tour **ansehen/entdecken**" funktioniert ohne GPS-Tracking. „Tour
**starten**" (Route folgen + aufzeichnen) setzt Phase 2 aus dem
Tracking-Konzept voraus (CoreLocation, Live-Karte, GPS-Track-Upload).
**Empfohlene Reihenfolge: erst Phase 2, dann Touren** — sonst endet jede
Tour-Detailseite in einer Sackgasse.

## 6. Berechnungen (offline, deterministisch)

- **Wanderzeit** (SAC): `t = distanz/4.2 h + aufstieg/400 h + abstieg/800 h`,
  wobei kleinerer Term halbiert zum größeren addiert wird; Rad: ~15 km/h
  Basis + Höhenmeter-Zuschlag; Laufen: Pace-Eingabe des Nutzers als Basis.
- **Schwierigkeit**: leicht (<10 km und <300 Hm, max T2) / mittel / schwer
  (>15 km oder >800 Hm oder ≥T4) — transparent im Detail erklärt.
- **Höhenprofil**: kumulierte Distanz vs. Elevation, Anstiegssumme mit
  2-m-Glättung (wie im Tracking-Konzept).

## 7. Lizenz, Kosten, Abgrenzung

- **OSM-Daten**: ODbL — Attribution „© OpenStreetMap-Mitwirkende" im
  Touren-Bereich (Impressum + Kartenfuß). Kostenlos.
- **Overpass**: fair use → unser Backend-Cache ist Pflicht, nicht Option.
- **OpenRouteService**: kostenloser API-Key (Limits ~2000 Requests/Tag —
  mit Cache locker ausreichend); Alternative GraphHopper.
- **Swisstopo**: freie Nutzung mit Attribution.
- **Komoot**: keine API, kein Scraping, kein 1:1-Design-Klon — wir bauen die
  Funktionsidee in unserer eigenen Marken-Palette (CTA-Orange fürs
  „Tour starten", Salbei/Oliv-Karten-UI, Messing für Highlights wäre stimmig).

## 8. Phasenplan

**T1 — Discovery (read-only)**
Backend-Proxy (tours + tours/:id, Overpass + Cache), TourDiscoveryView
(Karte, Suche, Aktivität, Radius, Tour-Cards), TourDetailView (Route,
Stats, Höhenprofil, Highlights). Einstieg im Training-Tab.
*Voraussetzung: keine. Sofort machbar.*

**T2 — Phase 2 des Tracking-Konzepts** *(falls noch nicht geschehen)*
GPS-Aufzeichnung, Live-Karte, Track-Upload.

**T3 — Tour starten**
„Tour starten" → Recorder mit Routen-Overlay (graue Linie, Live-Position),
Distanz-auf-Route-Fortschritt; Off-Route-Hinweis (>100 m) als sanfter Toast.

**T4 — Planen & Kuratieren**
Rundtour-Generator (ORS `round_trip`), GPX-Import/Export,
Trainer-kuratierte Touren mit Zuweisung (+ Chat-Karte „Tour empfohlen").

## 9. Risiken & Grenzen

| Risiko | Einschätzung |
|---|---|
| Overpass-Verfügbarkeit/Langsamkeit | Backend-Cache + Timeout-Fallback („Keine Touren geladen — erneut versuchen") |
| Datenqualität einzelner OSM-Routen (Lücken in Relationen) | Geometrie beim Cachen validieren (zusammenhängend? sonst verwerfen) |
| Erwartung „wie Komoot mit Fotos/Bewertungen" | Erwartungsmanagement: unsere Stärke ist die Trainer-Kuratierung, nicht Community-Masse |
| ORS-Limits bei viel Rundtouren-Nutzung | Cache pro (Start-Rasterzelle, Distanz, Aktivität); notfalls bezahlter Plan |
| App-Store: Karten/Standort | unkritisch, Standard-Berechtigungen aus Phase 2 |

## 10. Offene Entscheidungen

1. **Reihenfolge bestätigen**: T1 (Discovery) zuerst oder erst Tracking-Phase 2?
2. **Trainer-Kuratierung** (T4) gewünscht? Braucht Trainer-UI (Web/Trainer-App).
3. **Swisstopo-Look** von Anfang an oder Standard-MapKit im MVP?
4. **ORS-Konto**: kostenlosen API-Key anlegen (E-Mail nötig) — wer legt an?
5. Standard-Radius (Komoot: 9 km) und welche Aktivitäten zum Start
   (Vorschlag: Wandern + Rad; Laufen nutzt dieselben Wege wie Wandern).

---

*Fazit: „Touren wie Komoot" ist machbar — aber die Touren kommen nicht
fertig „von OpenMap": OSM liefert Wegenetz, markierte Routen, POIs und (via
OpenRouteService) generierte Rundtouren; Komoots Community-Ebene (Bewertungen,
Fotos, kuratierte Highlights) ist proprietär und wird bei uns durch
Trainer-Empfehlungen ersetzt — was im Coaching-Kontext das stärkere Konzept
ist. Technisch: NestJS-Proxy mit Cache vor Overpass/ORS, MapKit-UI in der
Marken-Palette, „Tour starten" dockt an den bestehenden Workout-Recorder an.*
