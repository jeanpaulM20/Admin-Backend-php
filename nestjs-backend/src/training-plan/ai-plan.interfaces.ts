// ─────────────────────────────────────────────────────────────────────────────
// Interfaces for AI-powered training plan generation
// ─────────────────────────────────────────────────────────────────────────────

/** Single exercise row as stored in the TrainingPlan JSON `values` blob. */
export interface AiPlanRow {
  exercise: string;
  exerciseId?: number;   // Matched DB id (null = new exercise)
  isNew?: boolean;       // true if the AI suggested an exercise not in our DB
  device: string;
  position: string;
  weight: string;
  sets?: string;         // e.g. "3×12"
  dates: string[];       // 8 empty slots
}

/** Full AI-generated plan payload returned to the frontend. */
export interface AiPlanResult {
  name: string;
  sonsomo: AiPlanRow[];
  main: AiPlanRow[];
  core: AiPlanRow[];
  mobility: AiPlanRow[];
  ai_reasoning: string;              // Human-readable explanation
  weaknesses: AiWeakness[];          // Identified test deficits
  basedOnTestId: number | null;
  basedOnTestDate: string | null;
  contraindications: string[];       // Active medical constraints
  isRuleBased?: boolean;             // true = LLM failed, rule-based fallback used
  llmError?: string;                 // Error message if LLM failed
}

/** A single identified weakness from the performance test. */
export interface AiWeakness {
  field: string;          // DB column name e.g. "pullups"
  label: string;          // Human-readable e.g. "Zugkraft Oberkörper"
  value: number;          // Actual test value
  benchmark: number;      // Expected minimum
  deficit: number;        // Percent below benchmark (0-100)
  category: 'warmup' | 'main' | 'core';
}

// ── Data sent to the LLM ────────────────────────────────────────────────────

/** Compact exercise entry sent in the AI prompt (not the full entity). */
export interface AiExerciseCatalog {
  id: number;
  name: string;
  group: string | null;
  subgroup: string | null;
  bodyRegion: string | null;
  muscle: string | null;
  joint: string | null;
  pattern: string | null;
}

/** The structured prompt context assembled for the LLM. */
export interface AiPromptContext {
  client: {
    id: number;
    name: string;
    birthdate?: string;
    gender?: string;
    minHeartRate?: number;
    maxHeartRate?: number;
  };
  anamnese: {
    injuries: string | null;
    injuryBodypart: string | null;
    injuryChronic: boolean;
    diseases: string[];
    musculoskeletalProblems: string | null;
    goals: string | null;
    sportarts: string | null;
    sportartsIntensity: string | null;
    profession: string | null;
    activities: string | null;
    physicalDemands: string | null;
    sleepWeek: string | null;
    sleepWeekend: string | null;
    medicalTreatment: boolean;
    takingDrugs: boolean;
    comments: string | null;
  };
  bodyComposition: {
    date: string | null;
    weight: number | null;
    bodyFatPerc: number | null;
    bodyFatKg: number | null;
    waistCircumference: number | null;
    bcm: number | null;
    sys: number | null;
    dia: number | null;
    calmPulse: number | null;
  } | null;
  goals: {
    description: string;
    targetDate: string | null;
    achieved: boolean;
  }[];
  recentTrainings: {
    trainingType: string | null;
    duration: string | null;
    kcal: number | null;
    heartRate: number | null;
    feedbackEmoticon: string | null;
  }[];
  performanceTest: {
    date: string;
    results: Record<string, number>;
    notTested?: string[];
  };
  weaknesses: AiWeakness[];
  exerciseCatalog: AiExerciseCatalog[];
}

/** Shape the LLM must return (enforced via structured prompt). */
export interface AiLlmResponse {
  plan_name: string;
  sonsomo: AiLlmExercise[];
  main: AiLlmExercise[];
  core: AiLlmExercise[];
  mobility: AiLlmExercise[];
  reasoning: string;
}

export interface AiLlmExercise {
  exercise_name: string;
  exercise_id: number | null;   // null = not found in catalog
  device: string;
  position: string;
  weight: string;
  sets?: string;                // e.g. "3×12"
}
