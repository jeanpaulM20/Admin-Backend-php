# Reformer-Repertoire — Erfassungsblatt (Etappe 4)

`reformer-repertoire.csv` ist das Gerüst für das eigene Reformer-Repertoire
(Konzept, Abschnitt 9). Es enthält die **55 Übungen der klassischen
Reihenfolge** in der Fassung der Pilatesology-Blätter *Classical Reformer
Order & Spring Settings* (Basic / Intermediate / Advanced, 2020). Was das Studio
ausfüllt, steht in leeren Spalten; was vorbelegt ist, ist ein Vorschlag und
darf überschrieben werden.

## Format

Semikolon-getrennt, UTF-8 mit BOM — öffnet in Excel und Numbers direkt mit
Umlauten. Beim Speichern das Format beibehalten (CSV, Semikolon).

## Spalten

| Spalte | Herkunft | Bedeutung |
|---|---|---|
| `order` | Blatt | Platz in der klassischen Reihenfolge. Der Generator sortiert danach (Konzept 7). Reihenfolge des Advanced-Blatts als Obermenge; im Basic-Blatt steht „Feet in Straps" direkt nach dem Hundred — das regelt später das Level, nicht die Nummer. |
| `name_de` / `name_en` | Vorschlag | Deutscher Anzeigename (frei änderbar) und Originalname |
| `series` | Blatt | Serie, zu der die Übung gehört (Footwork, Rowing, Short Box …) |
| `level` | Blatt | `basic` / `intermediate` / `advanced` — erstes Auftreten in den drei Blättern |
| `position` | Vorschlag | Rückenlage · Bauchlage · Sitz · Knien · Stand · **Stütz** · Seitlage |
| `attachment` | Vorschlag | keines · lange Gurte · kurze Gurte · Box quer · Box längs · Jumpboard (Kombinationen mit „+") |
| `footbar` | Vorschlag | hoch · tief · unten |
| `headrest` | Vorschlag | oben · flach. **Bei allem, was über Kopf rollt, ist „flach" vorbelegt** — bitte prüfen, nicht streichen. |
| `carriage_start` | Vorschlag | geschlossen · offen |
| `springs_classical` | Blatt | Federzahl auf dem klassischen Vier-Feder-Reformer, wie auf dem Blatt (inkl. „2 oder 1", „gear out") |
| `spring_load` | abgeleitet | Dieselbe Zahl normiert (0–5). **Damit rechnet der Generator** — „eine Stufe leichter" heisst −1.0. „2 oder 1" ist als 1.5 eingetragen. |
| `springs_studio` | **leer** | **Eure** Federfarben für dieses Gerät, z.B. „1 rot + 1 blau". Das ist die Anzeige für den Trainer. Hängt vom Fabrikat ab (Balanced Body, Gratz, Merrithew haben verschiedene Stärken). |
| `breathing_de` | leer | Atemführung, z.B. „5 ein / 5 aus" |
| `tempo` | leer | z.B. „3-1-1-0" |
| `cues_de` | leer | Ansagen für den Trainer, eine je Zeile |
| `instructions_de` | leer | Ausführung Schritt für Schritt, eine je Zeile |
| `contraindications_vorschlag` | Vorschlag | Schlüssel aus `exercise-vocabulary.ts` (s.u.) — mein Vorschlag, **nicht abgenommen** |
| `contraindications` | **leer** | Die abgenommene Fassung. Nur diese Spalte wird importiert. Leer = keine Einschränkung. |
| `notes` | leer | Alles, was sonst nirgends hinpasst |

## Kontraindikations-Schlüssel

| Schlüssel | greift bei | vorbelegt bei |
|---|---|---|
| `lumbar_flexion_load` | Bandscheibe, LWS, Osteoporose | Hundred, Coordination, Teaser, Backstroke, Stomach Massage rund, Short Box rund, allen Roll-Overs |
| `inversion` | Herz-Kreislauf, Bluthochdruck, Schwangerschaft | Overhead, Short Spine, Long Spine, Corkscrew, Tick Tock, Control Balance |
| `supine_late_pregnancy` | Schwangerschaft ab 2. Trimester | alle Übungen in Rückenlage |
| `prone` | Schwangerschaft | Schwan, Pull Straps |
| `shoulder_overhead` | Schulterproblematik | Rowing (Chest/Hips/Shaving), Backstroke, Arm Circles, Long/Up Stretch, Push-Ups, Snake & Twist |
| `knee_deep_flexion` | Knie | Knees Off, Thigh Stretch, Chest Expansion, Arm Circles (Knien), Front/Russian Splits |
| `spinal_flexion`, `high_impact` | Osteoporose / Gelenke | nicht vorbelegt |

Die Vorbelegung ist bewusst **vorsichtig** — lieber eine Übung zu viel gesperrt
als eine zu wenig. Wer abnimmt, streicht, was fachlich nicht gilt, und trägt
das Ergebnis in `contraindications` ein. Das ist der einzige Teil dieses
Blatts, bei dem ein Fehler jemandem schaden kann (Konzept, Entscheidung 5).

## Was nicht drin ist

Headstands, Mermaid, Grasshopper, Rocking, Swimming, Long Box Series 2 und die
Jumpboard-Arbeit — sie stehen nicht auf den drei Blättern. Wer sie im Studio
unterrichtet, hängt sie einfach mit der nächsten `order`-Nummer an.

## Danach

Ist das Blatt abgenommen, liest ein Importer (Etappe 5) die Zeilen in
`exercise` (modality `pilates_reformer`) und `exercise_reformer` ein —
über die Import-Pipeline aus Etappe 2, mit eigenem Adapter für diese CSV.
