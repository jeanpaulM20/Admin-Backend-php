/**
 * Belastungsschemata für klassisches Krafttraining — deterministisch, damit
 * Sätze und Wiederholungen nicht vom Zufall des Modells abhängen
 * (Konzept, Abschnitt 7).
 */

export type StrengthGoal = 'maxkraft' | 'hypertrophie' | 'kraftausdauer';
export const STRENGTH_GOALS: readonly StrengthGoal[] = ['maxkraft', 'hypertrophie', 'kraftausdauer'];

export interface StrengthScheme {
  label: string;
  sets: string;
  reps: string;
  restSeconds: string;
  tempo: string;
  intensity: string;
}

export const STRENGTH_SCHEMES: Record<StrengthGoal, StrengthScheme> = {
  maxkraft: {
    label: 'Maximalkraft',
    sets: '3–5', reps: '3–6', restSeconds: '180–300',
    tempo: '2-0-X-0', intensity: '85–95 % des 1RM, nur für Trainierte mit sauberer Technik',
  },
  hypertrophie: {
    label: 'Hypertrophie',
    sets: '3–4', reps: '8–12', restSeconds: '60–90',
    tempo: '3-1-1-0', intensity: '65–80 % des 1RM, letzte Wiederholungen fordernd',
  },
  kraftausdauer: {
    label: 'Kraftausdauer',
    sets: '2–3', reps: '15–25', restSeconds: '30–60',
    tempo: '2-0-2-0', intensity: '40–60 % des 1RM, zügig und kontrolliert',
  },
};

/** Übungszahl je Abschnitt nach Dauer — Pendant zum Athletik-Mapping. */
export const FITNESS_DURATION_MAPPING: Record<30 | 45 | 60, { sonsomo: string; main: string; core: string; mobility: string }> = {
  30: { sonsomo: '1-2', main: '3-4', core: '1', mobility: '1' },
  45: { sonsomo: '2', main: '4-5', core: '2', mobility: '1-2' },
  60: { sonsomo: '2', main: '5-6', core: '2-3', mobility: '2' },
};

/** Prompt-Block für einen Fitness-Plan; überschreibt die Athletik-Struktur. */
export function fitnessPromptBlock(goal: StrengthGoal, duration: 30 | 45 | 60 | null): string {
  const s = STRENGTH_SCHEMES[goal];
  const counts = duration ? FITNESS_DURATION_MAPPING[duration] : null;
  const structure = counts
    ? `- "sonsomo" = AUFWÄRMEN: ${counts.sonsomo} Übungen (Cardio 5–8 Min oder Mobilisation der beteiligten Gelenke)
- "main" = HAUPTTEIL: ${counts.main} Übungen, Grundübungen zuerst (Kniebeuge/Kreuzheben/Drücken/Ziehen), dann Isolationsübungen
- "core" = CORE: ${counts.core} Übungen
- "mobility" = AUSKLANG: ${counts.mobility} Übungen (Dehnung der beanspruchten Muskeln)`
    : `- "sonsomo" = AUFWÄRMEN: 2 Übungen
- "main" = HAUPTTEIL: 4–6 Übungen, Grundübungen zuerst, dann Isolationsübungen
- "core" = CORE: 2 Übungen
- "mobility" = AUSKLANG: 1–2 Übungen`;

  return `MODALITÄT: KLASSISCHES FITNESS-/GERÄTETRAINING
Die Regel 5 (STRUKTUR) oben gilt für Athletik-Pläne und ist für diesen Plan ERSETZT durch:
${structure}
Die Abschnitte heissen im Plan Aufwärmen, Hauptteil, Core, Ausklang — keine Sensomotorik, keine Barfussarbeit im Aufwärmen.

BELASTUNGSSCHEMA (verbindlich für den Hauptteil): ${s.label}
- Sätze: ${s.sets} · Wiederholungen: ${s.reps} · Pause: ${s.restSeconds} s
- Tempo ${s.tempo} (exzentrisch-Pause-konzentrisch-Pause) · Intensität: ${s.intensity}
- Trage das Schema in "sets" ein (z.B. "${s.sets.split('–')[0]}×${s.reps.split('–')[0]}") und ein realistisches Startgewicht in "weight".
- Push/Pull ausgleichen: je Druckübung eine Zugübung im Hauptteil.
- Bevorzuge Übungen aus dem Katalog mit passendem Gerät; der Katalog nennt zu jeder Übung Level und Gerät.`;
}
