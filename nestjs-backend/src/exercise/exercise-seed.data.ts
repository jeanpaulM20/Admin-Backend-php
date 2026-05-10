// ─────────────────────────────────────────────────────────────────────────────
// Sportwissenschaftliche Übungsdatenbank — 10 Kernbereiche
// Ganzheitlich, funktionell, Fokus auf Sensomotorik, Sehnen & Mobilität
// ─────────────────────────────────────────────────────────────────────────────

export interface SeedExercise {
  name: string;
  subgroup?: string;
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
      { name: 'Short Foot Exercise (Kurzfuß nach Janda)', subgroup: 'Intrinsische Fußmuskulatur' },
      { name: 'Zehenklavier (isolierte Zehenkontrolle)', subgroup: 'Intrinsische Fußmuskulatur' },
      { name: 'Towel Scrunch (Handtuch-Raffen)', subgroup: 'Intrinsische Fußmuskulatur' },
      { name: 'Marble Pickup (Murmelgreifen mit Zehen)', subgroup: 'Intrinsische Fußmuskulatur' },
      { name: 'Arch Doming (Fußgewölbe-Aktivierung)', subgroup: 'Intrinsische Fußmuskulatur' },
      { name: 'Big Toe Extension mit Widerstandsband', subgroup: 'Intrinsische Fußmuskulatur' },
      { name: 'Toe Yoga (Großzeh heben / Kleinzehen heben)', subgroup: 'Intrinsische Fußmuskulatur' },
      { name: 'Zehen-Spreizen & Kontrahieren (aktiv)', subgroup: 'Intrinsische Fußmuskulatur' },

      // Propriozeption Fuß
      { name: 'Einbeinstand auf instabilem Untergrund', subgroup: 'Propriozeption Fuß' },
      { name: 'Barfuß-Gehen über Sensorik-Pfad', subgroup: 'Propriozeption Fuß' },
      { name: 'Einbeinstand Augen geschlossen (30s+)', subgroup: 'Propriozeption Fuß' },
      { name: 'Tandemstand auf weichem Untergrund', subgroup: 'Propriozeption Fuß' },

      // Barfuß-Kräftigung
      { name: 'Heel Walk / Toe Walk (Fersen-/Zehengang)', subgroup: 'Barfuß-Kräftigung' },
      { name: 'Calf-Raise einbeinig barfuß (langsam exzentrisch)', subgroup: 'Barfuß-Kräftigung' },
      { name: 'Lateral Walk barfuß (Außenkante)', subgroup: 'Barfuß-Kräftigung' },
      { name: 'Barfuß-Treppengehen (kontrolliert exzentrisch)', subgroup: 'Barfuß-Kräftigung' },

      // Barfuß-Laufen
      { name: 'Barfuß-Lauf auf Rasen (Technikfokus Vorfuß)', subgroup: 'Barfuß-Laufen' },
      { name: 'Barfuß-Lauf-ABC (Skipping, Kniehebelauf)', subgroup: 'Barfuß-Laufen' },
      { name: 'Barfuß-Steigerungsläufe (50m progressiv)', subgroup: 'Barfuß-Laufen' },
      { name: 'Barfuß Trail-Walking (Waldboden, Kiesel)', subgroup: 'Barfuß-Laufen' },
      { name: 'Barfuß-Rückwärtslaufen (Propriozeption)', subgroup: 'Barfuß-Laufen' },
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
      { name: 'Tabata Sprints (20s on / 10s off)', subgroup: 'Lauf-Intervalle' },
      { name: 'Hill Repeats (Hügelsprints)', subgroup: 'Lauf-Intervalle' },
      { name: 'Tempo Run (Schwellentraining)', subgroup: 'Lauf-Intervalle' },
      { name: 'Fartlek-Lauf (Fahrtspiel)', subgroup: 'Lauf-Intervalle' },
      { name: '400m Intervalle (VO2max-Training)', subgroup: 'Lauf-Intervalle' },

      // Funktionelle Ausdauer
      { name: 'Burpee-Intervalle (EMOM)', subgroup: 'Funktionelle Ausdauer' },
      { name: 'Seilspringen (Double Unders)', subgroup: 'Funktionelle Ausdauer' },
      { name: 'Ruderergometer Intervalle (500m Repeats)', subgroup: 'Funktionelle Ausdauer' },
      { name: 'Assault Bike Sprint-Intervalle', subgroup: 'Funktionelle Ausdauer' },

      // Zirkeltraining
      { name: 'Bear Crawl + Sprint Kombi', subgroup: 'Zirkeltraining' },
      { name: 'Kettlebell Swing AMRAP (5 Min.)', subgroup: 'Zirkeltraining' },
      { name: 'Funktioneller 5er-Zirkel (Push/Pull/Hinge/Squat/Carry)', subgroup: 'Zirkeltraining' },
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
      { name: 'Ring Support Hold (Stütz-Halten)', subgroup: 'Ring-Grundlagen' },
      { name: 'Ring Rows (Rudern an Ringen)', subgroup: 'Ring-Grundlagen' },
      { name: 'Ring Push-Ups (Liegestütz an Ringen)', subgroup: 'Ring-Grundlagen' },
      { name: 'Ring Turned-Out Support (RTO Hold)', subgroup: 'Ring-Grundlagen' },

      // Ring-Kraft
      { name: 'Ring Dips', subgroup: 'Ring-Kraft' },
      { name: 'Ring Muscle-Up (Progression)', subgroup: 'Ring-Kraft' },
      { name: 'Ring Face Pull', subgroup: 'Ring-Kraft' },
      { name: 'Skin the Cat (Felgaufschwung rückwärts)', subgroup: 'Ring-Kraft' },
      { name: 'Ring L-Sit Hold', subgroup: 'Ring-Kraft' },
      { name: 'Ring Bulgarian Dips (tief)', subgroup: 'Ring-Kraft' },

      // TRX / Schlingen
      { name: 'TRX Body Saw (Schlingentrainer)', subgroup: 'TRX / Schlingen' },
      { name: 'TRX Einbein-Squat (Pistol Assist)', subgroup: 'TRX / Schlingen' },
      { name: 'TRX Y-T-W Schulteraktivierung', subgroup: 'TRX / Schlingen' },
      { name: 'TRX Hamstring Curl (einbeinig)', subgroup: 'TRX / Schlingen' },
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
      { name: 'Kettlebell Swing (Russian)', subgroup: 'Ballistische Übungen' },
      { name: 'Kettlebell Snatch', subgroup: 'Ballistische Übungen' },
      { name: 'Kettlebell Clean', subgroup: 'Ballistische Übungen' },
      { name: 'Kettlebell Clean & Press', subgroup: 'Ballistische Übungen' },
      { name: 'Kettlebell High Pull', subgroup: 'Ballistische Übungen' },

      // Grinds
      { name: 'Turkish Get-Up', subgroup: 'Grinds (langsame Kraft)' },
      { name: 'Kettlebell Goblet Squat', subgroup: 'Grinds (langsame Kraft)' },
      { name: 'Kettlebell Windmill', subgroup: 'Grinds (langsame Kraft)' },
      { name: 'Kettlebell Single-Leg Deadlift', subgroup: 'Grinds (langsame Kraft)' },
      { name: 'Kettlebell Bottom-Up Press (Stabilität)', subgroup: 'Grinds (langsame Kraft)' },
      { name: 'Double Kettlebell Front Squat', subgroup: 'Grinds (langsame Kraft)' },
      { name: 'Kettlebell Bent Press', subgroup: 'Grinds (langsame Kraft)' },

      // Flows
      { name: 'Kettlebell Halo', subgroup: 'Komplexe & Flows' },
      { name: 'Kettlebell Flow (Swing-Clean-Press-Squat)', subgroup: 'Komplexe & Flows' },
      { name: 'Kettlebell Armor Building Complex (2x Clean-Press-Squat)', subgroup: 'Komplexe & Flows' },
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
      { name: 'Exzentrische Calf Raises (Alfredson-Protokoll)', subgroup: 'Sehnen-Prehab' },
      { name: 'Exzentrische Spanish Squats (Patellasehne)', subgroup: 'Sehnen-Prehab' },
      { name: 'Exzentrische Wrist Curls (Tennisarm-Prehab)', subgroup: 'Sehnen-Prehab' },
      { name: 'Isometric-Eccentric Combo Wandsitzen', subgroup: 'Sehnen-Prehab' },
      { name: 'Exzentrische Plantarfaszie-Übung (Towel Stretch)', subgroup: 'Sehnen-Prehab' },

      // Untere Extremität
      { name: 'Exzentrische Nordic Hamstring Curls', subgroup: 'Untere Extremität' },
      { name: 'Exzentrische Single-Leg Squat (5s negativ)', subgroup: 'Untere Extremität' },
      { name: 'Tempo Squat (4-0-2-0 Kadenz)', subgroup: 'Untere Extremität' },
      { name: 'Exzentrische Step-Downs (3s negativ)', subgroup: 'Untere Extremität' },
      { name: 'Exzentrische Bulgarian Split Squat (4s TUT)', subgroup: 'Untere Extremität' },

      // Obere Extremität
      { name: 'Exzentrische Klimmzüge (5s Absenkphase)', subgroup: 'Obere Extremität' },
      { name: 'Exzentrische Push-Ups (5s negativ)', subgroup: 'Obere Extremität' },
      { name: 'Slow Eccentric Ring Row (4s negativ)', subgroup: 'Obere Extremität' },
      { name: 'Exzentrische Dips (5s Absenkphase)', subgroup: 'Obere Extremität' },
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
      { name: 'Handstand an der Wand (Aufbau)', subgroup: 'Drückend' },
      { name: 'Pseudo Planche Push-Up', subgroup: 'Drückend' },
      { name: 'Pike Push-Up (Schulterdrücken)', subgroup: 'Drückend' },
      { name: 'Planche Lean', subgroup: 'Drückend' },
      { name: 'Diamond Push-Up', subgroup: 'Drückend' },

      // Ziehend
      { name: 'Archer Pull-Up', subgroup: 'Ziehend' },
      { name: 'Front Lever Progression (Tuck)', subgroup: 'Ziehend' },
      { name: 'Back Lever Progression (Tuck)', subgroup: 'Ziehend' },
      { name: 'Typewriter Pull-Up', subgroup: 'Ziehend' },

      // Beine & Hüfte
      { name: 'Pistol Squat (einbeinige Kniebeuge)', subgroup: 'Beine & Hüfte' },
      { name: 'Shrimp Squat (Garnelenkniebeuge)', subgroup: 'Beine & Hüfte' },
      { name: 'Natural Leg Extension (Sissy Squat)', subgroup: 'Beine & Hüfte' },

      // Ganzkörper
      { name: 'Hollow Body Hold', subgroup: 'Ganzkörper' },
      { name: 'Dragon Flag (Progression)', subgroup: 'Ganzkörper' },
      { name: 'L-Sit Hold (am Boden oder Parallettes)', subgroup: 'Ganzkörper' },
      { name: 'Human Flag Progression', subgroup: 'Ganzkörper' },
    ],
  },

  // ═══════════════════════════════════════════════════════════════════════════
  // 7. Klettern & Slackline
  // ═══════════════════════════════════════════════════════════════════════════
  {
    group: 'Klettern & Slackline',
    subgroups: ['Griffkraft', 'Scapula-Kontrolle', 'Körperspannung', 'Slackline'],
    exercises: [
      // Griffkraft
      { name: 'Dead Hang (Passivhang 60s+)', subgroup: 'Griffkraft' },
      { name: 'Fingerboard Repeaters (7:3 Protokoll)', subgroup: 'Griffkraft' },
      { name: 'Pinch Block Training (Daumen-Griffkraft)', subgroup: 'Griffkraft' },
      { name: 'Campus Board Touches (Schnellkraft)', subgroup: 'Griffkraft' },
      { name: 'Fat Grip Pull-Ups', subgroup: 'Griffkraft' },
      { name: 'Farmer\'s Walk (schwerer Griffkraft-Carry)', subgroup: 'Griffkraft' },

      // Scapula-Kontrolle
      { name: 'Active Hang (Schulterblatt-Aktivierung)', subgroup: 'Scapula-Kontrolle' },
      { name: 'Scapular Pull-Ups', subgroup: 'Scapula-Kontrolle' },
      { name: 'Scapula Push-Up (Protraktion/Retraktion)', subgroup: 'Scapula-Kontrolle' },
      { name: 'Band Pull-Apart (Schulterblatt-Stabilität)', subgroup: 'Scapula-Kontrolle' },

      // Körperspannung
      { name: 'Lock-Off Holds (90°, 120°, 150°)', subgroup: 'Körperspannung' },
      { name: 'Front Lever Raise (Körperspannung)', subgroup: 'Körperspannung' },
      { name: 'Toe-to-Bar (Körperspannung + Kraft)', subgroup: 'Körperspannung' },

      // Slackline
      { name: 'Slackline Grundposition (Einbeinstand)', subgroup: 'Slackline' },
      { name: 'Slackline Walking (vorwärts/rückwärts)', subgroup: 'Slackline' },
      { name: 'Slackline Yoga Poses (Tree, Warrior)', subgroup: 'Slackline' },
      { name: 'Slackline Kniebeuge (einbeinig)', subgroup: 'Slackline' },
    ],
  },

  // ═══════════════════════════════════════════════════════════════════════════
  // 8. Balance Board / MFT (Sensomotorik & Koordination)
  // ═══════════════════════════════════════════════════════════════════════════
  {
    group: 'Balance Board & Sensomotorik',
    subgroups: ['Gleichgewicht Grundlagen', 'Reaktive Stabilität', 'Propriozeptives Training', 'Sport-spezifisch'],
    exercises: [
      // Gleichgewicht Grundlagen
      { name: 'MFT Board beidbeinig (Kreiselbewegung)', subgroup: 'Gleichgewicht Grundlagen' },
      { name: 'MFT Board einbeinig (Standstabilität)', subgroup: 'Gleichgewicht Grundlagen' },
      { name: 'Balance Board Squat', subgroup: 'Gleichgewicht Grundlagen' },
      { name: 'BOSU Ball beidbeiniger Stand (instabil)', subgroup: 'Gleichgewicht Grundlagen' },

      // Reaktive Stabilität
      { name: 'BOSU Ball Einbeinstand (Augen zu)', subgroup: 'Reaktive Stabilität' },
      { name: 'Perturbationstraining (Partner-Stöße)', subgroup: 'Reaktive Stabilität' },
      { name: 'Reaktiver Einbeinstand mit Ballwurf', subgroup: 'Reaktive Stabilität' },
      { name: 'Star Excursion Balance Test (SEBT)', subgroup: 'Reaktive Stabilität' },

      // Propriozeptives Training
      { name: 'Propriozeptiver Einbeinstand (Therapiekreisel)', subgroup: 'Propriozeptives Training' },
      { name: 'Augen-zu-Balance nach Sprunglandung', subgroup: 'Propriozeptives Training' },
      { name: 'Sensomotorischer Parcours (multi-surface)', subgroup: 'Propriozeptives Training' },
      { name: 'Einbeinstand mit Kopfbewegung (vestibulär)', subgroup: 'Propriozeptives Training' },

      // Sport-spezifisch
      { name: 'Balance Board + Kettlebell Press', subgroup: 'Sport-spezifisch' },
      { name: 'Wackelbrett Kniebeuge mit Rotation', subgroup: 'Sport-spezifisch' },
      { name: 'Indo Board Surf-Simulation', subgroup: 'Sport-spezifisch' },
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
      { name: 'Hip CARs (Hüft-Kreisbewegungen)', subgroup: 'CARs (Controlled Articular Rotations)' },
      { name: 'Shoulder CARs (Schulter-Kreisbewegungen)', subgroup: 'CARs (Controlled Articular Rotations)' },
      { name: 'Spine CARs (Wirbelsäulen-Segmentierung)', subgroup: 'CARs (Controlled Articular Rotations)' },
      { name: 'Ankle CARs (Sprunggelenk-Kreise)', subgroup: 'CARs (Controlled Articular Rotations)' },
      { name: 'Wrist CARs (Handgelenk-Kreise)', subgroup: 'CARs (Controlled Articular Rotations)' },

      // PAILs/RAILs (Endgradige Kraft)
      { name: 'PAILs/RAILs Hüftbeuger (aktive Dehnung)', subgroup: 'Endgradige Kraft (PAILs/RAILs)' },
      { name: 'PAILs/RAILs Hüftrotation (90/90 Position)', subgroup: 'Endgradige Kraft (PAILs/RAILs)' },
      { name: 'PAILs/RAILs Hamstrings (endgradige Kraft)', subgroup: 'Endgradige Kraft (PAILs/RAILs)' },
      { name: 'Kinstretch Hip Lift-Off (endgradige IR)', subgroup: 'Endgradige Kraft (PAILs/RAILs)' },

      // Aktive Beweglichkeit
      { name: 'Jefferson Curl (segmentale Wirbelsäulenflexion)', subgroup: 'Aktive Beweglichkeit' },
      { name: 'Loaded Progressive Stretching Hamstrings', subgroup: 'Aktive Beweglichkeit' },
      { name: 'Aktive Hüftbeuger-Dehnung mit Kontraktion', subgroup: 'Aktive Beweglichkeit' },
      { name: 'Aktive Brustwirbelsäulen-Extension (Foam Roller)', subgroup: 'Aktive Beweglichkeit' },

      // Faszien & Bewegungsfluss
      { name: 'Deep Squat Mobilisation (Goblet Hold)', subgroup: 'Faszien & Bewegungsfluss' },
      { name: 'World\'s Greatest Stretch', subgroup: 'Faszien & Bewegungsfluss' },
      { name: 'Thoracic Spine Rotation (Open Book)', subgroup: 'Faszien & Bewegungsfluss' },
      { name: 'Animal Flow (Beast-Crab-Scorpion)', subgroup: 'Faszien & Bewegungsfluss' },
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
      { name: 'Box Jump (beidbeinig)', subgroup: 'Sprungkraft (vertikal)' },
      { name: 'Box Jump einbeinig', subgroup: 'Sprungkraft (vertikal)' },
      { name: 'Countermovement Jump (CMJ)', subgroup: 'Sprungkraft (vertikal)' },
      { name: 'Squat Jump (ohne Gegenbeweg.)', subgroup: 'Sprungkraft (vertikal)' },
      { name: 'Tuck Jump (Knie zur Brust)', subgroup: 'Sprungkraft (vertikal)' },
      { name: 'Weighted Jump Squat (leicht belastet)', subgroup: 'Sprungkraft (vertikal)' },
      { name: 'Single-Leg Hop (einbeiniger Vertikalsprung)', subgroup: 'Sprungkraft (vertikal)' },

      // Sprungkraft (horizontal)
      { name: 'Broad Jump (Standweitsprung)', subgroup: 'Sprungkraft (horizontal)' },
      { name: 'Bounding (Wechselsprünge)', subgroup: 'Sprungkraft (horizontal)' },
      { name: 'Einbeiniger Standweitsprung', subgroup: 'Sprungkraft (horizontal)' },
      { name: 'Medizinball-Stoß vorwärts (Power Throw)', subgroup: 'Sprungkraft (horizontal)' },
      { name: 'Hürdenhüpfen beidbeinig (niedrige Hürden)', subgroup: 'Sprungkraft (horizontal)' },

      // Reaktivkraft & Drop Jumps
      { name: 'Drop Jump (Tiefsprung 30-50cm)', subgroup: 'Reaktivkraft & Drop Jumps' },
      { name: 'Altitude Landing (Landungsstabilität)', subgroup: 'Reaktivkraft & Drop Jumps' },
      { name: 'Pogo Hops (Sprunggelenk-Reaktivkraft)', subgroup: 'Reaktivkraft & Drop Jumps' },
      { name: 'Depth Jump to Box (reaktiv auf Box)', subgroup: 'Reaktivkraft & Drop Jumps' },
      { name: 'Continuous Hurdle Hops (Reaktivsprünge über Hürden)', subgroup: 'Reaktivkraft & Drop Jumps' },
      { name: 'Ankle Bounce (schnelle Sprunggelenk-Hops)', subgroup: 'Reaktivkraft & Drop Jumps' },

      // Laterale Agilität
      { name: 'Lateral Bound (Seitsprung beidbeinig)', subgroup: 'Laterale Agilität' },
      { name: 'Skater Jump (einbeiniger Seitsprung)', subgroup: 'Laterale Agilität' },
      { name: 'Lateral Hurdle Hop (seitlich über Hürde)', subgroup: 'Laterale Agilität' },
      { name: 'Pro Agility Shuttle (5-10-5)', subgroup: 'Laterale Agilität' },
      { name: 'T-Drill (Agilitäts-T-Lauf)', subgroup: 'Laterale Agilität' },
      { name: 'Hexagon Drill (Sechseck-Sprünge)', subgroup: 'Laterale Agilität' },
      { name: 'Richtungswechsel-Sprints (Cut & Go)', subgroup: 'Laterale Agilität' },

      // Sprint & Beschleunigung
      { name: 'Sled Push (Schlittenpressen)', subgroup: 'Sprint & Beschleunigung' },
      { name: 'Sled Pull (Schlittenziehen)', subgroup: 'Sprint & Beschleunigung' },
      { name: 'Resisted Sprint (Widerstandssprint)', subgroup: 'Sprint & Beschleunigung' },
      { name: 'Sprint-Start aus verschiedenen Positionen', subgroup: 'Sprint & Beschleunigung' },
      { name: 'Flying Sprint (Überschnelligkeit 10-30m)', subgroup: 'Sprint & Beschleunigung' },
      { name: 'A-Skip / B-Skip (Lauf-ABC Schnellkraft)', subgroup: 'Sprint & Beschleunigung' },
      { name: 'Acceleration Wall Drill (Wanddrücken-Sprint)', subgroup: 'Sprint & Beschleunigung' },
    ],
  },
];
