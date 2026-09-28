# Konzept: Automatische Trainingsprogramme — Fitness und Reformer Pilates

Stand 2026-09-28. Erweitert den bestehenden KI-Plangenerator
(`nestjs-backend/src/training-plan/ai-plan.service.ts`) um zwei Trainingswelten,
die er heute nicht abdeckt: **klassisches Gerätetraining** und **Pilates,
insbesondere am Reformer**.

---

## 1. Ausgangslage — gemessen, nicht geschätzt

**Der Generator ist ausgereift.** 1'390 Zeilen, und er zieht weit mehr heran als
einen Prompt: Anamnese, letzter Leistungstest, Messwerte, Ziele, die letzten
Aufzeichnungen und den Übungskatalog. Er leitet Schwächen aus dem Leistungstest
ab (`identifyWeaknesses`), zieht Kontraindikationen aus der Anamnese
(`extractContraindications`), rechnet Herzfrequenzzonen nach Karvonen und fällt
bei LLM-Ausfall auf ein Regelwerk zurück (`isRuleBased`). Diese Substanz bleibt.

**Der Katalog ist der Engpass.** 148 Übungen in der Produktionsdatenbank:

| Gruppe | Anzahl | | Körperregion | Anzahl |
|---|---|---|---|---|
| Plyometrie & Reaktivkraft | 35 | | LowerBody | 81 |
| Eigenkörpergewicht | 18 | | FullBody | 28 |
| Propriozeption | 18 | | UpperBody | 22 |
| Kettlebell | 15 | | Foot | 11 |
| Fuss & Barfuss | 11 | | **Core** | **6** |
| Exzentrik, Slackline, Mobilität | je 11 | | | |

Das ist ein **Athletik-Katalog**. Klassisches Gerätetraining (Beinpresse,
Latzug, Brustpresse, Rudermaschine) fehlt fast vollständig, Core hat sechs
Einträge, und **Pilates oder Reformer: null**.

**Das Datenmodell trägt die neuen Welten nicht.** Die Tabelle `exercise` hat
`name, group_id, subgroup_id, archive, published, body_region,
primary_muscle_group, target_joint, movement_pattern, icon`. Es gibt kein Feld
für Gerät, Schwierigkeitsgrad, Ausführungshinweise, Kontraindikationen, Tempo
oder Atmung — und erst recht nichts für Federn, Schlittenposition oder Fussbrett.

**Die Planstruktur ist auf Athletik zugeschnitten.** Vier feste Abschnitte
(`sonsomo`, `main`, `core`, `mobility`), je Zeile `device, position, weight,
sets`. Die Namen stecken an 29 Stellen im Backend und 4 in der iOS-App.

---

## 2. Die Lücke

| Anforderung | Heute | Fehlt |
|---|---|---|
| Klassische Fitnessübungen | ~20 von 148 | Geräte-Repertoire, Muskelzuordnung, Ausführungshinweise |
| Pilates Matte | 0 | Repertoire, Level, Atmung, Prinzipien |
| **Reformer Pilates** | 0 | Repertoire **plus** Federn, Fussbrett, Box, Gurte, Reihenfolge |
| Programmlogik | Athletik-Zirkel | Periodisierung Kraft, Flow-Logik Pilates |

Der Reformer ist dabei nicht „noch eine Übungsliste". Eine Reformer-Übung ist
ohne **Federspannung** gar nicht definiert: „Footwork mit 4 Federn" und
„Footwork mit 1 Feder" sind verschiedene Übungen mit verschiedenem Reiz. Diese
Angabe hat im heutigen Zeilenmodell keinen Platz — `weight` in Kilogramm passt
nicht auf „rot + blau".

---

## 3. Recherche: offene Übungsdatenbanken

Alle Angaben an den Rohdaten geprüft (JSON heruntergeladen bzw. API abgefragt),
nicht aus Beschreibungstexten übernommen.

### 3.1 Klassische Fitnessübungen

| Quelle | Umfang | Lizenz | Deutsch | Bilder | Befund |
|---|---|---|---|---|---|
| [RepDB](https://github.com/RepDB/exercise-dataset) | **601** | frei für kommerzielle App-Nutzung, **sichtbarer Attributionslink** nötig | **ja**, vollständig | 512px WebP | Reichstes Schema: `difficulty, equipment, body_part, primary/secondary_muscles, goals, tags, is_unilateral, is_bodyweight, met`, dazu `instructions_de` und `tips_de` |
| [free-exercise-db](https://github.com/yuhonas/free-exercise-db) | **876** | **Unlicense (Public Domain)** — keine Auflagen | nein (englisch) | ja | Sauberste Lizenz. Kategorien: strength 584, stretching 123, plyometrics 61, powerlifting 38, olympic 35, strongman 21, cardio 14. 871 Einträge mit Anleitung |
| [wger](https://github.com/wger-project/wger) | 845+ | Code AGPL-3, **Daten CC-BY-SA 3.0** | ja | ja | Share-Alike: abgeleitete Datenbestände müssten unter gleicher Lizenz weitergegeben werden — für einen proprietären Katalog heikel |
| [exercises-dataset](https://github.com/hasaneyldrm/exercises-dataset) | 1'324 | Code MIT, **Medien © Gym visual** | nein | GIFs | Für kommerzielle Nutzung eigene Medienlizenz nötig — **ausgeschieden** |

**Empfehlung: RepDB als Primärquelle, free-exercise-db als lizenzfreies
Rückgrat.** RepDB liefert als einzige fertiges Deutsch samt Ausführungshinweisen
und Tipps — bei 601 Übungen spart das eine Übersetzungsrunde, die sonst Geld
oder LLM-Zeit kostet und fachlich abgenommen werden müsste. Die Auflage ist ein
sichtbarer Link im Impressum der App. Wo RepDB dünn ist oder die Auflage stört,
füllt free-exercise-db auf: Public Domain heisst keinerlei Bindung.

Die Equipment-Vokabel von RepDB deckt genau das ab, was euch fehlt:
`leg_press, lat_pulldown_machine, chest_press_machine, smith_machine,
hack_squat, leg_curl, leg_extension, cable, ez_bar, hip_thrust_machine` …

### 3.2 Pilates und Reformer — der eigentliche Befund

**Es gibt keine brauchbare offene Datenbank.** Geprüft:

| Quelle | Pilates | Reformer |
|---|---|---|
| free-exercise-db (876 Übungen, im JSON durchsucht) | **0** | **0** |
| wger (API `search?term=pilates` und `term=reformer`) | **0** | **0** |
| RepDB (601 Übungen, im JSON durchsucht) | **9** Matten-Übungen | **0** |
| [neenan/pilates-workouts](https://github.com/neenan/pilates-workouts) | 143 Übungen **mit Federangaben** | ja — aber **ohne Lizenzdatei** |

Die neun Treffer bei RepDB sind Matten-Klassiker (Roll Down, Roll Over, Spine
Twist, Säge, Leg Pull Front/Back, Side Kick kniend, Spine Stretch Forward,
Seitbeuge) — brauchbar als Einstieg für Matte, aber kein Repertoire.

`neenan/pilates-workouts` ist der einzige Fund mit Reformer-Daten inklusive
Federeinstellungen. Er hat **keine Lizenz** — ohne Lizenz gilt volles
Urheberrecht, eine Übernahme wäre nicht zulässig. Wert hat er trotzdem: er
bestätigt, welche Felder ein Reformer-Datensatz braucht.

**Folgerung: Das Reformer-Repertoire müsst ihr selbst aufbauen.** Das ist
weniger dramatisch, als es klingt — der Umfang ist überschaubar und das Wissen
liegt im Studio.

### 3.3 Warum das rechtlich geht

Die Reihenfolge und die Namen des klassischen Repertoires sind breit und
unabhängig publiziert (Pilatesology, Online Pilates Classes, Pilates Andrea u.a.
zeigen dieselbe Abfolge: Footwork → Hundred → Overhead → Coordination → Rowing →
Long Stretch Series → Stomach Massage → Short Box → Knee Stretches → Running →
Pelvic Lift). Einzelne Übungsnamen und eine Bewegungsabfolge sind keine
geschützten Werke.

„Pilates" selbst ist seit dem Urteil *Pilates, Inc. v. Current Concepts* (SDNY,
19.10.2000) in den USA eine **Gattungsbezeichnung** — das Gericht hielt fest,
dass sich eine Trainingsmethode nicht über den generischen Begriff monopolisieren
lässt. Das Urteil gilt für die USA und ist nicht eins zu eins auf die Schweiz
übertragbar; die Bezeichnung ist hier aber ebenso gebräuchlich.

**Finger weg von Markennamen der Ausbildungssysteme** — STOTT, BASI, Polestar,
Balanced Body und ähnliche sind geschützt. Beschreibt die Übungen generisch
(„Footwork Ferse", nicht „BASI Footwork Heels") und formuliert Anleitungen
selbst, statt sie aus einem Handbuch zu übernehmen.

---

## 4. Datenmodell

### 4.1 Übung: von einer Tabelle zu einer Modalität

Neue Spalten an `exercise` (alle `NULL`-fähig, Bestand bleibt gültig):

```sql
modality          VARCHAR(24)   -- 'fitness' | 'pilates_mat' | 'pilates_reformer'
                                --  | 'athletik' (Bestand) | 'cardio'
equipment         VARCHAR(48)   -- Vokabular aus RepDB, ergänzt um Pilates-Geräte
level             VARCHAR(16)   -- 'beginner' | 'intermediate' | 'advanced'
instructions_de   TEXT          -- Ausführung, Schritt für Schritt
cues_de           TEXT          -- Ansagen für den Trainer („Rippen schliessen")
breathing_de      VARCHAR(190)  -- Atemführung — bei Pilates Teil der Übung
tempo             VARCHAR(16)   -- z.B. '3-1-1-0'
contraindications VARCHAR(255)  -- kodierte Schlüssel, s. 6.
is_unilateral     TINYINT(1)
met               DECIMAL(4,2)  -- Energieumsatz, für Kalorienschätzung
source            VARCHAR(32)   -- 'repdb' | 'free-exercise-db' | 'sihl'
source_ref        VARCHAR(120)  -- Fremd-ID, für spätere Aktualisierung
```

`source` und `source_ref` sind nicht Beiwerk: ohne sie lässt sich ein
Import später nicht noch einmal abgleichen, ohne eigene Ergänzungen zu
überschreiben.

### 4.2 Reformer: eigene Tabelle statt überladener Spalten

Eine Reformer-Übung hat Eigenschaften, die keine andere Modalität kennt. Die
gehören nicht als zehn leere Spalten an `exercise`, sondern daneben:

```sql
CREATE TABLE exercise_reformer (
  exercise_id      INT PRIMARY KEY,
  springs          VARCHAR(48),   -- '2 rot' / '1 rot + 1 blau' / 'federfrei'
  spring_load      DECIMAL(4,2),  -- normiert 0.0–5.0, für die Progression
  footbar          VARCHAR(16),   -- 'hoch' | 'tief' | 'unten'
  headrest         VARCHAR(16),   -- 'oben' | 'flach'
  carriage_start   VARCHAR(24),   -- 'geschlossen' | 'offen'
  attachment       VARCHAR(48),   -- 'lange Gurte' | 'kurze Gurte' | 'Box quer'
                                  --  | 'Box längs' | 'Jumpboard' | 'keines'
  position         VARCHAR(32),   -- 'Rückenlage' | 'Sitz' | 'Knien' | 'Stand'
  classical_order  INT,           -- Platz in der klassischen Reihenfolge
  CONSTRAINT fk_reformer_exercise FOREIGN KEY (exercise_id)
    REFERENCES exercise(id) ON DELETE CASCADE
);
```

**Warum `springs` *und* `spring_load`:** Der Trainer denkt in Farben, und die
Farben unterscheiden sich je Hersteller (Balanced Body, Gratz, Merrithew haben
verschiedene Federstärken). Der Generator dagegen muss rechnen können — „eine
Stufe leichter" — und das geht nur auf einer normierten Skala. Die Farbe ist die
Anzeige, die Zahl die Logik. Welche Farbskala euer Studio fährt, gehört in die
Studio-Einstellungen, nicht an die Übung.

### 4.3 Planzeile

`AiPlanRow` bekommt optionale Felder, die nur bei Reformer gefüllt sind:

```ts
springs?: string;      // Anzeige: '1 rot + 1 blau'
footbar?: string;
attachment?: string;
breathing?: string;    // '5 ein / 5 aus'
tempo?: string;
```

`weight` bleibt für Fitness, `springs` tritt bei Reformer an seine Stelle. Die
Trainer-App zeigt je Modalität die passende Spalte — die iOS-Planzeile hat heute
vier Felder (Übung, Sätze, Gewicht, Gerät); daraus werden bei Reformer
Übung, Wiederholungen, Federn, Zusatz.

---

## 5. Programmstruktur: vier Abschnitte passen nicht überall

Heute fest: `sonsomo → main → core → mobility`. Für Athletik richtig, für die
neuen Welten falsch.

| Modalität | Abschnitte |
|---|---|
| Athletik (Bestand) | Sonsomo · Main · Core · Mobility |
| **Fitness/Kraft** | Aufwärmen · Hauptteil (Split oder Ganzkörper) · Core · Ausklang |
| **Pilates Matte** | Vorbereitung · Serie (klassische Reihenfolge) · Ausklang |
| **Reformer** | Footwork · Core · Zug/Arme · Bein-/Fussarbeit · Abschluss |

**Vorschlag:** Die vier Schlüssel bleiben technisch bestehen — sie stecken an 33
Stellen im Code, und eine Umbenennung wäre reines Risiko ohne fachlichen Gewinn.
Stattdessen bekommt der Plan ein Feld `modality`, und je Modalität wird eine
**Beschriftung** auf die vier Slots gelegt:

```ts
const SECTION_LABELS: Record<Modality, Record<PlanSection, string>> = {
  reformer: { sonsomo: 'Footwork', main: 'Zug & Arme',
              core: 'Core & Bauch', mobility: 'Abschluss' },
  // …
};
```

Das ist ehrlich eine Krücke — vier Slots sind für Pilates knapp. Aber es hält
Backend, App und die bestehenden Pläne kompatibel. Wenn sich in der Praxis
zeigt, dass fünf oder sechs Abschnitte gebraucht werden, ist der Umbau auf eine
Liste von Abschnitten ein eigener, sauber abgrenzbarer Schritt.

---

## 6. Sicherheit: Kontraindikationen aus der Anamnese

Der Generator liest die Anamnese bereits aus. Das wird bei Pilates **wichtiger**,
weil einzelne Übungen bei bestimmten Befunden klar abzuraten sind:

| Befund (Anamnese-Feld) | Gesperrt |
|---|---|
| `injury` + LWS / Bandscheibe | Roll Over, Jackknife, Short Spine, Teaser, alles mit starker Flexion unter Last |
| Osteoporose (`disease_*`, Freitext) | Flexion der Wirbelsäule gegen Widerstand, Roll Up, Säge |
| Schwangerschaft | Bauchlage, starke Flexion, Rückenlage ab 2. Trimester |
| `disease_heart_circulatory` | Inversionen (Short Spine, Long Spine, Headstands) |
| Schulterproblematik | Pull Straps, Backstroke, Overhead |
| Bluthochdruck | Inversionen, langes Halten über Kopf |

Umgesetzt als Schlüsselmenge an der Übung (`contraindications`) und ein Filter
**vor** dem LLM-Aufruf: gesperrte Übungen kommen gar nicht erst in den Katalog,
der in den Prompt geht. Ein Modell, das eine verbotene Übung nicht kennt, kann
sie auch nicht vorschlagen — das ist verlässlicher, als sie ihm zu verbieten.

---

## 7. Generierung: Regelwerk zuerst, Modell danach

Die heutige Architektur ist richtig: Regelwerk als Rückfall, LLM für die
Auswahl. Für die neuen Modalitäten verschiebt sich das Gewicht.

**Deterministisch (Code, kein LLM):**
- Auswahl der zulässigen Übungen (Kontraindikationen, Level, vorhandenes Gerät)
- Anzahl Übungen je Abschnitt aus der Dauer (`DURATION_MAPPING` existiert)
- Federprogression: eine Stufe leichter/schwerer gegenüber dem Vorplan
- Reihenfolge bei Reformer: `classical_order` sortiert, nicht das Modell
- Satz-/Wiederholungsschema aus dem Trainingsziel (Kraft 3–5×3–6, Hypertrophie
  3–4×8–12, Kraftausdauer 2–3×15–25)

**LLM:**
- Welche Übungen zum Kunden passen — Schwächen aus dem Test, Ziele, Abwechslung
  gegenüber den letzten Plänen
- Begründung im Klartext (`ai_reasoning`), die der Trainer prüfen kann
- Cues und Betonung je Kunde

**Warum die Reihenfolge nicht das Modell macht:** Die klassische Abfolge ist
nicht Geschmackssache, sondern Aufbau — Footwork wärmt die Beine und die
Federspannung ein, bevor Zugarbeit kommt. Ein Sprachmodell würfelt das bei jeder
zweiten Generierung anders. Sortieren kostet drei Zeilen Code und ist danach
immer richtig.

---

## 8. Import-Pipeline

Ein Einmal-Skript reicht nicht — die Quellen aktualisieren sich, und eure eigenen
Ergänzungen dürfen dabei nicht verloren gehen.

```
nestjs-backend/src/exercise/import/
├── domain/            # Normalisierung, Zuordnung, Dubletten — reine Logik
│   ├── exercise-mapping.ts       # Fremdschema → unser Schema
│   ├── duplicate-detection.ts    # Namensähnlichkeit + Muskel/Gerät
│   └── modality-classifier.ts    # Kategorie/Tags → modality
├── application/       # Use Cases + Ports
│   ├── import-catalog.usecase.ts
│   └── ports.ts                  # CatalogSource, ExerciseRepository
├── adapter/           # je Quelle ein Adapter, sonst nichts
│   ├── repdb.source.ts
│   └── free-exercise-db.source.ts
└── interface/
    └── import.command.ts         # CLI / Admin-Endpunkt, liest die Config
```

Das folgt der Schichtung, die du im Projekt sihl-lab verlangt hast:
Abhängigkeiten zeigen nur nach innen, `domain/` kennt weder HTTP noch TypeORM,
und die Konfiguration (Quell-URLs, Attributionstext) wird ausschliesslich an der
Composition Root gelesen und hineingereicht. Ein Architektur-Test hält das fest.

**Dublettenerkennung** ist der heikle Teil: 601 + 876 Übungen überschneiden sich
stark, und eure 148 bestehenden sollen erhalten bleiben. Regel: Treffer über
normalisierten Namen **und** übereinstimmende Muskelgruppe gilt als Dublette;
bestehende Einträge gewinnen immer, Importe füllen nur leere Felder.

---

## 9. Reformer-Repertoire selbst aufbauen

Der Umfang ist überschaubar: rund **60 bis 80 Übungen** decken Basic bis
Intermediate ab, inklusive der gängigen Varianten.

**Vorgehen:**
1. Gerüst aus der klassischen Reihenfolge anlegen — Name, `classical_order`,
   Level, Position, Zusatz (Box, Gurte). Das ist eine Tabelle, keine Software:
   eine CSV, die im Studio ausgefüllt wird.
2. Federangaben je Übung eintragen — **eure** Federfarben, nicht die aus einem
   Buch. Sie hängen am Gerät im Studio.
3. Anleitung, Cues und Atmung selbst formulieren. Hier lohnt ein LLM als
   Entwurfshilfe, aber die fachliche Abnahme macht eine Pilates-Ausbildnerin.
4. Kontraindikationen je Übung setzen (s. 6.) — das ist der sicherheitsrelevante
   Teil und gehört fachlich abgenommen.
5. Bilder: Strichzeichnungen im bestehenden Stil
   (`docs/exercise-line-art-prompts.md` gibt es schon).

**Aufwand realistisch:** Schritte 1 und 2 an einem Nachmittag im Studio, Schritt
3 und 4 verteilt über zwei bis drei Sitzungen. Das ist der Teil, den keine
Software abkürzt — und zugleich der, der euch von jeder App unterscheidet, die
nur einen offenen Datensatz einliest.

---

## 10. Umsetzung in Etappen

| Etappe | Inhalt | Ergebnis |
|---|---|---|
| **1** | Datenmodell: Spalten an `exercise`, Tabelle `exercise_reformer`, `modality` am Plan | Migration, nichts sichtbar |
| **2** | Import-Pipeline + RepDB-Import (nur `modality='fitness'`) | Katalog wächst auf ~700, deutsch |
| **3** | Generator: Modalität als Auswahl, Fitness-Periodisierung, Kontraindikationsfilter | Kraftpläne mit Geräten |
| **4** | Reformer-Repertoire erfassen (Studio) + Matten-Übungen aus RepDB | Pilates-Katalog steht |
| **5** | Generator: Reformer-Logik — Reihenfolge, Federprogression, Atmung | Reformer-Pläne |
| **6** | Trainer-App: Modalitätswahl, Federspalte, Cues in der Planansicht | sichtbar für den Trainer |
| **7** | Client-App: Pläne mit Federangaben und Atmung anzeigen | sichtbar für den Kunden |

Etappen 1–3 sind reine Softwarearbeit und unabhängig vom Studio. Etappe 4 ist
die Voraussetzung für 5 — ohne Repertoire kein Reformer-Generator.

---

## 11. Offene Entscheidungen

1. **RepDB-Attribution** — ein sichtbarer Link „Exercise data by RepDB" im
   Impressum der Apps. Akzeptabel, oder lieber ausschliesslich free-exercise-db
   und die 876 englischen Einträge selbst übersetzen lassen?
2. **Federfarben** — welches Fabrikat steht im Studio? Davon hängt die Skala ab.
3. **Matten-Pilates** — eigene Modalität oder zusammen mit Reformer unter
   „Pilates" mit Gerätefeld?
4. **Vier Abschnitte** — reicht die Beschriftungslösung aus 5., oder soll der
   Plan von Beginn an auf eine freie Abschnittsliste umgebaut werden?
5. **Fachliche Abnahme** — wer zeichnet die Kontraindikationen ab? Das ist der
   einzige Teil des Konzepts, bei dem ein Fehler jemandem schaden kann.

---

## Quellen

- [RepDB exercise-dataset](https://github.com/RepDB/exercise-dataset) — 601 Übungen, DE/EN/ES
- [free-exercise-db](https://github.com/yuhonas/free-exercise-db) — 876 Übungen, Unlicense
- [wger](https://github.com/wger-project/wger) — AGPL-3, Daten CC-BY-SA 3.0
- [exercises-dataset](https://github.com/hasaneyldrm/exercises-dataset) — Medien © Gym visual
- [neenan/pilates-workouts](https://github.com/neenan/pilates-workouts) — Reformer mit Federn, ohne Lizenz
- [Online Pilates Classes: Full Reformer Order](https://onlinepilatesclasses.com/blog/full-pilates-reformer-order-and-tutorial/)
- [Pilatesology: Classical Reformer Order & Spring Settings](https://pilatesology.com/wp-content/uploads/2020/08/Reformer-Basic-Order-Spring-Settings.pdf)
- [Pilates, Inc. v. Current Concepts (SDNY 2000)](https://www.courtlistener.com/opinion/2499620/pilates-inc-v-current-concepts-inc/)
