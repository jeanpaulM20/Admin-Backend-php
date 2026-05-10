// ─────────────────────────────────────────────────────────────────────────────
// Sportwissenschaftliche Übungsdatenbank — 9 Kernbereiche
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
    subgroups: ['Intrinsische Fußmuskulatur', 'Propriozeption Fuß', 'Barfuß-Kräftigung'],
    exercises: [
      { name: 'Short Foot Exercise (Kurzfuß nach Janda)', subgroup: 'Intrinsische Fußmuskulatur' },
      { name: 'Zehenklavier (isolierte Zehenkontrolle)', subgroup: 'Intrinsische Fußmuskulatur' },
      { name: 'Towel Scrunch (Handtuch-Raffen)', subgroup: 'Intrinsische Fußmuskulatur' },
      { name: 'Marble Pickup (Murmelgreifen mit Zehen)', subgroup: 'Intrinsische Fußmuskulatur' },
      { name: 'Einbeinstand auf instabilem Untergrund', subgroup: 'Propriozeption Fuß' },
      { name: 'Barfuß-Gehen über Sensorik-Pfad', subgroup: 'Propriozeption Fuß' },
      { name: 'Heel Walk / Toe Walk (Fersen-/Zehengang)', subgroup: 'Barfuß-Kräftigung' },
      { name: 'Arch Doming (Fußgewölbe-Aktivierung)', subgroup: 'Intrinsische Fußmuskulatur' },
      { name: 'Big Toe Extension mit Widerstandsband', subgroup: 'Intrinsische Fußmuskulatur' },
      { name: 'Calf-Raise einbeinig barfuß (langsam exzentrisch)', subgroup: 'Barfuß-Kräftigung' },
    ],
  },

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. Ausdauer (funktional & intervallbasiert)
  // ═══════════════════════════════════════════════════════════════════════════
  {
    group: 'Ausdauer & Intervalltraining',
    subgroups: ['Lauf-Intervalle', 'Funktionelle Ausdauer', 'Zirkeltraining'],
    exercises: [
      { name: 'Tabata Sprints (20s on / 10s off)', subgroup: 'Lauf-Intervalle' },
      { name: 'Hill Repeats (Hügelsprints)', subgroup: 'Lauf-Intervalle' },
      { name: 'Tempo Run (Schwellentraining)', subgroup: 'Lauf-Intervalle' },
      { name: 'Fartlek-Lauf (Fahrtspiel)', subgroup: 'Lauf-Intervalle' },
      { name: 'Burpee-Intervalle (EMOM)', subgroup: 'Funktionelle Ausdauer' },
      { name: 'Seilspringen (Double Unders)', subgroup: 'Funktionelle Ausdauer' },
      { name: 'Ruderergometer Intervalle (500m Repeats)', subgroup: 'Funktionelle Ausdauer' },
      { name: 'Assault Bike Sprint-Intervalle', subgroup: 'Funktionelle Ausdauer' },
      { name: 'Bear Crawl + Sprint Kombi', subgroup: 'Zirkeltraining' },
      { name: 'Kettlebell Swing AMRAP (5 Min.)', subgroup: 'Zirkeltraining' },
    ],
  },

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. Ring- & Suspension-Training
  // ═══════════════════════════════════════════════════════════════════════════
  {
    group: 'Ring- & Suspension-Training',
    subgroups: ['Ring-Grundlagen', 'Ring-Kraft', 'TRX / Schlingen'],
    exercises: [
      { name: 'Ring Support Hold (Stütz-Halten)', subgroup: 'Ring-Grundlagen' },
      { name: 'Ring Rows (Rudern an Ringen)', subgroup: 'Ring-Grundlagen' },
      { name: 'Ring Push-Ups (Liegestütz an Ringen)', subgroup: 'Ring-Grundlagen' },
      { name: 'Ring Dips', subgroup: 'Ring-Kraft' },
      { name: 'Ring Muscle-Up (Progression)', subgroup: 'Ring-Kraft' },
      { name: 'Ring Face Pull', subgroup: 'Ring-Kraft' },
      { name: 'Skin the Cat (Felgaufschwung rückwärts)', subgroup: 'Ring-Kraft' },
      { name: 'Ring L-Sit Hold', subgroup: 'Ring-Kraft' },
      { name: 'TRX Body Saw (Schlingentrainer)', subgroup: 'TRX / Schlingen' },
      { name: 'TRX Einbein-Squat (Pistol Assist)', subgroup: 'TRX / Schlingen' },
      { name: 'TRX Y-T-W Schulteraktivierung', subgroup: 'TRX / Schlingen' },
    ],
  },

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. Kettlebell-Training
  // ═══════════════════════════════════════════════════════════════════════════
  {
    group: 'Kettlebell-Training',
    subgroups: ['Ballistische Übungen', 'Grinds (langsame Kraft)', 'Komplexe & Flows'],
    exercises: [
      { name: 'Kettlebell Swing (Russian)', subgroup: 'Ballistische Übungen' },
      { name: 'Kettlebell Snatch', subgroup: 'Ballistische Übungen' },
      { name: 'Kettlebell Clean', subgroup: 'Ballistische Übungen' },
      { name: 'Kettlebell Clean & Press', subgroup: 'Ballistische Übungen' },
      { name: 'Turkish Get-Up', subgroup: 'Grinds (langsame Kraft)' },
      { name: 'Kettlebell Goblet Squat', subgroup: 'Grinds (langsame Kraft)' },
      { name: 'Kettlebell Windmill', subgroup: 'Grinds (langsame Kraft)' },
      { name: 'Kettlebell Single-Leg Deadlift', subgroup: 'Grinds (langsame Kraft)' },
      { name: 'Kettlebell Halo', subgroup: 'Komplexe & Flows' },
      { name: 'Kettlebell Flow (Swing-Clean-Press-Squat)', subgroup: 'Komplexe & Flows' },
      { name: 'Kettlebell Bottom-Up Press (Stabilität)', subgroup: 'Grinds (langsame Kraft)' },
      { name: 'Double Kettlebell Front Squat', subgroup: 'Grinds (langsame Kraft)' },
    ],
  },

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. Exzentrisches Training (Sehnen-Prehab & Hypertrophie)
  // ═══════════════════════════════════════════════════════════════════════════
  {
    group: 'Exzentrisches Training',
    subgroups: ['Untere Extremität', 'Obere Extremität', 'Sehnen-Prehab'],
    exercises: [
      { name: 'Exzentrische Calf Raises (Alfredson-Protokoll)', subgroup: 'Sehnen-Prehab' },
      { name: 'Exzentrische Nordic Hamstring Curls', subgroup: 'Untere Extremität' },
      { name: 'Exzentrische Spanish Squats (Patellasehne)', subgroup: 'Sehnen-Prehab' },
      { name: 'Exzentrische Single-Leg Squat (5s negativ)', subgroup: 'Untere Extremität' },
      { name: 'Exzentrische Klimmzüge (5s Absenkphase)', subgroup: 'Obere Extremität' },
      { name: 'Exzentrische Push-Ups (5s negativ)', subgroup: 'Obere Extremität' },
      { name: 'Exzentrische Wrist Curls (Tennisarm-Prehab)', subgroup: 'Sehnen-Prehab' },
      { name: 'Tempo Squat (4-0-2-0 Kadenz)', subgroup: 'Untere Extremität' },
      { name: 'Slow Eccentric Ring Row (4s negativ)', subgroup: 'Obere Extremität' },
      { name: 'Isometric-Eccentric Combo Wandsitzen', subgroup: 'Sehnen-Prehab' },
    ],
  },

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. Eigenkörpergewicht (Calisthenics)
  // ═══════════════════════════════════════════════════════════════════════════
  {
    group: 'Eigenkörpergewicht / Calisthenics',
    subgroups: ['Drückend', 'Ziehend', 'Beine & Hüfte', 'Ganzkörper'],
    exercises: [
      { name: 'Hollow Body Hold', subgroup: 'Ganzkörper' },
      { name: 'Handstand an der Wand (Aufbau)', subgroup: 'Drückend' },
      { name: 'Pseudo Planche Push-Up', subgroup: 'Drückend' },
      { name: 'Pike Push-Up (Schulterdrücken)', subgroup: 'Drückend' },
      { name: 'Archer Pull-Up', subgroup: 'Ziehend' },
      { name: 'Front Lever Progression (Tuck)', subgroup: 'Ziehend' },
      { name: 'Pistol Squat (einbeinige Kniebeuge)', subgroup: 'Beine & Hüfte' },
      { name: 'Shrimp Squat (Garnelenkniebeuge)', subgroup: 'Beine & Hüfte' },
      { name: 'Dragon Flag (Progression)', subgroup: 'Ganzkörper' },
      { name: 'Back Lever Progression (Tuck)', subgroup: 'Ziehend' },
      { name: 'Planche Lean', subgroup: 'Drückend' },
      { name: 'L-Sit Hold (am Boden oder Parallettes)', subgroup: 'Ganzkörper' },
    ],
  },

  // ═══════════════════════════════════════════════════════════════════════════
  // 7. Klettern & Slackline
  // ═══════════════════════════════════════════════════════════════════════════
  {
    group: 'Klettern & Slackline',
    subgroups: ['Griffkraft', 'Scapula-Kontrolle', 'Körperspannung', 'Slackline'],
    exercises: [
      { name: 'Dead Hang (Passivhang 60s+)', subgroup: 'Griffkraft' },
      { name: 'Active Hang (Schulterblatt-Aktivierung)', subgroup: 'Scapula-Kontrolle' },
      { name: 'Fingerboard Repeaters (7:3 Protokoll)', subgroup: 'Griffkraft' },
      { name: 'Pinch Block Training (Daumen-Griffkraft)', subgroup: 'Griffkraft' },
      { name: 'Scapular Pull-Ups', subgroup: 'Scapula-Kontrolle' },
      { name: 'Lock-Off Holds (90°, 120°, 150°)', subgroup: 'Körperspannung' },
      { name: 'Campus Board Touches (Schnellkraft)', subgroup: 'Griffkraft' },
      { name: 'Front Lever Raise (Körperspannung)', subgroup: 'Körperspannung' },
      { name: 'Slackline Grundposition (Einbeinstand)', subgroup: 'Slackline' },
      { name: 'Slackline Walking (vorwärts/rückwärts)', subgroup: 'Slackline' },
      { name: 'Slackline Yoga Poses (Tree, Warrior)', subgroup: 'Slackline' },
    ],
  },

  // ═══════════════════════════════════════════════════════════════════════════
  // 8. Balance Board / MFT (Sensomotorik & Koordination)
  // ═══════════════════════════════════════════════════════════════════════════
  {
    group: 'Balance Board & Sensomotorik',
    subgroups: ['Gleichgewicht Grundlagen', 'Reaktive Stabilität', 'Sport-spezifisch'],
    exercises: [
      { name: 'MFT Board beidbeinig (Kreiselbewegung)', subgroup: 'Gleichgewicht Grundlagen' },
      { name: 'MFT Board einbeinig (Standstabilität)', subgroup: 'Gleichgewicht Grundlagen' },
      { name: 'Balance Board Squat', subgroup: 'Gleichgewicht Grundlagen' },
      { name: 'BOSU Ball Einbeinstand (Augen zu)', subgroup: 'Reaktive Stabilität' },
      { name: 'Perturbationstraining (Partner-Stöße)', subgroup: 'Reaktive Stabilität' },
      { name: 'Reaktiver Einbeinstand mit Ballwurf', subgroup: 'Reaktive Stabilität' },
      { name: 'Balance Board + Kettlebell Press', subgroup: 'Sport-spezifisch' },
      { name: 'Wackelbrett Kniebeuge mit Rotation', subgroup: 'Sport-spezifisch' },
      { name: 'Star Excursion Balance Test (SEBT)', subgroup: 'Reaktive Stabilität' },
      { name: 'Indo Board Surf-Simulation', subgroup: 'Sport-spezifisch' },
    ],
  },

  // ═══════════════════════════════════════════════════════════════════════════
  // 9. Mobilität & Aktive Beweglichkeit
  // ═══════════════════════════════════════════════════════════════════════════
  {
    group: 'Mobilität & Aktive Beweglichkeit',
    subgroups: ['CARs (Controlled Articular Rotations)', 'Endgradige Kraft', 'Faszien & Bewegungsfluss'],
    exercises: [
      { name: 'Hip CARs (Hüft-Kreisbewegungen)', subgroup: 'CARs (Controlled Articular Rotations)' },
      { name: 'Shoulder CARs (Schulter-Kreisbewegungen)', subgroup: 'CARs (Controlled Articular Rotations)' },
      { name: 'Spine CARs (Wirbelsäulen-Segmentierung)', subgroup: 'CARs (Controlled Articular Rotations)' },
      { name: 'Ankle CARs (Sprunggelenk-Kreise)', subgroup: 'CARs (Controlled Articular Rotations)' },
      { name: 'PAILs/RAILs Hüftbeuger (aktive Dehnung)', subgroup: 'Endgradige Kraft' },
      { name: 'PAILs/RAILs Hüftrotation (90/90 Position)', subgroup: 'Endgradige Kraft' },
      { name: 'Jefferson Curl (segmentale Wirbelsäulenflexion)', subgroup: 'Endgradige Kraft' },
      { name: 'Loaded Progressive Stretching Hamstrings', subgroup: 'Endgradige Kraft' },
      { name: 'Deep Squat Mobilisation (Goblet Hold)', subgroup: 'Faszien & Bewegungsfluss' },
      { name: 'World\'s Greatest Stretch', subgroup: 'Faszien & Bewegungsfluss' },
      { name: 'Thoracic Spine Rotation (Open Book)', subgroup: 'Faszien & Bewegungsfluss' },
      { name: 'Kinstretch Hip Lift-Off (endgradige IR)', subgroup: 'Endgradige Kraft' },
    ],
  },
];
