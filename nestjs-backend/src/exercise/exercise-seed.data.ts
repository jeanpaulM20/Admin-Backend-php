// ─────────────────────────────────────────────────────────────────────────────
// Sportwissenschaftliche Übungsdatenbank — 10 Kernbereiche
// Ganzheitlich, funktionell, Fokus auf Sensomotorik, Sehnen & Mobilität
// Jede Übung mit anatomischen Metadaten für KI-gestützte Planauswahl
// ─────────────────────────────────────────────────────────────────────────────

export type BodyRegion = 'UpperBody' | 'LowerBody' | 'Core' | 'FullBody' | 'Foot';
export type MovementPattern = 'Push' | 'Pull' | 'Squat' | 'Hinge' | 'Carry' | 'Rotation' | 'Static' | 'Plyo' | 'Sprint' | 'Agility';

export interface SeedExercise {
  name: string;
  subgroup?: string;
  body_region: BodyRegion;
  primary_muscle_group: string;
  target_joint: string;
  movement_pattern: MovementPattern;
}

export interface SeedCategory {
  group: string;
  subgroups: string[];
  exercises: SeedExercise[];
}

export const EXERCISE_SEED_DATA: SeedCategory[] = [
  // ═══════════════════════════════════════════════════════════════════════════
  // 1. Fußmuskulatur & Barfuß-Training
  // ═══════════════════════════════════════════════════════════════════════════
  {
    group: 'Fußmuskulatur & Barfuß-Training',
    subgroups: [
      'Intrinsische Fußmuskulatur',
      'Propriozeption Fuß',
      'Barfuß-Kräftigung',
      'Barfuß-Laufen',
    ],
    exercises: [
      // Intrinsische Fußmuskulatur
      { name: 'Short Foot Exercise (Kurzfuß nach Janda)', subgroup: 'Intrinsische Fußmuskulatur', body_region: 'Foot', primary_muscle_group: 'Fußmuskulatur intrinsisch', target_joint: 'Sprunggelenk', movement_pattern: 'Static' },
      { name: 'Zehenklavier (isolierte Zehenkontrolle)', subgroup: 'Intrinsische Fußmuskulatur', body_region: 'Foot', primary_muscle_group: 'Fußmuskulatur intrinsisch', target_joint: 'Sprunggelenk', movement_pattern: 'Static' },
      { name: 'Towel Scrunch (Handtuch-Raffen)', subgroup: 'Intrinsische Fußmuskulatur', body_region: 'Foot', primary_muscle_group: 'Fußmuskulatur intrinsisch', target_joint: 'Sprunggelenk', movement_pattern: 'Pull' },
      { name: 'Marble Pickup (Murmelgreifen mit Zehen)', subgroup: 'Intrinsische Fußmuskulatur', body_region: 'Foot', primary_muscle_group: 'Fußmuskulatur intrinsisch', target_joint: 'Sprunggelenk', movement_pattern: 'Pull' },
      { name: 'Arch Doming (Fußgewölbe-Aktivierung)', subgroup: 'Intrinsische Fußmuskulatur', body_region: 'Foot', primary_muscle_group: 'Fußmuskulatur intrinsisch', target_joint: 'Sprunggelenk', movement_pattern: 'Static' },
      { name: 'Big Toe Extension mit Widerstandsband', subgroup: 'Intrinsische Fußmuskulatur', body_region: 'Foot', primary_muscle_group: 'Fußmuskulatur intrinsisch', target_joint: 'Sprunggelenk', movement_pattern: 'Push' },
      { name: 'Toe Yoga (Großzeh heben / Kleinzehen heben)', subgroup: 'Intrinsische Fußmuskulatur', body_region: 'Foot', primary_muscle_group: 'Fußmuskulatur intrinsisch', target_joint: 'Sprunggelenk', movement_pattern: 'Static' },
      { name: 'Zehen-Spreizen & Kontrahieren (aktiv)', subgroup: 'Intrinsische Fußmuskulatur', body_region: 'Foot', primary_muscle_group: 'Fußmuskulatur intrinsisch', target_joint: 'Sprunggelenk', movement_pattern: 'Static' },

      // Propriozeption Fuß
      { name: 'Einbeinstand auf instabilem Untergrund', subgroup: 'Propriozeption Fuß', body_region: 'Foot', primary_muscle_group: 'Fußmuskulatur intrinsisch', target_joint: 'Sprunggelenk', movement_pattern: 'Static' },
      { name: 'Barfuß-Gehen über Sensorik-Pfad', subgroup: 'Propriozeption Fuß', body_region: 'Foot', primary_muscle_group: 'Fußmuskulatur intrinsisch', target_joint: 'Sprunggelenk', movement_pattern: 'Static' },
      { name: 'Einbeinstand Augen geschlossen (30s+)', subgroup: 'Propriozeption Fuß', body_region: 'Foot', primary_muscle_group: 'Fußmuskulatur intrinsisch', target_joint: 'Sprunggelenk', movement_pattern: 'Static' },
      { name: 'Tandemstand auf weichem Untergrund', subgroup: 'Propriozeption Fuß', body_region: 'Foot', primary_muscle_group: 'Fußmuskulatur intrinsisch', target_joint: 'Sprunggelenk', movement_pattern: 'Static' },

      // Barfuß-Kräftigung
      { name: 'Heel Walk / Toe Walk (Fersen-/Zehengang)', subgroup: 'Barfuß-Kräftigung', body_region: 'Foot', primary_muscle_group: 'Wade / Tibialis anterior', target_joint: 'Sprunggelenk', movement_pattern: 'Push' },
      { name: 'Calf-Raise einbeinig barfuß (langsam exzentrisch)', subgroup: 'Barfuß-Kräftigung', body_region: 'Foot', primary_muscle_group: 'Wade', target_joint: 'Sprunggelenk', movement_pattern: 'Push' },
      { name: 'Lateral Walk barfuß (Außenkante)', subgroup: 'Barfuß-Kräftigung', body_region: 'Foot', primary_muscle_group: 'Peroneus / Fußmuskulatur', target_joint: 'Sprunggelenk', movement_pattern: 'Static' },
      { name: 'Barfuß-Treppengehen (kontrolliert exzentrisch)', subgroup: 'Barfuß-Kräftigung', body_region: 'Foot', primary_muscle_group: 'Wade / Quadriceps', target_joint: 'Sprunggelenk', movement_pattern: 'Squat' },

      // Barfuß-Laufen
      { name: 'Barfuß-Lauf auf Rasen (Technikfokus Vorfuß)', subgroup: 'Barfuß-Laufen', body_region: 'Foot', primary_muscle_group: 'Wade / Fußmuskulatur', target_joint: 'Sprunggelenk', movement_pattern: 'Sprint' },
      { name: 'Barfuß-Lauf-ABC (Skipping, Kniehebelauf)', subgroup: 'Barfuß-Laufen', body_region: 'Foot', primary_muscle_group: 'Hüftbeuger / Wade', target_joint: 'Knie', movement_pattern: 'Sprint' },
      { name: 'Barfuß-Steigerungsläufe (50m progressiv)', subgroup: 'Barfuß-Laufen', body_region: 'Foot', primary_muscle_group: 'Gluteus / Quadriceps / Wade', target_joint: 'Knie', movement_pattern: 'Sprint' },
      { name: 'Barfuß Trail-Walking (Waldboden, Kiesel)', subgroup: 'Barfuß-Laufen', body_region: 'Foot', primary_muscle_group: 'Fußmuskulatur intrinsisch', target_joint: 'Sprunggelenk', movement_pattern: 'Static' },
      { name: 'Barfuß-Rückwärtslaufen (Propriozeption)', subgroup: 'Barfuß-Laufen', body_region: 'Foot', primary_muscle_group: 'Quadriceps / Wade', target_joint: 'Knie', movement_pattern: 'Sprint' },
    ],
  },

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. Ausdauer (funktional & intervallbasiert)
  // ═══════════════════════════════════════════════════════════════════════════
  {
    group: 'Ausdauer & Intervalltraining',
    subgroups: ['Lauf-Intervalle', 'Funktionelle Ausdauer', 'Zirkeltraining'],
    exercises: [
      // Lauf-Intervalle
      { name: 'Tabata Sprints (20s on / 10s off)', subgroup: 'Lauf-Intervalle', body_region: 'FullBody', primary_muscle_group: 'Gluteus / Quadriceps', target_joint: 'Knie', movement_pattern: 'Sprint' },
      { name: 'Hill Repeats (Hügelsprints)', subgroup: 'Lauf-Intervalle', body_region: 'LowerBody', primary_muscle_group: 'Gluteus / Quadriceps', target_joint: 'Knie', movement_pattern: 'Sprint' },
      { name: 'Tempo Run (Schwellentraining)', subgroup: 'Lauf-Intervalle', body_region: 'FullBody', primary_muscle_group: 'Gluteus / Quadriceps', target_joint: 'Knie', movement_pattern: 'Sprint' },
      { name: 'Fartlek-Lauf (Fahrtspiel)', subgroup: 'Lauf-Intervalle', body_region: 'FullBody', primary_muscle_group: 'Gluteus / Quadriceps', target_joint: 'Knie', movement_pattern: 'Sprint' },
      { name: '400m Intervalle (VO2max-Training)', subgroup: 'Lauf-Intervalle', body_region: 'FullBody', primary_muscle_group: 'Gluteus / Quadriceps', target_joint: 'Knie', movement_pattern: 'Sprint' },

      // Funktionelle Ausdauer
      { name: 'Burpee-Intervalle (EMOM)', subgroup: 'Funktionelle Ausdauer', body_region: 'FullBody', primary_muscle_group: 'Brust / Quadriceps / Schulter', target_joint: 'Schulter', movement_pattern: 'Push' },
      { name: 'Seilspringen (Double Unders)', subgroup: 'Funktionelle Ausdauer', body_region: 'FullBody', primary_muscle_group: 'Wade / Schulter', target_joint: 'Sprunggelenk', movement_pattern: 'Plyo' },
      { name: 'Ruderergometer Intervalle (500m Repeats)', subgroup: 'Funktionelle Ausdauer', body_region: 'FullBody', primary_muscle_group: 'Oberer Rücken / Quadriceps', target_joint: 'Knie', movement_pattern: 'Pull' },
      { name: 'Assault Bike Sprint-Intervalle', subgroup: 'Funktionelle Ausdauer', body_region: 'FullBody', primary_muscle_group: 'Quadriceps / Schulter', target_joint: 'Knie', movement_pattern: 'Push' },

      // Zirkeltraining
      { name: 'Bear Crawl + Sprint Kombi', subgroup: 'Zirkeltraining', body_region: 'FullBody', primary_muscle_group: 'Schulter / Core / Quadriceps', target_joint: 'Schulter', movement_pattern: 'Push' },
      { name: 'Kettlebell Swing AMRAP (5 Min.)', subgroup: 'Zirkeltraining', body_region: 'FullBody', primary_muscle_group: 'Gluteus / Hamstrings', target_joint: 'Hüfte', movement_pattern: 'Hinge' },
      { name: 'Funktioneller 5er-Zirkel (Push/Pull/Hinge/Squat/Carry)', subgroup: 'Zirkeltraining', body_region: 'FullBody', primary_muscle_group: 'Ganzkörper', target_joint: 'Hüfte', movement_pattern: 'Hinge' },
    ],
  },

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. Ring- & Suspension-Training
  // ═══════════════════════════════════════════════════════════════════════════
  {
    group: 'Ring- & Suspension-Training',
    subgroups: ['Ring-Grundlagen', 'Ring-Kraft', 'TRX / Schlingen'],
    exercises: [
      // Ring-Grundlagen
      { name: 'Ring Support Hold (Stütz-Halten)', subgroup: 'Ring-Grundlagen', body_region: 'UpperBody', primary_muscle_group: 'Brust / Trizeps / Schulter', target_joint: 'Schulter', movement_pattern: 'Static' },
      { name: 'Ring Rows (Rudern an Ringen)', subgroup: 'Ring-Grundlagen', body_region: 'UpperBody', primary_muscle_group: 'Oberer Rücken / Bizeps', target_joint: 'Schulter', movement_pattern: 'Pull' },
      { name: 'Ring Push-Ups (Liegestütz an Ringen)', subgroup: 'Ring-Grundlagen', body_region: 'UpperBody', primary_muscle_group: 'Brust / Trizeps', target_joint: 'Schulter', movement_pattern: 'Push' },
      { name: 'Ring Turned-Out Support (RTO Hold)', subgroup: 'Ring-Grundlagen', body_region: 'UpperBody', primary_muscle_group: 'Brust / Bizeps / Schulter', target_joint: 'Schulter', movement_pattern: 'Static' },

      // Ring-Kraft
      { name: 'Ring Dips', subgroup: 'Ring-Kraft', body_region: 'UpperBody', primary_muscle_group: 'Brust / Trizeps', target_joint: 'Schulter', movement_pattern: 'Push' },
      { name: 'Ring Muscle-Up (Progression)', subgroup: 'Ring-Kraft', body_region: 'UpperBody', primary_muscle_group: 'Latissimus / Brust / Trizeps', target_joint: 'Schulter', movement_pattern: 'Pull' },
      { name: 'Ring Face Pull', subgroup: 'Ring-Kraft', body_region: 'UpperBody', primary_muscle_group: 'Hintere Schulter / Rotatorenmanschette', target_joint: 'Schulter', movement_pattern: 'Pull' },
      { name: 'Skin the Cat (Felgaufschwung rückwärts)', subgroup: 'Ring-Kraft', body_region: 'UpperBody', primary_muscle_group: 'Latissimus / Schulter', target_joint: 'Schulter', movement_pattern: 'Pull' },
      { name: 'Ring L-Sit Hold', subgroup: 'Ring-Kraft', body_region: 'Core', primary_muscle_group: 'Hüftbeuger / Bauchmuskulatur', target_joint: 'Hüfte', movement_pattern: 'Static' },
      { name: 'Ring Bulgarian Dips (tief)', subgroup: 'Ring-Kraft', body_region: 'UpperBody', primary_muscle_group: 'Brust / Trizeps / Schulter', target_joint: 'Schulter', movement_pattern: 'Push' },

      // TRX / Schlingen
      { name: 'TRX Body Saw (Schlingentrainer)', subgroup: 'TRX / Schlingen', body_region: 'Core', primary_muscle_group: 'Bauchmuskulatur / Schulter', target_joint: 'LWS', movement_pattern: 'Static' },
      { name: 'TRX Einbein-Squat (Pistol Assist)', subgroup: 'TRX / Schlingen', body_region: 'LowerBody', primary_muscle_group: 'Quadriceps / Gluteus', target_joint: 'Knie', movement_pattern: 'Squat' },
      { name: 'TRX Y-T-W Schulteraktivierung', subgroup: 'TRX / Schlingen', body_region: 'UpperBody', primary_muscle_group: 'Hintere Schulter / Rotatorenmanschette', target_joint: 'Schulter', movement_pattern: 'Pull' },
      { name: 'TRX Hamstring Curl (einbeinig)', subgroup: 'TRX / Schlingen', body_region: 'LowerBody', primary_muscle_group: 'Hamstrings', target_joint: 'Knie', movement_pattern: 'Pull' },
    ],
  },

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. Kettlebell-Training
  // ═══════════════════════════════════════════════════════════════════════════
  {
    group: 'Kettlebell-Training',
    subgroups: ['Ballistische Übungen', 'Grinds (langsame Kraft)', 'Komplexe & Flows'],
    exercises: [
      // Ballistische Übungen
      { name: 'Kettlebell Swing (Russian)', subgroup: 'Ballistische Übungen', body_region: 'FullBody', primary_muscle_group: 'Gluteus / Hamstrings', target_joint: 'Hüfte', movement_pattern: 'Hinge' },
      { name: 'Kettlebell Snatch', subgroup: 'Ballistische Übungen', body_region: 'FullBody', primary_muscle_group: 'Gluteus / Schulter / Hamstrings', target_joint: 'Hüfte', movement_pattern: 'Hinge' },
      { name: 'Kettlebell Clean', subgroup: 'Ballistische Übungen', body_region: 'FullBody', primary_muscle_group: 'Gluteus / Hamstrings / Unterarm', target_joint: 'Hüfte', movement_pattern: 'Hinge' },
      { name: 'Kettlebell Clean & Press', subgroup: 'Ballistische Übungen', body_region: 'FullBody', primary_muscle_group: 'Schulter / Gluteus / Trizeps', target_joint: 'Schulter', movement_pattern: 'Push' },
      { name: 'Kettlebell High Pull', subgroup: 'Ballistische Übungen', body_region: 'FullBody', primary_muscle_group: 'Oberer Rücken / Gluteus', target_joint: 'Schulter', movement_pattern: 'Pull' },

      // Grinds
      { name: 'Turkish Get-Up', subgroup: 'Grinds (langsame Kraft)', body_region: 'FullBody', primary_muscle_group: 'Schulter / Core / Gluteus', target_joint: 'Schulter', movement_pattern: 'Push' },
      { name: 'Kettlebell Goblet Squat', subgroup: 'Grinds (langsame Kraft)', body_region: 'LowerBody', primary_muscle_group: 'Quadriceps / Gluteus', target_joint: 'Knie', movement_pattern: 'Squat' },
      { name: 'Kettlebell Windmill', subgroup: 'Grinds (langsame Kraft)', body_region: 'FullBody', primary_muscle_group: 'Seitliche Bauchmuskulatur / Schulter', target_joint: 'Hüfte', movement_pattern: 'Rotation' },
      { name: 'Kettlebell Single-Leg Deadlift', subgroup: 'Grinds (langsame Kraft)', body_region: 'LowerBody', primary_muscle_group: 'Hamstrings / Gluteus', target_joint: 'Hüfte', movement_pattern: 'Hinge' },
      { name: 'Kettlebell Bottom-Up Press (Stabilität)', subgroup: 'Grinds (langsame Kraft)', body_region: 'UpperBody', primary_muscle_group: 'Schulter / Unterarm', target_joint: 'Schulter', movement_pattern: 'Push' },
      { name: 'Double Kettlebell Front Squat', subgroup: 'Grinds (langsame Kraft)', body_region: 'LowerBody', primary_muscle_group: 'Quadriceps / Gluteus / Core', target_joint: 'Knie', movement_pattern: 'Squat' },
      { name: 'Kettlebell Bent Press', subgroup: 'Grinds (langsame Kraft)', body_region: 'FullBody', primary_muscle_group: 'Schulter / Seitliche Bauchmuskulatur', target_joint: 'Schulter', movement_pattern: 'Push' },

      // Flows
      { name: 'Kettlebell Halo', subgroup: 'Komplexe & Flows', body_region: 'UpperBody', primary_muscle_group: 'Schulter / Rotatorenmanschette', target_joint: 'Schulter', movement_pattern: 'Rotation' },
      { name: 'Kettlebell Flow (Swing-Clean-Press-Squat)', subgroup: 'Komplexe & Flows', body_region: 'FullBody', primary_muscle_group: 'Ganzkörper', target_joint: 'Hüfte', movement_pattern: 'Hinge' },
      { name: 'Kettlebell Armor Building Complex (2x Clean-Press-Squat)', subgroup: 'Komplexe & Flows', body_region: 'FullBody', primary_muscle_group: 'Ganzkörper', target_joint: 'Hüfte', movement_pattern: 'Hinge' },
    ],
  },

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. Exzentrisches Training (Sehnen-Prehab & Hypertrophie)
  // ═══════════════════════════════════════════════════════════════════════════
  {
    group: 'Exzentrisches Training',
    subgroups: ['Untere Extremität', 'Obere Extremität', 'Sehnen-Prehab'],
    exercises: [
      // Sehnen-Prehab
      { name: 'Exzentrische Calf Raises (Alfredson-Protokoll)', subgroup: 'Sehnen-Prehab', body_region: 'LowerBody', primary_muscle_group: 'Wade', target_joint: 'Sprunggelenk', movement_pattern: 'Push' },
      { name: 'Exzentrische Spanish Squats (Patellasehne)', subgroup: 'Sehnen-Prehab', body_region: 'LowerBody', primary_muscle_group: 'Quadriceps', target_joint: 'Knie', movement_pattern: 'Squat' },
      { name: 'Exzentrische Wrist Curls (Tennisarm-Prehab)', subgroup: 'Sehnen-Prehab', body_region: 'UpperBody', primary_muscle_group: 'Unterarm-Extensoren', target_joint: 'Ellenbogen', movement_pattern: 'Pull' },
      { name: 'Isometric-Eccentric Combo Wandsitzen', subgroup: 'Sehnen-Prehab', body_region: 'LowerBody', primary_muscle_group: 'Quadriceps', target_joint: 'Knie', movement_pattern: 'Static' },
      { name: 'Exzentrische Plantarfaszie-Übung (Towel Stretch)', subgroup: 'Sehnen-Prehab', body_region: 'Foot', primary_muscle_group: 'Plantarfaszie / Wade', target_joint: 'Sprunggelenk', movement_pattern: 'Static' },

      // Untere Extremität
      { name: 'Exzentrische Nordic Hamstring Curls', subgroup: 'Untere Extremität', body_region: 'LowerBody', primary_muscle_group: 'Hamstrings', target_joint: 'Knie', movement_pattern: 'Pull' },
      { name: 'Exzentrische Single-Leg Squat (5s negativ)', subgroup: 'Untere Extremität', body_region: 'LowerBody', primary_muscle_group: 'Quadriceps / Gluteus', target_joint: 'Knie', movement_pattern: 'Squat' },
      { name: 'Tempo Squat (4-0-2-0 Kadenz)', subgroup: 'Untere Extremität', body_region: 'LowerBody', primary_muscle_group: 'Quadriceps / Gluteus', target_joint: 'Knie', movement_pattern: 'Squat' },
      { name: 'Exzentrische Step-Downs (3s negativ)', subgroup: 'Untere Extremität', body_region: 'LowerBody', primary_muscle_group: 'Quadriceps', target_joint: 'Knie', movement_pattern: 'Squat' },
      { name: 'Exzentrische Bulgarian Split Squat (4s TUT)', subgroup: 'Untere Extremität', body_region: 'LowerBody', primary_muscle_group: 'Quadriceps / Gluteus', target_joint: 'Knie', movement_pattern: 'Squat' },

      // Obere Extremität
      { name: 'Exzentrische Klimmzüge (5s Absenkphase)', subgroup: 'Obere Extremität', body_region: 'UpperBody', primary_muscle_group: 'Latissimus / Bizeps', target_joint: 'Schulter', movement_pattern: 'Pull' },
      { name: 'Exzentrische Push-Ups (5s negativ)', subgroup: 'Obere Extremität', body_region: 'UpperBody', primary_muscle_group: 'Brust / Trizeps', target_joint: 'Schulter', movement_pattern: 'Push' },
      { name: 'Slow Eccentric Ring Row (4s negativ)', subgroup: 'Obere Extremität', body_region: 'UpperBody', primary_muscle_group: 'Oberer Rücken / Bizeps', target_joint: 'Schulter', movement_pattern: 'Pull' },
      { name: 'Exzentrische Dips (5s Absenkphase)', subgroup: 'Obere Extremität', body_region: 'UpperBody', primary_muscle_group: 'Brust / Trizeps', target_joint: 'Schulter', movement_pattern: 'Push' },
    ],
  },

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. Eigenkörpergewicht (Calisthenics)
  // ═══════════════════════════════════════════════════════════════════════════
  {
    group: 'Eigenkörpergewicht / Calisthenics',
    subgroups: ['Drückend', 'Ziehend', 'Beine & Hüfte', 'Ganzkörper'],
    exercises: [
      // Drückend
      { name: 'Handstand an der Wand (Aufbau)', subgroup: 'Drückend', body_region: 'UpperBody', primary_muscle_group: 'Schulter / Trizeps', target_joint: 'Schulter', movement_pattern: 'Push' },
      { name: 'Pseudo Planche Push-Up', subgroup: 'Drückend', body_region: 'UpperBody', primary_muscle_group: 'Brust / Vordere Schulter', target_joint: 'Schulter', movement_pattern: 'Push' },
      { name: 'Pike Push-Up (Schulterdrücken)', subgroup: 'Drückend', body_region: 'UpperBody', primary_muscle_group: 'Schulter / Trizeps', target_joint: 'Schulter', movement_pattern: 'Push' },
      { name: 'Planche Lean', subgroup: 'Drückend', body_region: 'UpperBody', primary_muscle_group: 'Vordere Schulter / Brust', target_joint: 'Schulter', movement_pattern: 'Static' },
      { name: 'Diamond Push-Up', subgroup: 'Drückend', body_region: 'UpperBody', primary_muscle_group: 'Trizeps / Brust', target_joint: 'Ellenbogen', movement_pattern: 'Push' },

      // Ziehend
      { name: 'Archer Pull-Up', subgroup: 'Ziehend', body_region: 'UpperBody', primary_muscle_group: 'Latissimus / Bizeps', target_joint: 'Schulter', movement_pattern: 'Pull' },
      { name: 'Front Lever Progression (Tuck)', subgroup: 'Ziehend', body_region: 'UpperBody', primary_muscle_group: 'Latissimus / Core', target_joint: 'Schulter', movement_pattern: 'Pull' },
      { name: 'Back Lever Progression (Tuck)', subgroup: 'Ziehend', body_region: 'UpperBody', primary_muscle_group: 'Vordere Schulter / Bizeps', target_joint: 'Schulter', movement_pattern: 'Static' },
      { name: 'Typewriter Pull-Up', subgroup: 'Ziehend', body_region: 'UpperBody', primary_muscle_group: 'Latissimus / Bizeps', target_joint: 'Schulter', movement_pattern: 'Pull' },

      // Beine & Hüfte
      { name: 'Pistol Squat (einbeinige Kniebeuge)', subgroup: 'Beine & Hüfte', body_region: 'LowerBody', primary_muscle_group: 'Quadriceps / Gluteus', target_joint: 'Knie', movement_pattern: 'Squat' },
      { name: 'Shrimp Squat (Garnelenkniebeuge)', subgroup: 'Beine & Hüfte', body_region: 'LowerBody', primary_muscle_group: 'Quadriceps / Gluteus', target_joint: 'Knie', movement_pattern: 'Squat' },
      { name: 'Natural Leg Extension (Sissy Squat)', subgroup: 'Beine & Hüfte', body_region: 'LowerBody', primary_muscle_group: 'Quadriceps', target_joint: 'Knie', movement_pattern: 'Squat' },

      // Ganzkörper
      { name: 'Hollow Body Hold', subgroup: 'Ganzkörper', body_region: 'Core', primary_muscle_group: 'Bauchmuskulatur', target_joint: 'LWS', movement_pattern: 'Static' },
      { name: 'Dragon Flag (Progression)', subgroup: 'Ganzkörper', body_region: 'Core', primary_muscle_group: 'Bauchmuskulatur / Hüftbeuger', target_joint: 'LWS', movement_pattern: 'Static' },
      { name: 'L-Sit Hold (am Boden oder Parallettes)', subgroup: 'Ganzkörper', body_region: 'Core', primary_muscle_group: 'Hüftbeuger / Bauchmuskulatur', target_joint: 'Hüfte', movement_pattern: 'Static' },
      { name: 'Human Flag Progression', subgroup: 'Ganzkörper', body_region: 'FullBody', primary_muscle_group: 'Seitliche Bauchmuskulatur / Latissimus / Schulter', target_joint: 'Schulter', movement_pattern: 'Static' },
    ],
  },

  // ═══════════════════════════════════════════════════════════════════════════
  // 7. Slackline (ehemals Klettern & Slackline)
  // ═══════════════════════════════════════════════════════════════════════════
  {
    group: 'Slackline',
    subgroups: ['Griffkraft', 'Scapula-Kontrolle', 'Körperspannung', 'Slackline'],
    exercises: [
      // Griffkraft
      { name: 'Dead Hang (Passivhang 60s+)', subgroup: 'Griffkraft', body_region: 'UpperBody', primary_muscle_group: 'Unterarm / Griffkraft', target_joint: 'Handgelenk', movement_pattern: 'Static' },
      { name: 'Fingerboard Repeaters (7:3 Protokoll)', subgroup: 'Griffkraft', body_region: 'UpperBody', primary_muscle_group: 'Unterarm / Fingerflexoren', target_joint: 'Handgelenk', movement_pattern: 'Static' },
      { name: 'Pinch Block Training (Daumen-Griffkraft)', subgroup: 'Griffkraft', body_region: 'UpperBody', primary_muscle_group: 'Unterarm / Daumenmuskulatur', target_joint: 'Handgelenk', movement_pattern: 'Static' },
      { name: 'Campus Board Touches (Schnellkraft)', subgroup: 'Griffkraft', body_region: 'UpperBody', primary_muscle_group: 'Latissimus / Unterarm', target_joint: 'Schulter', movement_pattern: 'Pull' },
      { name: 'Fat Grip Pull-Ups', subgroup: 'Griffkraft', body_region: 'UpperBody', primary_muscle_group: 'Latissimus / Unterarm / Bizeps', target_joint: 'Schulter', movement_pattern: 'Pull' },
      { name: 'Farmer\'s Walk (schwerer Griffkraft-Carry)', subgroup: 'Griffkraft', body_region: 'FullBody', primary_muscle_group: 'Unterarm / Trapezius / Core', target_joint: 'Handgelenk', movement_pattern: 'Carry' },

      // Scapula-Kontrolle
      { name: 'Active Hang (Schulterblatt-Aktivierung)', subgroup: 'Scapula-Kontrolle', body_region: 'UpperBody', primary_muscle_group: 'Unterer Trapezius / Serratus anterior', target_joint: 'Schulter', movement_pattern: 'Pull' },
      { name: 'Scapular Pull-Ups', subgroup: 'Scapula-Kontrolle', body_region: 'UpperBody', primary_muscle_group: 'Unterer Trapezius / Latissimus', target_joint: 'Schulter', movement_pattern: 'Pull' },
      { name: 'Scapula Push-Up (Protraktion/Retraktion)', subgroup: 'Scapula-Kontrolle', body_region: 'UpperBody', primary_muscle_group: 'Serratus anterior', target_joint: 'Schulter', movement_pattern: 'Push' },
      { name: 'Band Pull-Apart (Schulterblatt-Stabilität)', subgroup: 'Scapula-Kontrolle', body_region: 'UpperBody', primary_muscle_group: 'Hintere Schulter / Rhomboiden', target_joint: 'Schulter', movement_pattern: 'Pull' },

      // Körperspannung
      { name: 'Lock-Off Holds (90°, 120°, 150°)', subgroup: 'Körperspannung', body_region: 'UpperBody', primary_muscle_group: 'Bizeps / Latissimus', target_joint: 'Ellenbogen', movement_pattern: 'Static' },
      { name: 'Front Lever Raise (Körperspannung)', subgroup: 'Körperspannung', body_region: 'UpperBody', primary_muscle_group: 'Latissimus / Core', target_joint: 'Schulter', movement_pattern: 'Pull' },
      { name: 'Toe-to-Bar (Körperspannung + Kraft)', subgroup: 'Körperspannung', body_region: 'Core', primary_muscle_group: 'Bauchmuskulatur / Hüftbeuger', target_joint: 'Hüfte', movement_pattern: 'Pull' },

      // Slackline
      { name: 'Slackline Grundposition (Einbeinstand)', subgroup: 'Slackline', body_region: 'LowerBody', primary_muscle_group: 'Fußmuskulatur / Gluteus medius', target_joint: 'Sprunggelenk', movement_pattern: 'Static' },
      { name: 'Slackline Walking (vorwärts/rückwärts)', subgroup: 'Slackline', body_region: 'LowerBody', primary_muscle_group: 'Fußmuskulatur / Gluteus medius', target_joint: 'Sprunggelenk', movement_pattern: 'Static' },
      { name: 'Slackline Yoga Poses (Tree, Warrior)', subgroup: 'Slackline', body_region: 'FullBody', primary_muscle_group: 'Gluteus medius / Core', target_joint: 'Hüfte', movement_pattern: 'Static' },
      { name: 'Slackline Kniebeuge (einbeinig)', subgroup: 'Slackline', body_region: 'LowerBody', primary_muscle_group: 'Quadriceps / Gluteus', target_joint: 'Knie', movement_pattern: 'Squat' },
    ],
  },

  // ═══════════════════════════════════════════════════════════════════════════
  // 8. Propriozeption (ehemals Balance Board & Sensomotorik)
  // ═══════════════════════════════════════════════════════════════════════════
  {
    group: 'Propriozeption',
    subgroups: ['Gleichgewicht Grundlagen', 'Reaktive Stabilität', 'Propriozeptives Training', 'Sport-spezifisch'],
    exercises: [
      // Gleichgewicht Grundlagen
      { name: 'MFT Board beidbeinig (Kreiselbewegung)', subgroup: 'Gleichgewicht Grundlagen', body_region: 'LowerBody', primary_muscle_group: 'Fußmuskulatur / Wade', target_joint: 'Sprunggelenk', movement_pattern: 'Static' },
      { name: 'MFT Board einbeinig (Standstabilität)', subgroup: 'Gleichgewicht Grundlagen', body_region: 'LowerBody', primary_muscle_group: 'Fußmuskulatur / Gluteus medius', target_joint: 'Sprunggelenk', movement_pattern: 'Static' },
      { name: 'Balance Board Squat', subgroup: 'Gleichgewicht Grundlagen', body_region: 'LowerBody', primary_muscle_group: 'Quadriceps / Gluteus', target_joint: 'Knie', movement_pattern: 'Squat' },
      { name: 'BOSU Ball beidbeiniger Stand (instabil)', subgroup: 'Gleichgewicht Grundlagen', body_region: 'LowerBody', primary_muscle_group: 'Fußmuskulatur / Wade', target_joint: 'Sprunggelenk', movement_pattern: 'Static' },

      // Reaktive Stabilität
      { name: 'BOSU Ball Einbeinstand (Augen zu)', subgroup: 'Reaktive Stabilität', body_region: 'LowerBody', primary_muscle_group: 'Fußmuskulatur / Gluteus medius', target_joint: 'Sprunggelenk', movement_pattern: 'Static' },
      { name: 'Perturbationstraining (Partner-Stöße)', subgroup: 'Reaktive Stabilität', body_region: 'FullBody', primary_muscle_group: 'Core / Gluteus medius', target_joint: 'Hüfte', movement_pattern: 'Static' },
      { name: 'Reaktiver Einbeinstand mit Ballwurf', subgroup: 'Reaktive Stabilität', body_region: 'FullBody', primary_muscle_group: 'Gluteus medius / Core', target_joint: 'Sprunggelenk', movement_pattern: 'Static' },
      { name: 'Star Excursion Balance Test (SEBT)', subgroup: 'Reaktive Stabilität', body_region: 'LowerBody', primary_muscle_group: 'Gluteus medius / Quadriceps', target_joint: 'Knie', movement_pattern: 'Squat' },

      // Propriozeptives Training
      { name: 'Propriozeptiver Einbeinstand (Therapiekreisel)', subgroup: 'Propriozeptives Training', body_region: 'LowerBody', primary_muscle_group: 'Fußmuskulatur / Peroneus', target_joint: 'Sprunggelenk', movement_pattern: 'Static' },
      { name: 'Augen-zu-Balance nach Sprunglandung', subgroup: 'Propriozeptives Training', body_region: 'LowerBody', primary_muscle_group: 'Fußmuskulatur / Gluteus medius', target_joint: 'Sprunggelenk', movement_pattern: 'Plyo' },
      { name: 'Sensomotorischer Parcours (multi-surface)', subgroup: 'Propriozeptives Training', body_region: 'LowerBody', primary_muscle_group: 'Fußmuskulatur intrinsisch', target_joint: 'Sprunggelenk', movement_pattern: 'Static' },
      { name: 'Einbeinstand mit Kopfbewegung (vestibulär)', subgroup: 'Propriozeptives Training', body_region: 'LowerBody', primary_muscle_group: 'Fußmuskulatur / Gluteus medius', target_joint: 'Sprunggelenk', movement_pattern: 'Static' },

      // Sport-spezifisch
      { name: 'Balance Board + Kettlebell Press', subgroup: 'Sport-spezifisch', body_region: 'FullBody', primary_muscle_group: 'Schulter / Core / Fußmuskulatur', target_joint: 'Schulter', movement_pattern: 'Push' },
      { name: 'Wackelbrett Kniebeuge mit Rotation', subgroup: 'Sport-spezifisch', body_region: 'FullBody', primary_muscle_group: 'Quadriceps / Seitliche Bauchmuskulatur', target_joint: 'Knie', movement_pattern: 'Squat' },
      { name: 'Indo Board Surf-Simulation', subgroup: 'Sport-spezifisch', body_region: 'FullBody', primary_muscle_group: 'Core / Fußmuskulatur / Gluteus medius', target_joint: 'Sprunggelenk', movement_pattern: 'Static' },
    ],
  },

  // ═══════════════════════════════════════════════════════════════════════════
  // 9. Mobilität & Aktive Beweglichkeit
  // ═══════════════════════════════════════════════════════════════════════════
  {
    group: 'Mobilität & Aktive Beweglichkeit',
    subgroups: [
      'CARs (Controlled Articular Rotations)',
      'Endgradige Kraft (PAILs/RAILs)',
      'Aktive Beweglichkeit',
      'Faszien & Bewegungsfluss',
    ],
    exercises: [
      // CARs
      { name: 'Hip CARs (Hüft-Kreisbewegungen)', subgroup: 'CARs (Controlled Articular Rotations)', body_region: 'LowerBody', primary_muscle_group: 'Hüftrotatoren / Gluteus', target_joint: 'Hüfte', movement_pattern: 'Rotation' },
      { name: 'Shoulder CARs (Schulter-Kreisbewegungen)', subgroup: 'CARs (Controlled Articular Rotations)', body_region: 'UpperBody', primary_muscle_group: 'Rotatorenmanschette / Deltoideus', target_joint: 'Schulter', movement_pattern: 'Rotation' },
      { name: 'Spine CARs (Wirbelsäulen-Segmentierung)', subgroup: 'CARs (Controlled Articular Rotations)', body_region: 'Core', primary_muscle_group: 'Rückenstrecker / Bauchmuskulatur', target_joint: 'BWS', movement_pattern: 'Rotation' },
      { name: 'Ankle CARs (Sprunggelenk-Kreise)', subgroup: 'CARs (Controlled Articular Rotations)', body_region: 'LowerBody', primary_muscle_group: 'Wade / Tibialis anterior', target_joint: 'Sprunggelenk', movement_pattern: 'Rotation' },
      { name: 'Wrist CARs (Handgelenk-Kreise)', subgroup: 'CARs (Controlled Articular Rotations)', body_region: 'UpperBody', primary_muscle_group: 'Unterarm', target_joint: 'Handgelenk', movement_pattern: 'Rotation' },

      // PAILs/RAILs (Endgradige Kraft)
      { name: 'PAILs/RAILs Hüftbeuger (aktive Dehnung)', subgroup: 'Endgradige Kraft (PAILs/RAILs)', body_region: 'LowerBody', primary_muscle_group: 'Hüftbeuger / Iliopsoas', target_joint: 'Hüfte', movement_pattern: 'Static' },
      { name: 'PAILs/RAILs Hüftrotation (90/90 Position)', subgroup: 'Endgradige Kraft (PAILs/RAILs)', body_region: 'LowerBody', primary_muscle_group: 'Hüftrotatoren', target_joint: 'Hüfte', movement_pattern: 'Rotation' },
      { name: 'PAILs/RAILs Hamstrings (endgradige Kraft)', subgroup: 'Endgradige Kraft (PAILs/RAILs)', body_region: 'LowerBody', primary_muscle_group: 'Hamstrings', target_joint: 'Knie', movement_pattern: 'Static' },
      { name: 'Kinstretch Hip Lift-Off (endgradige IR)', subgroup: 'Endgradige Kraft (PAILs/RAILs)', body_region: 'LowerBody', primary_muscle_group: 'Hüftrotatoren', target_joint: 'Hüfte', movement_pattern: 'Rotation' },

      // Aktive Beweglichkeit
      { name: 'Jefferson Curl (segmentale Wirbelsäulenflexion)', subgroup: 'Aktive Beweglichkeit', body_region: 'Core', primary_muscle_group: 'Rückenstrecker / Hamstrings', target_joint: 'LWS', movement_pattern: 'Hinge' },
      { name: 'Loaded Progressive Stretching Hamstrings', subgroup: 'Aktive Beweglichkeit', body_region: 'LowerBody', primary_muscle_group: 'Hamstrings', target_joint: 'Knie', movement_pattern: 'Hinge' },
      { name: 'Aktive Hüftbeuger-Dehnung mit Kontraktion', subgroup: 'Aktive Beweglichkeit', body_region: 'LowerBody', primary_muscle_group: 'Hüftbeuger / Iliopsoas', target_joint: 'Hüfte', movement_pattern: 'Static' },
      { name: 'Aktive Brustwirbelsäulen-Extension (Foam Roller)', subgroup: 'Aktive Beweglichkeit', body_region: 'Core', primary_muscle_group: 'Rückenstrecker / BWS-Mobilität', target_joint: 'BWS', movement_pattern: 'Static' },

      // Faszien & Bewegungsfluss
      { name: 'Deep Squat Mobilisation (Goblet Hold)', subgroup: 'Faszien & Bewegungsfluss', body_region: 'LowerBody', primary_muscle_group: 'Hüftbeuger / Quadriceps / Wade', target_joint: 'Hüfte', movement_pattern: 'Squat' },
      { name: 'World\'s Greatest Stretch', subgroup: 'Faszien & Bewegungsfluss', body_region: 'FullBody', primary_muscle_group: 'Hüftbeuger / BWS-Mobilität / Hamstrings', target_joint: 'Hüfte', movement_pattern: 'Rotation' },
      { name: 'Thoracic Spine Rotation (Open Book)', subgroup: 'Faszien & Bewegungsfluss', body_region: 'Core', primary_muscle_group: 'BWS-Mobilität / Seitliche Bauchmuskulatur', target_joint: 'BWS', movement_pattern: 'Rotation' },
      { name: 'Animal Flow (Beast-Crab-Scorpion)', subgroup: 'Faszien & Bewegungsfluss', body_region: 'FullBody', primary_muscle_group: 'Ganzkörper', target_joint: 'Hüfte', movement_pattern: 'Rotation' },
    ],
  },

  // ═══════════════════════════════════════════════════════════════════════════
  // 10. Plyometrie & Reaktivkraft (Schnellkraft, Explosivität, Sprungkraft)
  // ═══════════════════════════════════════════════════════════════════════════
  {
    group: 'Plyometrie & Reaktivkraft',
    subgroups: [
      'Sprungkraft (vertikal)',
      'Sprungkraft (horizontal)',
      'Reaktivkraft & Drop Jumps',
      'Laterale Agilität',
      'Sprint & Beschleunigung',
    ],
    exercises: [
      // Sprungkraft (vertikal)
      { name: 'Box Jump (beidbeinig)', subgroup: 'Sprungkraft (vertikal)', body_region: 'LowerBody', primary_muscle_group: 'Quadriceps / Gluteus', target_joint: 'Knie', movement_pattern: 'Plyo' },
      { name: 'Box Jump einbeinig', subgroup: 'Sprungkraft (vertikal)', body_region: 'LowerBody', primary_muscle_group: 'Quadriceps / Gluteus', target_joint: 'Knie', movement_pattern: 'Plyo' },
      { name: 'Countermovement Jump (CMJ)', subgroup: 'Sprungkraft (vertikal)', body_region: 'LowerBody', primary_muscle_group: 'Quadriceps / Gluteus', target_joint: 'Knie', movement_pattern: 'Plyo' },
      { name: 'Squat Jump (ohne Gegenbeweg.)', subgroup: 'Sprungkraft (vertikal)', body_region: 'LowerBody', primary_muscle_group: 'Quadriceps / Gluteus', target_joint: 'Knie', movement_pattern: 'Plyo' },
      { name: 'Tuck Jump (Knie zur Brust)', subgroup: 'Sprungkraft (vertikal)', body_region: 'LowerBody', primary_muscle_group: 'Quadriceps / Hüftbeuger', target_joint: 'Knie', movement_pattern: 'Plyo' },
      { name: 'Weighted Jump Squat (leicht belastet)', subgroup: 'Sprungkraft (vertikal)', body_region: 'LowerBody', primary_muscle_group: 'Quadriceps / Gluteus', target_joint: 'Knie', movement_pattern: 'Plyo' },
      { name: 'Single-Leg Hop (einbeiniger Vertikalsprung)', subgroup: 'Sprungkraft (vertikal)', body_region: 'LowerBody', primary_muscle_group: 'Quadriceps / Wade', target_joint: 'Knie', movement_pattern: 'Plyo' },

      // Sprungkraft (horizontal)
      { name: 'Broad Jump (Standweitsprung)', subgroup: 'Sprungkraft (horizontal)', body_region: 'LowerBody', primary_muscle_group: 'Gluteus / Quadriceps', target_joint: 'Hüfte', movement_pattern: 'Plyo' },
      { name: 'Bounding (Wechselsprünge)', subgroup: 'Sprungkraft (horizontal)', body_region: 'LowerBody', primary_muscle_group: 'Gluteus / Quadriceps / Wade', target_joint: 'Hüfte', movement_pattern: 'Plyo' },
      { name: 'Einbeiniger Standweitsprung', subgroup: 'Sprungkraft (horizontal)', body_region: 'LowerBody', primary_muscle_group: 'Gluteus / Quadriceps', target_joint: 'Hüfte', movement_pattern: 'Plyo' },
      { name: 'Medizinball-Stoß vorwärts (Power Throw)', subgroup: 'Sprungkraft (horizontal)', body_region: 'FullBody', primary_muscle_group: 'Brust / Schulter / Core', target_joint: 'Schulter', movement_pattern: 'Push' },
      { name: 'Hürdenhüpfen beidbeinig (niedrige Hürden)', subgroup: 'Sprungkraft (horizontal)', body_region: 'LowerBody', primary_muscle_group: 'Quadriceps / Wade', target_joint: 'Knie', movement_pattern: 'Plyo' },

      // Reaktivkraft & Drop Jumps
      { name: 'Drop Jump (Tiefsprung 30-50cm)', subgroup: 'Reaktivkraft & Drop Jumps', body_region: 'LowerBody', primary_muscle_group: 'Quadriceps / Wade', target_joint: 'Knie', movement_pattern: 'Plyo' },
      { name: 'Altitude Landing (Landungsstabilität)', subgroup: 'Reaktivkraft & Drop Jumps', body_region: 'LowerBody', primary_muscle_group: 'Quadriceps / Gluteus', target_joint: 'Knie', movement_pattern: 'Plyo' },
      { name: 'Pogo Hops (Sprunggelenk-Reaktivkraft)', subgroup: 'Reaktivkraft & Drop Jumps', body_region: 'LowerBody', primary_muscle_group: 'Wade / Achillessehne', target_joint: 'Sprunggelenk', movement_pattern: 'Plyo' },
      { name: 'Depth Jump to Box (reaktiv auf Box)', subgroup: 'Reaktivkraft & Drop Jumps', body_region: 'LowerBody', primary_muscle_group: 'Quadriceps / Wade', target_joint: 'Knie', movement_pattern: 'Plyo' },
      { name: 'Continuous Hurdle Hops (Reaktivsprünge über Hürden)', subgroup: 'Reaktivkraft & Drop Jumps', body_region: 'LowerBody', primary_muscle_group: 'Quadriceps / Wade', target_joint: 'Knie', movement_pattern: 'Plyo' },
      { name: 'Ankle Bounce (schnelle Sprunggelenk-Hops)', subgroup: 'Reaktivkraft & Drop Jumps', body_region: 'LowerBody', primary_muscle_group: 'Wade / Achillessehne', target_joint: 'Sprunggelenk', movement_pattern: 'Plyo' },

      // Laterale Agilität
      { name: 'Lateral Bound (Seitsprung beidbeinig)', subgroup: 'Laterale Agilität', body_region: 'LowerBody', primary_muscle_group: 'Gluteus medius / Adduktoren', target_joint: 'Hüfte', movement_pattern: 'Agility' },
      { name: 'Skater Jump (einbeiniger Seitsprung)', subgroup: 'Laterale Agilität', body_region: 'LowerBody', primary_muscle_group: 'Gluteus medius / Quadriceps', target_joint: 'Hüfte', movement_pattern: 'Agility' },
      { name: 'Lateral Hurdle Hop (seitlich über Hürde)', subgroup: 'Laterale Agilität', body_region: 'LowerBody', primary_muscle_group: 'Gluteus medius / Wade', target_joint: 'Hüfte', movement_pattern: 'Agility' },
      { name: 'Pro Agility Shuttle (5-10-5)', subgroup: 'Laterale Agilität', body_region: 'LowerBody', primary_muscle_group: 'Quadriceps / Gluteus medius', target_joint: 'Knie', movement_pattern: 'Agility' },
      { name: 'T-Drill (Agilitäts-T-Lauf)', subgroup: 'Laterale Agilität', body_region: 'LowerBody', primary_muscle_group: 'Quadriceps / Gluteus medius', target_joint: 'Knie', movement_pattern: 'Agility' },
      { name: 'Hexagon Drill (Sechseck-Sprünge)', subgroup: 'Laterale Agilität', body_region: 'LowerBody', primary_muscle_group: 'Wade / Quadriceps', target_joint: 'Sprunggelenk', movement_pattern: 'Agility' },
      { name: 'Richtungswechsel-Sprints (Cut & Go)', subgroup: 'Laterale Agilität', body_region: 'LowerBody', primary_muscle_group: 'Quadriceps / Gluteus medius / Adduktoren', target_joint: 'Knie', movement_pattern: 'Agility' },

      // Sprint & Beschleunigung
      { name: 'Sled Push (Schlittenpressen)', subgroup: 'Sprint & Beschleunigung', body_region: 'LowerBody', primary_muscle_group: 'Gluteus / Quadriceps', target_joint: 'Knie', movement_pattern: 'Sprint' },
      { name: 'Sled Pull (Schlittenziehen)', subgroup: 'Sprint & Beschleunigung', body_region: 'FullBody', primary_muscle_group: 'Gluteus / Oberer Rücken', target_joint: 'Hüfte', movement_pattern: 'Sprint' },
      { name: 'Resisted Sprint (Widerstandssprint)', subgroup: 'Sprint & Beschleunigung', body_region: 'LowerBody', primary_muscle_group: 'Gluteus / Quadriceps / Hüftbeuger', target_joint: 'Hüfte', movement_pattern: 'Sprint' },
      { name: 'Sprint-Start aus verschiedenen Positionen', subgroup: 'Sprint & Beschleunigung', body_region: 'LowerBody', primary_muscle_group: 'Gluteus / Quadriceps', target_joint: 'Knie', movement_pattern: 'Sprint' },
      { name: 'Flying Sprint (Überschnelligkeit 10-30m)', subgroup: 'Sprint & Beschleunigung', body_region: 'LowerBody', primary_muscle_group: 'Hamstrings / Hüftbeuger', target_joint: 'Hüfte', movement_pattern: 'Sprint' },
      { name: 'A-Skip / B-Skip (Lauf-ABC Schnellkraft)', subgroup: 'Sprint & Beschleunigung', body_region: 'LowerBody', primary_muscle_group: 'Hüftbeuger / Wade', target_joint: 'Hüfte', movement_pattern: 'Sprint' },
      { name: 'Acceleration Wall Drill (Wanddrücken-Sprint)', subgroup: 'Sprint & Beschleunigung', body_region: 'LowerBody', primary_muscle_group: 'Gluteus / Hüftbeuger', target_joint: 'Hüfte', movement_pattern: 'Sprint' },
    ],
  },
];
