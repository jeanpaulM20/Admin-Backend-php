import {
  Injectable,
  Logger,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import Anthropic from '@anthropic-ai/sdk';
import Groq from 'groq-sdk';

import { TrainingPlan } from '../entities/training-plan.entity';
import { PerformanceTest } from '../entities/performance-test.entity';
import { ClientAnamnese } from '../entities/client-anamnese.entity';
import { Exercise } from '../entities/exercise.entity';
import { Client } from '../entities/client.entity';
import { Metric } from '../entities/metric.entity';
import { Review } from '../entities/review.entity';
import { Goal } from '../entities/remaining.entities';

import {
  AiPlanResult,
  AiPlanRow,
  AiPlanRequest,
  AiWeakness,
  AiExerciseCatalog,
  AiPromptContext,
  AiLlmResponse,
  AiTrainingType,
  AiAusdauerIntensity,
  AiHrZones,
} from './ai-plan.interfaces';

// ─────────────────────────────────────────────────────────────────────────────
// Performance-test field → human label + benchmark + plan section mapping
// ─────────────────────────────────────────────────────────────────────────────

const TEST_BENCHMARKS: Record<
  string,
  { label: string; min: number; category: 'warmup' | 'main' | 'core' }
> = {
  // Stability → warm-up / sonsomo
  points:       { label: 'Stabilitätspunkte',      min: 5,  category: 'warmup' },
  hamstrings:   { label: 'Hamstring-Flexibilität',  min: 3,  category: 'warmup' },
  calfs:        { label: 'Wadenflexibilität',       min: 3,  category: 'warmup' },
  adductors:    { label: 'Adduktoren',              min: 3,  category: 'warmup' },
  sensomotoric: { label: 'Sensomotorik',            min: 5,  category: 'warmup' },
  symmetry:     { label: 'Symmetrie',               min: 5,  category: 'warmup' },

  // Strength → main
  pullups:                { label: 'Zugkraft Oberkörper',   min: 5,  category: 'main' },
  pushups:                { label: 'Druckkraft Oberkörper', min: 15, category: 'main' },
  trunk_bending:          { label: 'Rumpfbeuge',            min: 10, category: 'main' },
  squat_on_wall:          { label: 'Wandsitzen (Sek.)',     min: 45, category: 'main' },
  counter_movement_jump:  { label: 'Sprungkraft (cm)',      min: 25, category: 'main' },
  reaction:               { label: 'Reaktionszeit',         min: 5,  category: 'main' },
  tapping:                { label: 'Tapping',               min: 30, category: 'main' },

  // Sprint → main
  sprint_10: { label: 'Sprint 10m (Sek.)', min: 0, category: 'main' },
  sprint_20: { label: 'Sprint 20m (Sek.)', min: 0, category: 'main' },
  sprint_30: { label: 'Sprint 30m (Sek.)', min: 0, category: 'main' },

  // Core
  forearm_support: { label: 'Unterarmstütz (Sek.)',  min: 60, category: 'core' },
  side_support:    { label: 'Seitstütz (Sek.)',      min: 30, category: 'core' },
};

// Disease field → human-readable label for the LLM
const DISEASE_LABELS: Record<string, string> = {
  disease_heartattack:            'Herzinfarkt in der Vorgeschichte',
  disease_arterial_disorder:      'Arterielle Durchblutungsstörung',
  disease_raynauld_syndrome:      'Raynaud-Syndrom',
  disease_vasculitis:             'Vaskulitis',
  disease_cold_sensitivity:       'Kälteempfindlichkeit',
  disease_sensory_disturbances:   'Sensibilitätsstörung',
  disease_circulatory_disorder:   'Kreislaufstörung',
  disease_nerve_damage:           'Nervenschädigung',
  disease_replantation:           'Replantation',
  disease_peripheral_lymphatics:  'Periphere Lymphabflussstörung',
  disease_hemoglobinemia:         'Hämoglobinämie',
  disease_kidney_bladder:         'Nieren-/Blasenerkrankung',
  disease_heart_circulatory:      'Herz-Kreislauf-Erkrankung',
};

// ─────────────────────────────────────────────────────────────────────────────
// AI Provider type — switch via AI_PROVIDER env var
// ─────────────────────────────────────────────────────────────────────────────

type AiProvider = 'groq' | 'anthropic' | 'none';

@Injectable()
export class AiPlanService {
  private readonly logger = new Logger(AiPlanService.name);
  private anthropic: Anthropic | null = null;
  private groq: Groq | null = null;
  private readonly provider: AiProvider;

  constructor(
    @InjectRepository(TrainingPlan)
    private readonly planRepo: Repository<TrainingPlan>,
    @InjectRepository(PerformanceTest)
    private readonly testRepo: Repository<PerformanceTest>,
    @InjectRepository(ClientAnamnese)
    private readonly anamneseRepo: Repository<ClientAnamnese>,
    @InjectRepository(Exercise)
    private readonly exerciseRepo: Repository<Exercise>,
    @InjectRepository(Client)
    private readonly clientRepo: Repository<Client>,
    @InjectRepository(Metric)
    private readonly metricRepo: Repository<Metric>,
    @InjectRepository(Review)
    private readonly reviewRepo: Repository<Review>,
    @InjectRepository(Goal)
    private readonly goalRepo: Repository<Goal>,
  ) {
    // Initialize ALL available providers (primary + fallback)
    const requestedProvider = (process.env.AI_PROVIDER || '').toLowerCase().trim();
    const groqKey = process.env.GROQ_API_KEY?.trim();
    const anthropicKey = process.env.ANTHROPIC_API_KEY?.trim();

    // Initialize both SDKs if keys exist (for fallback)
    if (groqKey) this.groq = new Groq({ apiKey: groqKey });
    if (anthropicKey) this.anthropic = new Anthropic({ apiKey: anthropicKey });

    // Determine primary provider
    if (requestedProvider === 'anthropic' && anthropicKey) {
      this.provider = 'anthropic';
    } else if (requestedProvider === 'groq' && groqKey) {
      this.provider = 'groq';
    } else if (anthropicKey) {
      this.provider = 'anthropic';
    } else if (groqKey) {
      this.provider = 'groq';
    } else {
      this.provider = 'none';
    }

    const fallback = this.provider === 'anthropic' && this.groq ? 'groq'
                   : this.provider === 'groq' && this.anthropic ? 'anthropic'
                   : 'none';
    this.logger.log(`AI Provider: ${this.provider} (fallback: ${fallback})`);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════════════════════════

  /** Debug: returns which AI provider is active, optionally tests the connection */
  async getProviderStatus(test = false) {
    const status: any = {
      provider: this.provider,
      groqConfigured: !!this.groq,
      anthropicConfigured: !!this.anthropic,
      env: {
        AI_PROVIDER: process.env.AI_PROVIDER ?? '(not set)',
        GROQ_API_KEY: process.env.GROQ_API_KEY ? `set (${process.env.GROQ_API_KEY.substring(0, 10)}...)` : '(not set)',
        ANTHROPIC_API_KEY: process.env.ANTHROPIC_API_KEY ? `set (${process.env.ANTHROPIC_API_KEY.substring(0, 15)}...)` : '(not set)',
      },
    };

    if (test && this.anthropic) {
      try {
        const resp = await this.anthropic.messages.create({
          model: 'claude-haiku-4-5-20251001',
          max_tokens: 10,
          messages: [{ role: 'user', content: 'Say OK' }],
        });
        status.anthropicTest = { ok: true, model: 'claude-haiku-4-5-20251001', response: resp.content?.[0] };
      } catch (err: any) {
        status.anthropicTest = { ok: false, error: err.message?.substring(0, 300) };
      }
    }

    return status;
  }

  async generateAiPlan(clientId: number, request?: AiPlanRequest): Promise<AiPlanResult> {
    // 1. Load all required data in parallel
    const [client, test, anamnese, exercises, metric, goals, recentReviews] = await Promise.all([
      this.loadClient(clientId),
      this.loadLatestTest(clientId),
      this.loadAnamnese(clientId),
      this.loadExerciseCatalog(),
      this.loadLatestMetric(clientId),
      this.loadGoals(clientId),
      this.loadRecentReviews(clientId),
    ]);

    // 2. Identify weaknesses from test
    const weaknesses = this.identifyWeaknesses(test);

    // 3. Extract contraindications from anamnese
    const contraindications = this.extractContraindications(anamnese);

    // 4. Build prompt context (with optional plan request)
    const context = this.buildPromptContext(
      client, test, anamnese, weaknesses, exercises, metric, goals, recentReviews, request,
    );

    // 5. Generate plan (AI or rule-based fallback)
    let llmResponse: AiLlmResponse;
    let isRuleBased = false;
    let llmError: string | undefined;
    try {
      llmResponse = await this.callLlm(context);
    } catch (err: any) {
      this.logger.warn(`LLM call failed, using rule-based fallback: ${err?.message ?? err}`);
      llmResponse = this.ruleBasedFallback(weaknesses, exercises, contraindications);
      isRuleBased = true;
      llmError = err?.message ?? String(err);
    }

    // 6. Match suggested exercises against DB
    const exerciseMap = new Map(exercises.map((e) => [e.id, e]));
    const exerciseByName = new Map(exercises.map((e) => [e.name.toLowerCase(), e]));
    // Running plan detection — disabled when fallback is used (fallback generates gym exercises)
    let isRunningPlan = request?.trainingType === 'ausdauer' && !!request?.ausdauerIntensity;
    if (isRuleBased) isRunningPlan = false;

    const mapRows = (rows: AiLlmResponse['sonsomo'], skipDbMatch = false): AiPlanRow[] =>
      rows.map((r) => {
        // Running protocol rows in main don't match DB exercises
        if (skipDbMatch) {
          return {
            exercise: r.exercise_name,
            exerciseId: undefined,
            isNew: false,
            device: r.device || '',
            position: r.position || '',
            weight: r.weight || '',
            sets: r.sets || '',
            dates: Array(8).fill(''),
          };
        }
        // Try matching by ID first, then by name
        const byId = r.exercise_id ? exerciseMap.get(r.exercise_id) : null;
        const byName = exerciseByName.get(r.exercise_name.toLowerCase());
        const match = byId ?? byName;
        return {
          exercise: match?.name ?? r.exercise_name,
          exerciseId: match?.id ?? undefined,
          isNew: !match,
          device: r.device || '',
          position: r.position || '',
          weight: r.weight || '',
          sets: r.sets || '',
          dates: Array(8).fill(''),
        };
      });

    // For running plans, calculate HR zones to return to frontend
    const hrZones = isRunningPlan ? this.calculateHrZones(context) : null;

    return {
      name: llmResponse.plan_name,
      sonsomo: mapRows(llmResponse.sonsomo),
      main: mapRows(llmResponse.main, isRunningPlan), // Running: skip DB match for protocol rows
      core: mapRows(llmResponse.core),
      mobility: mapRows(llmResponse.mobility ?? []),
      ai_reasoning: llmResponse.reasoning,
      weaknesses,
      basedOnTestId: test?.id ?? null,
      basedOnTestDate: test?.date ?? null,
      contraindications,
      ...(isRuleBased ? { isRuleBased: true, llmError } : {}),
      ...(request ? { request } : {}),
      ...(hrZones ? { hrZones } : {}),
    };
  }

  /**
   * Generate and immediately persist the plan to the DB.
   * Returns the saved TrainingPlan entity + AI metadata.
   */
  async generateAndSave(clientId: number, request?: AiPlanRequest): Promise<{
    plan: TrainingPlan;
    meta: Omit<AiPlanResult, 'sonsomo' | 'main' | 'core' | 'mobility' | 'name'>;
  }> {
    const result = await this.generateAiPlan(clientId, request);

    const values = JSON.stringify({
      sonsomo: result.sonsomo.map(this.toPlanRow),
      main: result.main.map(this.toPlanRow),
      core: result.core.map(this.toPlanRow),
      mobility: result.mobility.map(this.toPlanRow),
      dates: Array(8).fill(''),
    });

    // Auto-create new exercises that the AI suggested (with duplicate check)
    for (const row of [...result.sonsomo, ...result.main, ...result.core, ...result.mobility]) {
      if (row.isNew && row.exercise) {
        // Check if exercise already exists (case-insensitive)
        const existing = await this.exerciseRepo
          .createQueryBuilder('e')
          .where('LOWER(e.name) = LOWER(:name)', { name: row.exercise.trim() })
          .getOne();

        if (existing) {
          row.exerciseId = existing.id;
          row.isNew = false;
          this.logger.log(`Matched existing exercise: "${row.exercise}" → id=${existing.id}`);
        } else {
          const created = await this.exerciseRepo.save(
            this.exerciseRepo.create({
              name: row.exercise,
              published: 1,
              archive: 0,
            }),
          );
          row.exerciseId = created.id;
          row.isNew = false;
          this.logger.log(`Auto-created exercise: "${row.exercise}" → id=${created.id}`);
        }
      }
    }

    const plan = await this.planRepo.save(
      this.planRepo.create({
        clientId,
        values,
        name: result.name || 'KI-Trainingsplan',
        goal: result.ai_reasoning.substring(0, 1000),
      }),
    );

    return {
      plan,
      meta: {
        ai_reasoning: result.ai_reasoning,
        weaknesses: result.weaknesses,
        basedOnTestId: result.basedOnTestId,
        basedOnTestDate: result.basedOnTestDate,
        contraindications: result.contraindications,
      },
    };
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DATA LOADING
  // ═══════════════════════════════════════════════════════════════════════════

  private async loadClient(clientId: number): Promise<Client> {
    const client = await this.clientRepo.findOne({ where: { id: clientId } });
    if (!client) throw new NotFoundException(`Client ${clientId} nicht gefunden`);
    return client;
  }

  private async loadLatestTest(clientId: number): Promise<PerformanceTest | null> {
    return this.testRepo.findOne({
      where: { client_id: clientId },
      order: { date: 'DESC' },
    });
  }

  private async loadAnamnese(clientId: number): Promise<ClientAnamnese | null> {
    return this.anamneseRepo.findOne({
      where: { client_id: clientId },
    });
  }

  private async loadExerciseCatalog(): Promise<AiExerciseCatalog[]> {
    const exercises = await this.exerciseRepo.find({
      where: { archive: 0 },
      relations: ['group', 'subgroup'],
    });
    return exercises.map((e) => ({
      id: e.id,
      name: e.name,
      group: e.group?.name ?? null,
      subgroup: e.subgroup?.name ?? null,
      bodyRegion: e.bodyRegion ?? null,
      muscle: e.primaryMuscleGroup ?? null,
      joint: e.targetJoint ?? null,
      pattern: e.movementPattern ?? null,
    }));
  }

  private async loadLatestMetric(clientId: number): Promise<Metric | null> {
    try {
      return await this.metricRepo.findOne({
        where: { client_id: clientId },
        order: { date: 'DESC' },
      });
    } catch (err) {
      this.logger.warn(`Failed to load metric for client ${clientId}: ${err.message}`);
      return null;
    }
  }

  private async loadGoals(clientId: number): Promise<Goal[]> {
    try {
      return await this.goalRepo.find({
        where: { clientId },
      });
    } catch (err) {
      this.logger.warn(`Failed to load goals for client ${clientId}: ${err.message}`);
      return [];
    }
  }

  private async loadRecentReviews(clientId: number): Promise<Review[]> {
    try {
      // Load last 10 training sessions via raw query (Review→Training join)
      const reviews = await this.reviewRepo.query(
        `SELECT r.id, r.training_type, r.duration, r.kcal, r.heart_rate,
                r.feedback_emoticon, r.speed, r.distance
         FROM review r
         INNER JOIN training t ON t.id = r.training_id
         WHERE t.client_id = ?
         ORDER BY r.id DESC
         LIMIT 10`,
        [clientId],
      );
      return reviews;
    } catch (err) {
      this.logger.warn(`Failed to load reviews for client ${clientId}: ${err.message}`);
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ANALYSIS
  // ═══════════════════════════════════════════════════════════════════════════

  private identifyWeaknesses(test: PerformanceTest | null): AiWeakness[] {
    if (!test) return [];

    return Object.entries(TEST_BENCHMARKS)
      .filter(([key, bench]) => {
        const value = Number(test[key]) || 0;
        // Sprint: lower = better, skip entirely for weakness analysis
        if (key.startsWith('sprint_')) return false;
        // 0 or null = NOT TESTED → skip (don't treat as weakness)
        if (!value || value === 0) return false;
        return bench.min > 0 && value < bench.min;
      })
      .map(([key, bench]) => ({
        field: key,
        label: bench.label,
        value: Number(test[key]) || 0,
        benchmark: bench.min,
        deficit: Math.round((1 - (Number(test[key]) || 0) / bench.min) * 100),
        category: bench.category,
      }))
      .sort((a, b) => b.deficit - a.deficit);
  }

  private extractContraindications(anamnese: ClientAnamnese | null): string[] {
    if (!anamnese) return [];
    const result: string[] = [];

    // Disease flags
    for (const [field, label] of Object.entries(DISEASE_LABELS)) {
      if (anamnese[field] === 1) result.push(label);
    }

    // Injuries
    if (anamnese.injury) {
      const parts: string[] = [];
      if (anamnese.injury_type) parts.push(anamnese.injury_type);
      if (anamnese.injury_bodypart) parts.push(`Bereich: ${anamnese.injury_bodypart}`);
      if (anamnese.injury_chronic) parts.push('(chronisch)');
      result.push(`Verletzung: ${parts.join(', ') || 'ja'}`);
    }

    // Musculoskeletal
    if (anamnese.musculoskeletal_problems && anamnese.musculoskeletal_problems_description) {
      result.push(`Muskuloskelettale Probleme: ${anamnese.musculoskeletal_problems_description}`);
    }

    // Extract medical hints from comments field (often contains surgery info, chronic conditions)
    if (anamnese.comments) {
      const comments = anamnese.comments.toLowerCase();
      const medicalKeywords = [
        { pattern: /knie[\s-]?(op|operation|arthroskopie|tep|prothese)/i, label: 'Knie-OP' },
        { pattern: /kreuzband/i, label: 'Kreuzbandverletzung' },
        { pattern: /meniskus/i, label: 'Meniskusschaden' },
        { pattern: /bandscheib/i, label: 'Bandscheibenvorfall' },
        { pattern: /h[üu]ft[\s-]?(op|operation|tep|prothese)/i, label: 'Hüft-OP' },
        { pattern: /schulter[\s-]?(op|operation|arthroskopie)/i, label: 'Schulter-OP' },
        { pattern: /impingement/i, label: 'Schulter-Impingement' },
        { pattern: /achillessehne/i, label: 'Achillessehnen-Problem' },
        { pattern: /patella/i, label: 'Patella-Problem' },
        { pattern: /schwanger/i, label: 'Schwangerschaft' },
        { pattern: /osteoporo/i, label: 'Osteoporose' },
        { pattern: /arthro(se|sis)/i, label: 'Arthrose' },
        { pattern: /skoliose/i, label: 'Skoliose' },
        { pattern: /hernie/i, label: 'Hernie' },
      ];

      for (const { pattern, label } of medicalKeywords) {
        if (pattern.test(anamnese.comments) && !result.some((r) => r.toLowerCase().includes(label.toLowerCase()))) {
          result.push(`${label} (aus Kommentaren)`);
        }
      }
    }

    return result;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TRAINING TYPE PROMPT EXTENSIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /** Training-type-specific prompt blocks injected into the system prompt */
  private static readonly TRAINING_TYPE_PROMPTS: Record<AiTrainingType, string> = {
    ausdauer: `TRAININGSTYP: AUSDAUER
FOKUS: Cardio-Intervalle, Laufübungen, Seilspringen, HIIT-Zirkel.
- Sonsomo: Kurze Aktivierung, Seilspringen, Lauf-ABC
- Main: Zirkeltraining mit kurzen Pausen (30-60s), Intervall-Belastungen, Ausdauer-Kraftübungen mit hoher Wiederholungszahl (15-25 Rep)
- Core: Dynamische Core-Übungen mit Cardio-Anteil (Mountain Climbers, Plank Jacks)
- Mobility: Aktive Erholung, leichte Dehnungen, Atemübungen
Pulsbereich: 65-85% der max. Herzfrequenz. Sätze: 3-4×15-25 Rep oder Zeitintervalle (30-60s Arbeit / 15-30s Pause).`,

    kraft: `TRAININGSTYP: KRAFT
FOKUS: Maximalkraft und Hypertrophie, Compound-Lifts.
- Sonsomo: Gelenkspezifische Mobilisation, leichte Aktivierungsübungen
- Main: Compound-Lifts (Squat, Deadlift, Press, Row) + isolierte Übungen für identifizierte Schwächen. Schwere Gewichte, niedrige Wiederholungen.
- Core: Anti-Rotations- und Anti-Flexions-Übungen unter Last (Pallof Press, Farmer's Carry, Heavy Plank)
- Mobility: Gelenkmobilisation der belasteten Bereiche
Sätze: 4-5×5-8 Rep für Compound, 3×8-12 Rep für Isolation. Pausen: 90-180s zwischen Sätzen.`,

    propriozeptiv: `TRAININGSTYP: PROPRIOZEPTIV
FOKUS: Balance, Koordination, Sensorik, neuronale Ansteuerung.
- Sonsomo: ERWEITERT auf 4-6 Übungen! Balance Board, MFT Board, Slackline, Einbeinstand mit geschlossenen Augen, Barfuß-Übungen, Kurzfuß nach Janda
- Main: Instabile Untergründe (Bosu, Airex, Wackelbrett), unilaterale Übungen, kontralaterale Bewegungsmuster, Gleichgewichtsübungen mit kognitiver Doppelaufgabe (Dual-Task)
- Core: Stabilisierung auf instabilem Untergrund, Anti-Rotations-Übungen im Einbeinstand
- Mobility: CARs aller großen Gelenke, Sprunggelenk-Mobilisation, Fußgewölbe-Arbeit
BEVORZUGE: Barfuß-Training, propriozeptive Geräte (MFT, Balance Board, Slackline, Airex), Einbeinstand-Varianten, geschlossene-Augen-Übungen.`,

    mental_health: `TRAININGSTYP: MENTAL HEALTH
FOKUS: Atemübungen, Yoga-Elemente, Meditation, Flow-Bewegungen, therapeutisches Klettern, Slackline, propriozeptives Training zur neuronalen Stimulation und Flow-Erlebnis.
- Sonsomo: Atemübungen (Box Breathing, 4-7-8 Technik), achtsame Körperwahrnehmung, langsame Barfuß-Balanceübungen, Slackline für Achtsamkeit und Flow
- Main: Flow-Bewegungen (Animal Flows, Yoga-Sequenzen), therapeutisches Klettern (Bouldern, Traversieren), Slackline-Training, propriozeptive Übungen mit bewusster neuronaler Stimulation, moderate Kraftübungen mit Fokus auf Körperwahrnehmung. Langsames kontrolliertes Tempo, Fokus auf Bewegungsqualität statt Intensität.
- Core: Yoga-basierte Core-Übungen (Boat Pose, Plank-Flow), Atemgesteuerte Stabilisation, Pilates-Elemente
- Mobility: Yoga-Flows, Meditation in Dehnpositionen, Faszien-Release, Progressive Muskelentspannung
INTENSITÄT: Moderat (RPE 4-6/10). KEINE Maximalkraft, KEIN HIIT. Puls unter 70% HFmax. Fokus auf Parasympathikus-Aktivierung und Flow-Erlebnis.
BEVORZUGE: Slackline, Kletterwand/Bouldern, Yoga-Matten, Faszienrollen, propriozeptive Geräte für neuronale Stimulation.`,

    athletik: `TRAININGSTYP: ATHLETIK
FOKUS: Explosivkraft, Plyometrie, Agility, sportartspezifische Leistung.
- Sonsomo: Dynamische Mobilisation, Lauf-ABC, Sprunggelenk-Aktivierung, Reaktionsübungen
- Main: Plyometrische Übungen (Box Jumps, Depth Jumps, Bounding), Sprint-Drills, Agility-Leiter, Medizinball-Würfe, olympische Lifts (Power Clean, Push Press), Reaktionstraining
- Core: Explosive Core-Übungen (Med Ball Slams, Rotational Throws, Hanging Leg Raises)
- Mobility: Dynamische Dehnungen, Hip Opener, Sprunggelenk-Mobilisation
Sätze: 3-5×3-6 Rep für Explosivkraft, 4-6×10-20m für Sprints. Pausen: 120-180s (vollständige Erholung). Power-Übungen IMMER am Anfang (frisch).`,

    schnelligkeit: `TRAININGSTYP: SCHNELLIGKEIT
FOKUS: Sprint-Intervalle, Reaktionstraining, Frequenzübungen, maximale Geschwindigkeit, Barfußtraining zur Stärkung der Fußmuskulatur und Verbesserung der Feinmotorik, Propriozeptives Training zur Verbesserung der neuronalen Ansteuerung und Schnelligkeit, Barfuß Lauf-ABC.
- Sonsomo: Barfuß-Training! Kurzfuß nach Janda, Zehengreifen, Fußgewölbe-Aktivierung, Barfuß Lauf-ABC (Kniehebelauf, Anfersen, Skippings, Fußgelenksarbeit barfuß), propriozeptive Übungen für neuronale Ansteuerung (Einbeinstand, Reaktionsbalance)
- Main: Sprint-Intervalle (10-40m), Frequenzsprints (kurze Distanz, maximale Schrittfrequenz), Reaktionssprints (auf Signal), Agility-Drills, Plyometrie für Schnellkraft (Pogo Hops, Single Leg Bounds), Tapping-Übungen (Schnelle Fußkontakte), Koordinationsleiter
- Core: Explosive Anti-Rotations-Übungen, Sprint-spezifische Core-Stabilität (Pallof Press dynamisch, Dead Bug schnell)
- Mobility: Hüftbeuger-Mobilisation (essentiell für Sprintschrittlänge), Sprunggelenk-Mobilisation, aktive Wadendehnung
BEVORZUGE: Barfuß-Training, Koordinationsleiter, Springseil für Frequenz, freie Sprintfläche.
WICHTIG: Schnelligkeitsübungen IMMER im erholten Zustand durchführen (am Anfang des Trainings). Pausen: 180-300s zwischen Maximalsprints.`,
  };

  /** Duration-based exercise count mapping per section */
  private static readonly DURATION_MAPPING: Record<number, { sonsomo: string; main: string; core: string; mobility: string }> = {
    30: { sonsomo: '2', main: '3-4', core: '1-2', mobility: '1' },
    45: { sonsomo: '3', main: '4-5', core: '2-3', mobility: '2' },
    60: { sonsomo: '3-4', main: '5-7', core: '3', mobility: '2-3' },
  };

  /** Equipment labels for the prompt */
  private static readonly EQUIPMENT_LABELS: Record<string, string> = {
    mft: 'MFT Board (propriozeptives Balance-Board)',
    slackline: 'Slackline (Balance und Koordination)',
    springseil: 'Springseil (Koordination, Cardio, Frequenztraining)',
    kettlebell: 'Kettlebell (funktionelles Krafttraining, Swings, Cleans, Snatches)',
    ringe: 'Gymnastikringe / Suspension Trainer (Bodyweight-Kraft, Instabilität, Pull/Push)',
  };

  // ═══════════════════════════════════════════════════════════════════════════
  // AUSDAUER / RUNNING — Intensity zone prompts + HR zone calculation
  // ═══════════════════════════════════════════════════════════════════════════

  /** Ausdauer intensity zone definitions with running-specific prompts */
  private static readonly AUSDAUER_INTENSITY_PROMPTS: Record<AiAusdauerIntensity, {
    label: string;
    hrPercent: [number, number]; // %HRR range
    cadence: string;
    protocol: string;
  }> = {
    regenerativ: {
      label: 'Regenerativ (Zone 1 — Leicht)',
      hrPercent: [50, 60],
      cadence: '~155-160 spm',
      protocol: `AUSDAUER-INTENSITÄT: REGENERATIV (Zone 1)
FOKUS: Aktive Erholung, lockerer Dauerlauf, Fettverbrennung.
PROTOKOLL:
- Aufwärmen: 5 min sehr lockeres Gehen/Joggen
- Hauptteil: Kontinuierlicher lockerer Dauerlauf, Konversationstempo, gleichmässiges Tempo
- Cool-down: 5 min Auslaufen, Gehen
TEMPO: Sehr locker — der Kunde sollte sich jederzeit unterhalten können.
KEINE Intervalle, KEINE Tempowechsel. Rein regenerativ.
KADENZ: ~155-160 Schritte pro Minute.`,
    },
    allgemeine: {
      label: 'Allgemeine Ausdauer (Zone 2 — Mittel)',
      hrPercent: [60, 70],
      cadence: '~160-165 spm',
      protocol: `AUSDAUER-INTENSITÄT: ALLGEMEINE AUSDAUER / GA1 (Zone 2)
FOKUS: Grundlagenausdauer, aerobe Basis aufbauen, Ausschöpfung steigern.
PROTOKOLL:
- Aufwärmen: 5 min lockeres Einlaufen, Steigerung auf Zieltempo
- Hauptteil: Kontinuierlicher Dauerlauf im GA1-Bereich. Gleichmässiges moderates Tempo über die gesamte Dauer.
- Cool-down: 5 min lockeres Auslaufen
TEMPO: Moderat — leicht anstrengend, aber noch gut durchhaltbar. Atemrhythmus 3:3 oder 4:4.
KEINE harten Intervalle. Gleichmässiger Dauerlauf.
KADENZ: ~160-165 Schritte pro Minute.`,
    },
    spezial: {
      label: 'Speziale Ausdauer (Zone 3 — Hart)',
      hrPercent: [70, 80],
      cadence: '~165-172 spm',
      protocol: `AUSDAUER-INTENSITÄT: SPEZIALE AUSDAUER / TEMPO (Zone 3)
FOKUS: Ermüdungsresistenz steigern, Laktat-Clearance verbessern, Tempo-Intervalle.
PROTOKOLL:
- Aufwärmen: 5 min lockeres Einlaufen (Zone 1-2)
- Hauptteil: 3-4 längere Intervalle (6-10 min) im Tempobereich, dazwischen jeweils 2-3 min aktive Pause (lockeres Joggen Zone 1)
- Cool-down: 5 min lockeres Auslaufen
TEMPO: Anstrengend — Atemrhythmus 2:2, Sprechen nur noch in kurzen Sätzen möglich.
KADENZ: ~165-172 Schritte pro Minute.
BEISPIEL-STRUKTUR: 5' Aufwärmen → 3×8 min Tempo (2 min Pause) → 5' Cool-down`,
    },
    schwelle: {
      label: 'Schwellentraining (Zone 4 — Sehr Hart)',
      hrPercent: [80, 90],
      cadence: '~172-178 spm',
      protocol: `AUSDAUER-INTENSITÄT: SCHWELLENTRAINING / THRESHOLD (Zone 4)
FOKUS: Anaerobe Schwelle verschieben, Potenzial steigern, Leistungsfähigkeit erhöhen.
PROTOKOLL:
- Aufwärmen: 5 min lockeres Einlaufen (Zone 1-2), danach 2-3 min Steigerungen
- Hauptteil: 4-6 Intervalle (3-5 min) an der anaeroben Schwelle, dazwischen jeweils 3 min aktive Pause (lockeres Joggen Zone 1-2)
- Cool-down: 5 min lockeres Auslaufen
TEMPO: Sehr anstrengend — Sprechen nur noch in einzelnen Wörtern möglich. 4×4-Minuten-Methode (z.B. nach norwegischem Modell).
KADENZ: ~172-178 Schritte pro Minute.
BEISPIEL-STRUKTUR: 5' Aufwärmen → 4×4 min Schwelle (3 min Pause) → 5' Cool-down`,
    },
    hiit: {
      label: 'Hochintensives Intervalltraining (Zone 5 — Maximal)',
      hrPercent: [90, 100],
      cadence: '~178-185+ spm',
      protocol: `AUSDAUER-INTENSITÄT: HIIT / VO2max (Zone 5)
FOKUS: Maximale Sauerstoffaufnahme (VO2max) verbessern, anaerobe Kapazität, Spitzenleistung.
PROTOKOLL:
- Aufwärmen: 5-8 min progressives Einlaufen (Zone 1→3), 2-3 kurze Steigerungsläufe
- Hauptteil: 6-10 kurze hochintensive Intervalle (30s-2 min) mit nahezu maximaler Belastung, dazwischen vollständige Erholung (2-3 min lockeres Gehen/Joggen)
- Cool-down: 5-8 min sehr lockeres Auslaufen
TEMPO: Maximal — alles geben, Sprint-ähnlich. Vollständige Erholung zwischen Intervallen essenziell!
KADENZ: ~178-185+ Schritte pro Minute.
BEISPIEL-STRUKTUR: 8' Aufwärmen → 8×1 min Sprint (2 min Pause) → 8' Cool-down
WICHTIG: Nur für gut trainierte Kunden. Bei Anfängern → kürzere/weniger Intervalle.`,
    },
  };

  /**
   * Calculate HR zones using the Karvonen formula:
   * Target HR = HRrest + (intensity% × (HRmax - HRrest))
   */
  private calculateHrZones(context: AiPromptContext): AiHrZones | null {
    const maxHr = context.client.maxHeartRate;
    if (!maxHr) return null;

    const restHr = context.bodyComposition?.calmPulse;
    if (!restHr) return null; // No resting HR → force RPE fallback (safer than guessing)
    const hrr = maxHr - restHr;

    // Zone boundaries: upper = next zone lower - 1 (no overlap, convention like Garmin/Polar)
    return {
      restHr,
      maxHr,
      zone1: [Math.round(restHr + 0.50 * hrr), Math.round(restHr + 0.60 * hrr) - 1],
      zone2: [Math.round(restHr + 0.60 * hrr), Math.round(restHr + 0.70 * hrr) - 1],
      zone3: [Math.round(restHr + 0.70 * hrr), Math.round(restHr + 0.80 * hrr) - 1],
      zone4: [Math.round(restHr + 0.80 * hrr), Math.round(restHr + 0.90 * hrr) - 1],
      zone5: [Math.round(restHr + 0.90 * hrr), maxHr],
    };
  }

  /** Build the training-type / duration / equipment extension for the system prompt */
  private buildRequestPromptBlock(request?: AiPlanRequest, context?: AiPromptContext): string {
    if (!request) return '';

    const blocks: string[] = [];
    const isRunningPlan = request.trainingType === 'ausdauer' && request.ausdauerIntensity;

    // 1. Training type block — running plans get intensity-specific prompt instead
    if (isRunningPlan) {
      const zoneConfig = AiPlanService.AUSDAUER_INTENSITY_PROMPTS[request.ausdauerIntensity!];
      blocks.push(zoneConfig.protocol);

      // Inject calculated HR zones if client data available
      if (context) {
        const hrZones = this.calculateHrZones(context);
        if (hrZones) {
          const zoneKey = request.ausdauerIntensity!;
          const zoneMap: Record<AiAusdauerIntensity, keyof Pick<AiHrZones, 'zone1' | 'zone2' | 'zone3' | 'zone4' | 'zone5'>> = {
            regenerativ: 'zone1', allgemeine: 'zone2', spezial: 'zone3', schwelle: 'zone4', hiit: 'zone5',
          };
          const activeZone = hrZones[zoneMap[zoneKey]];
          blocks.push(
            `HERZFREQUENZ-ZONEN (Karvonen-Formel, Ruhepuls ${hrZones.restHr} bpm, HFmax ${hrZones.maxHr} bpm):\n` +
            `- Zone 1 (Regenerativ): ${hrZones.zone1[0]}-${hrZones.zone1[1]} bpm\n` +
            `- Zone 2 (GA1): ${hrZones.zone2[0]}-${hrZones.zone2[1]} bpm\n` +
            `- Zone 3 (Tempo): ${hrZones.zone3[0]}-${hrZones.zone3[1]} bpm\n` +
            `- Zone 4 (Schwelle): ${hrZones.zone4[0]}-${hrZones.zone4[1]} bpm\n` +
            `- Zone 5 (HIIT): ${hrZones.zone5[0]}-${hrZones.zone5[1]} bpm\n` +
            `\nAKTIVE ZONE FÜR DIESES TRAINING: ${activeZone[0]}-${activeZone[1]} bpm\n` +
            `Gib die Ziel-Herzfrequenz im "position"-Feld jeder Laufzeile an (z.B. "Zone 2: ${activeZone[0]}-${activeZone[1]} bpm").`,
          );
        } else {
          blocks.push(
            'HERZFREQUENZ: Keine HFmax-Daten vorhanden. Verwende subjektive Belastungsskala (RPE) und Borg-Skala statt absoluter HR-Werte. ' +
            `Gib RPE-Werte im "position"-Feld an (z.B. "RPE 4-5 / Locker").`,
          );
        }
      }

      // Running-specific output format — adapt examples based on HR availability
      const hrZonesAvailable = context ? this.calculateHrZones(context) : null;
      const posExample = hrZonesAvailable
        ? `Herzfrequenz-Zone (z.B. "Zone 2: ${hrZonesAvailable.zone2[0]}-${hrZonesAvailable.zone2[1]} bpm")`
        : `RPE-Wert (z.B. "RPE 4-5 / Locker")`;
      blocks.push(
        `LAUFPLAN-FORMAT: Der "main"-Bereich enthält NUR Laufprotokoll-Zeilen:\n` +
        `- "exercise_name": Phasenname (z.B. "Aufwärmen", "GA1 Dauerlauf", "Tempo-Intervall", "Aktive Pause", "Cool-down")\n` +
        `- "exercise_id": null (Laufphasen sind keine DB-Übungen)\n` +
        `- "device": "Laufband" oder "Outdoor"\n` +
        `- "position": ${posExample}\n` +
        `- "weight": Tempo/Pace (z.B. "8.5 km/h" oder "5:30 min/km")\n` +
        `- "sets": Dauer/Struktur (z.B. "20 min", "4×4 min", "3×8 min mit 2 min Pause")\n` +
        `\nDie Sonsomo-Sektion enthält 2-3 Lauf-ABC/Aufwärm-Übungen (aus dem Katalog).\n` +
        `Die Core-Sektion enthält 1-2 laufspezifische Core-Übungen (aus dem Katalog).\n` +
        `Die Mobility-Sektion enthält 1-2 laufspezifische Dehnübungen (aus dem Katalog).`,
      );
    } else {
      const typePrompt = AiPlanService.TRAINING_TYPE_PROMPTS[request.trainingType];
      if (typePrompt) {
        blocks.push(typePrompt);
      }
    }

    // 2. Duration block
    if (request.duration) {
      if (isRunningPlan) {
        // Running plans: duration = total training time, not exercise counts
        blocks.push(
          `TRAININGSDAUER: ${request.duration} Minuten (Gesamtzeit inkl. Aufwärmen + Cool-down)\n` +
          `Passe das Laufprotokoll an die verfügbare Zeit an. Aufwärmen ~5 min, Cool-down ~5 min, Rest = Hauptteil.\n` +
          `- Sonsomo: 2-3 Aufwärm-Übungen (vor dem Laufen)\n` +
          `- Core: 1-2 Übungen\n` +
          `- Mobility: 1-2 Übungen`,
        );
      } else {
        const mapping = AiPlanService.DURATION_MAPPING[request.duration];
        if (mapping) {
          blocks.push(
            `TRAININGSDAUER: ${request.duration} Minuten\n` +
            `Passe die Übungsanzahl an die Dauer an:\n` +
            `- Sonsomo: ${mapping.sonsomo} Übungen\n` +
            `- Main: ${mapping.main} Übungen\n` +
            `- Core: ${mapping.core} Übungen\n` +
            `- Mobility: ${mapping.mobility} Übungen\n` +
            `Halte den Plan kompakt — lieber weniger Übungen mit guter Qualität als zu viele.`,
          );
        }
      }
    } else {
      blocks.push(
        'TRAININGSDAUER: Frei — wähle die optimale Übungsanzahl basierend auf dem Fitnesslevel und den Zielen des Kunden.',
      );
    }

    // 3. Equipment block
    if (request.equipment && request.equipment.length > 0) {
      const labels = request.equipment
        .map((e) => AiPlanService.EQUIPMENT_LABELS[e] ?? e)
        .join(', ');
      blocks.push(
        `VERFÜGBARE GERÄTE: ${labels}\n` +
        `BEVORZUGE diese Geräte bei der Übungsauswahl. Integriere sie aktiv in den Plan — ` +
        `mindestens 2-3 Übungen sollten die angegebenen Geräte nutzen. ` +
        `Gib das Gerät im "device"-Feld der jeweiligen Übung an.`,
      );
    } else {
      blocks.push(
        'GERÄTE: Frei — wähle die optimalen Geräte basierend auf den Übungen und dem Kundenprofil.',
      );
    }

    return '\n\n' + blocks.join('\n\n');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LLM CALL — supports Groq and Anthropic
  // ═══════════════════════════════════════════════════════════════════════════

  /** Shared system prompt — includes optional training type/duration/equipment blocks */
  private buildSystemPrompt(request?: AiPlanRequest, context?: AiPromptContext): string {
    return `Du bist ein erfahrener Sportwissenschaftler und Personal Trainer.
Deine Aufgabe: Erstelle einen individualisierten Trainingsplan basierend auf den Leistungstest-Ergebnissen, der medizinischen Anamnese, der Körperzusammensetzung, den Kundenzielen und der Trainingshistorie des Kunden.

WICHTIGE REGELN:
1. KONTRAINDIKATIONEN STRIKT BEACHTEN: Wenn der Kunde Verletzungen hat, wähle KEINE Übungen die das verletzte Gelenk/den verletzten Bereich belasten.
   - Knie-Verletzung → KEINE Squats, Lunges, Ausfallschritte, Sprünge, tiefe Kniebeugen
   - Patellasehne (Jumpers Knee) → KEINE Sprünge, KEINE tiefe Kniebeugen, KEINE plyometrischen Übungen. Stattdessen: Exzentrische Spanish Squats, Exzentrische Step-Downs, isometrisches Wandsitzen, Hamstring-Kräftigung (Nordics). Exzentrische Kniestreckerkraft gezielt aufbauen.
   - Rücken/LWS-Probleme → KEINE schweren Deadlifts, Hyperextensions unter Last, Übungen mit hoher axialer Belastung
   - Schulter-Verletzung/Impingement → KEINE Überkopf-Druckübungen, weites Bankdrücken, Handstände, Front Lever, Back Lever, Lock-Off Holds, Military Press, Push Press. Stattdessen: Scapula-Stabilisation, Rotatorenmanschetten-Übungen, Facepulls, horizontales Rudern.
   - Schwangerschaft (ab SSW 16) → KEINE Rückenlage-Übungen (Vena-cava-Syndrom-Risiko: Hollow Body Hold, Crunch, Sit-Up, Dragon Flag, Bankdrücken). KEINE Sprünge/High-Impact, KEINE Maximalkraft, KEINE Pressatmung/Valsalva. Stattdessen: Seitlage-Core, Vierfüßlerstand, Pallof Press, Beckenboden-Übungen, Hüftmobilisation. Gewichte moderat halten, Puls unter 150 bpm.
   - Achillessehnen-Tendinopathie → KEINE Sprünge, KEINE Plyometrie, KEINE High-Impact-Läufe (Drop Jump, Pogo Hops, Box Jump, Sprint). Stattdessen: Exzentrische Calf Raises (Alfredson-Protokoll), Wadenheben barfuß, Sprunggelenk-Mobilisation, Fußmuskulatur-Training. Belastung progressiv steigern.
   - BWS-Kyphose / Rundrücken → IMMER Thorakale Rotation und BWS-Extension einplanen. Bevorzuge: Thorakale Rotation, Shoulder CARs, Ring Face Pull, Band Pull-Apart, Rudern. Fokus auf Scapula-Retraktion und Brustöffnung.
   Sicherheit geht IMMER vor Leistungsoptimierung.
2. SCHWIERIGKEITSGRAD ANPASSEN: Passe den Schwierigkeitsgrad der Übungen an das tatsächliche Leistungsniveau des Kunden an. Wenn der Kunde z.B. 0 Klimmzüge schafft, wähle KEINE fortgeschrittenen Übungen wie Front Lever, Muscle-Up, L-Sit. Beginne mit Regressionen (z.B. Negativklimmzüge, Ruderübungen, Plankvarianten).
3. SCHWÄCHEN VOLLSTÄNDIG ABDECKEN: Adressiere JEDE identifizierte Schwäche aus dem Leistungstest mit mindestens einer gezielten Übung. Prüfe am Ende, ob alle Schwächen im Plan vertreten sind. WICHTIG: Wenn ein Test-Parameter als "notTested" markiert ist, wurde er NICHT durchgeführt. Behandle fehlende Tests NICHT als Schwäche — erwähne sie nur als "nicht getestet" im Reasoning.
4. VERFÜGBARE ÜBUNGEN BEVORZUGEN: Wähle Übungen aus dem mitgelieferten Katalog (mit exercise_id). Der Katalog enthält pro Übung: Muskelgruppe, Zielgelenk und Bewegungsmuster (Push/Pull/Squat/Hinge/Plyo/Static/etc.). Nutze diese Metadaten für eine präzise Übungsauswahl. Nur wenn keine passende Übung im Katalog existiert, schlage eine neue vor (exercise_id: null).
5. STRUKTUR:
   - "sonsomo" (Aufwärmen/Sensomotorik): 2-4 Übungen. FOKUS: Propriozeptives Training, Koordination und Fußmuskulatur. ZIELE: (1) Propriorezeptoren aktivieren und verbessern — Einbeinstand, Balance Board, instabiler Untergrund, Augen-geschlossen-Varianten. (2) Neuronales Nervensystem aktivieren — Aufmerksamkeit, Achtsamkeit, den Kunden bewusst ins Hier-und-Jetzt bringen. (3) Koordinative Herausforderungen — Seilspringen, Reaktionsübungen, kontralaterale Bewegungen. (4) Fußmuskulatur stärken — Barfuß-Übungen, Kurzfuß nach Janda, Zehenarbeit, Fußgewölbe-Aktivierung. BEVORZUGE: Barfuß-Übungen, Balance Board, Einbeinstand, Slackline, Seilspringen, Short Foot Exercise, MFT Board. VERMEIDE: Klassische Dehnübungen, passives Aufwärmen, Scapula- oder Schulter-Übungen (gehören in main/core). Die Sonsomo-Phase ist REIN propriozeptiv und koordinativ.
   - "main" (Haupttraining): 4-6 Übungen für die identifizierten Schwächen
   - "core" (Core/Rumpf): 2-3 Übungen für Rumpfstabilität
   - "mobility" (Mobilität/Cool-Down): 2-3 Übungen. FOKUS: Aktive Beweglichkeit, CARs (Controlled Articular Rotations), Faszien-Release, Dehnübungen. ZIELE: (1) Bewegungsumfang (ROM) erhalten und verbessern. (2) Verkürzte Muskelketten adressieren — besonders Hüftbeuger bei sitzenden Berufen. (3) Gelenke durch volle ROM führen (CARs). BEVORZUGE: CARs (Hip, Shoulder, Spine, Ankle), aktive Dehnungen, PNF-Stretching, Foam Rolling, Faszien-Übungen. VERMEIDE: Statisches Dehnen ohne vorherige Aktivierung.
6. GEWICHT/BELASTUNG: Gib realistische Startgewichte basierend auf der Körperzusammensetzung und dem Leistungsniveau an. Trenne Sätze/Wiederholungen (sets) und Gewicht (weight). Berücksichtige das Körpergewicht bei Eigengewichtsübungen.
7. KÖRPERZUSAMMENSETZUNG BERÜCKSICHTIGEN: Nutze die Körperzusammensetzungsdaten (Gewicht, Körperfett%, BCM, Bauchumfang) für die Belastungssteuerung. Hoher Körperfettanteil → mehr metabolische Übungen einbauen. Niedrige BCM → Fokus auf Muskelaufbau.
8. BLUTDRUCK & RUHEPULS BEACHTEN: Bei erhöhtem Blutdruck (sys > 140 oder dia > 90) oder hohem Ruhepuls (> 80 bpm) → KEINE maximalen Belastungen, KEINE Pressatmung, moderates Tempo bevorzugen.
9. KUNDENZIELE PRIORISIEREN: Berücksichtige die spezifischen Ziele des Kunden (z.B. Muskelaufbau, Schmerzreduktion, Wettkampfvorbereitung). Die Ziele bestimmen die Trainingsausrichtung.
10. TRAININGSHISTORIE EINBEZIEHEN: Nutze die letzten Trainingseinheiten für die Progression. Wenn der Kunde regelmäßig trainiert → anspruchsvollere Übungen. Wenn die Herzfrequenz bei Trainings konstant hoch war → Intensität anpassen. Emoticon-Feedback (😀=leicht, 😐=mittel, 😫=hart) zeigt die subjektive Belastung.
11. LIFESTYLE-KONTEXT: Berücksichtige den Beruf (sitzend → mehr Mobilität, körperlich → weniger Volumen), Schlafqualität und sportliche Vorbelastung bei der Plangestaltung.
12. PUSH/PULL-BALANCE & MUSKEL-ANTAGONISTEN: Stelle sicher, dass der Plan muskulär ausbalanciert ist. Nutze die Muskelreferenz unten:
    - Trainiere nie nur Agonisten ohne Antagonisten (z.B. Brust ohne Rücken, Quadriceps ohne Hamstrings)
    - Bei Verletzungen: Stärke den Antagonisten des verletzten Bereichs (z.B. Knie-Verletzung → Hamstrings & Gluteus kräftigen)
    - Berücksichtige die Gelenkzuordnung der Muskeln bei Kontraindikationen (Schulter-Verletzung → vermeide ALLE Muskeln die das Schultergelenk belasten)
13. SPRACHE: Antworte auf Deutsch.

MUSKEL-REFERENZ (Agonist/Antagonist-Beziehungen):
OBERKÖRPER:
- Pectoralis major (Brust): Push|Schulter → Ago: Latissimus, Teres major, Deltoideus ant → Ant: Trapezius, Deltoideus post, Infraspinatus
- Latissimus dorsi (breiter Rücken): Pull|Schulter → Ago: Pectoralis major, Triceps, Teres major → Ant: Deltoideus ant, Biceps, Infraspinatus, Teres minor
- Deltoideus anterior (vordere Schulter): Push|Schulter → Ago: Pectoralis, Biceps, Coracobrachialis → Ant: Deltoideus post, Latissimus, Teres major
- Deltoideus medial (seitl. Schulter): Push|Schulter → Ago: Deltoideus ant, Supraspinatus → Ant: Pectoralis major, Latissimus
- Deltoideus posterior (hintere Schulter): Pull|Schulter → Ago: Latissimus, Teres major, Infraspinatus → Ant: Deltoideus ant, Pectoralis, Biceps
- Trapezius (Nacken/oberer Rücken): Pull|Schulter → desc: hebt Scapula, trans: retrahiert Scapula, asc: senkt Scapula
- Rhomboideus (Schulterblatt-Retraktion): Pull|Schulter → Ago: Trapezius, Levator scapulae → Ant: Pectoralis minor, Serratus anterior
- Serratus anterior (Sägezahnmuskel): Push|Schulter → Ago: Trapezius → Ant: Rhomboideus, Levator scapulae
- Biceps brachii: Pull|Ellenbogen+Schulter → Ago: Coracobrachialis, Deltoideus ant → Ant: Triceps, Deltoideus post
- Rotatorenmanschette: Schulter-Stabilisation → Infraspinatus (Außenrotation) + Supraspinatus (Abduktion) + Subscapularis (Innenrotation) + Teres minor (Außenrotation)
RUMPF/CORE:
- Rectus abdominis (gerader Bauch): Flexion/Stabilisation|LWS → Ago: Obliquus ext/int, Transversus, Psoas major → Ant: Erector spinae, Quadratus lumborum
- Obliquus ext/int (seitl. Bauch): Rotation/Lateralflexion → Ago: Rectus abdominis, Transversus → Ant: Erector spinae, Quadratus lumborum
- Erector spinae (Rückenstrecker): Extension|Wirbelsäule+Hüfte → Ago: Gluteus maximus, Hamstrings → Ant: Bauchmuskulatur, Rectus femoris
- Quadratus lumborum (tiefer Rücken): Lateralflexion → Ago: Erector spinae → Ant: Obliquus ext/int
UNTERKÖRPER:
- Gluteus maximus (großer Gesäß): Push|Hüfte → Ago: Hamstrings, Adductor magnus → Ant: Iliopsoas, Psoas major, Gluteus medius, TFL
- Gluteus medius/minimus (Hüft-Abduktion): Pull|Hüfte → Ago: TFL, Gluteus maximus → Ant: Adduktoren (longus, magnus, brevis)
- Quadriceps (Kniestrecker): Push|Knie+Hüfte → Rectus femoris + Vastus lat/med/int → Ant: Hamstrings (Biceps femoris, Semitendinosus, Semimembranosus)
- Hamstrings (Kniebeuger/Hüftstrecker): Pull|Knie+Hüfte → Biceps femoris + Semitendinosus + Semimembranosus → Ant: Quadriceps, Iliopsoas
- Iliopsoas (Hüftbeuger): Pull|Hüfte → Ago: Rectus femoris, TFL, Sartorius → Ant: Gluteus maximus, Hamstrings, Gluteus medius
- Adduktoren (Schenkel-Adduktion): Pull|Hüfte → Ago: Pectineus, Gracilis → Ant: Gluteus maximus, Gluteus medius, TFL
- Gastrocnemius+Soleus (Wade): Push|Knie+Sprunggelenk → Plantarflexion → Ant: Tibialis anterior, Ext. digitorum longus
- Tibialis anterior (Schienbein): Pull|Sprunggelenk → Dorsalextension → Ant: Fibularis longus, Triceps surae
FUß:
- Intrinsische Fußmuskulatur: Stabilisation|Sprunggelenk → Kurzfuß, Zehengreifen, Gewölbe-Aktivierung
- Fibularis longus (Pronation): Push|Sprunggelenk → Ant: Tibialis anterior
- Tibialis posterior (Supination): Push|Sprunggelenk → Ant: Ext. digitorum/hallucis longus

${this.buildRequestPromptBlock(request, context)}

Antworte AUSSCHLIESSLICH mit validem JSON in genau diesem Format:
{
  "plan_name": "Kurzer Planname (z.B. 'Kraft & Stabilität Phase 1')",
  "sonsomo": [
    { "exercise_name": "Name", "exercise_id": 123, "device": "Gerät", "position": "Position/Ausführung", "sets": "3×12", "weight": "20kg" }
  ],
  "main": [ ... ],
  "core": [ ... ],
  "mobility": [ ... ],
  "reasoning": "2-4 Sätze die erklären WARUM dieser Plan gewählt wurde, welche Schwächen adressiert werden, welche Kontraindikationen berücksichtigt wurden, und wie Körperzusammensetzung/Ziele/Trainingshistorie eingeflossen sind. Erwähne auch welche Agonist/Antagonist-Paare berücksichtigt wurden."
}`;
  }

  private buildUserPrompt(context: AiPromptContext): string {
    // Build a compact prompt. Exercise catalog as compact lines to save tokens.
    // Strip null/empty values to reduce token usage.
    const { exerciseCatalog, ...rest } = context;

    const stripNulls = (obj: any): any => {
      if (Array.isArray(obj)) return obj.map(stripNulls);
      if (obj && typeof obj === 'object') {
        return Object.fromEntries(
          Object.entries(obj)
            .filter(([, v]) => v !== null && v !== undefined && v !== '')
            .map(([k, v]) => [k, stripNulls(v)]),
        );
      }
      return obj;
    };

    const catalogLines = exerciseCatalog
      .map((e) => {
        const parts = [String(e.id), e.name];
        if (e.group) parts.push(e.group);
        if (e.muscle) parts.push(e.muscle);
        if (e.joint) parts.push(e.joint);
        if (e.pattern) parts.push(e.pattern);
        return parts.join('|');
      })
      .join('\n');

    // Build request summary for the user prompt (reinforces system prompt)
    const requestSummary = context.planRequest
      ? [
          '',
          'TRAINER-VORGABEN:',
          `- Trainingstyp: ${context.planRequest.trainingType.toUpperCase()}`,
          ...(context.planRequest.ausdauerIntensity
            ? [`- Ausdauer-Intensität: ${context.planRequest.ausdauerIntensity.toUpperCase()} (${
                AiPlanService.AUSDAUER_INTENSITY_PROMPTS[context.planRequest.ausdauerIntensity]?.label ?? context.planRequest.ausdauerIntensity
              })`]
            : []),
          `- Dauer: ${context.planRequest.duration ? context.planRequest.duration + ' Minuten' : 'Frei (KI entscheidet)'}`,
          `- Geräte: ${context.planRequest.equipment?.length ? context.planRequest.equipment.join(', ') : 'Frei (KI wählt)'}`,
          '',
        ].join('\n')
      : '';

    return [
      'Erstelle einen Trainingsplan für folgenden Kunden:',
      '',
      JSON.stringify(stripNulls(rest), null, 2),
      requestSummary,
      'VERFÜGBARE ÜBUNGEN (id|name|gruppe|muskel|gelenk|pattern):',
      catalogLines,
      '',
      'Antworte NUR mit dem JSON-Objekt, kein Markdown, kein Kommentar.',
    ].join('\n');
  }

  private buildPromptContext(
    client: Client,
    test: PerformanceTest | null,
    anamnese: ClientAnamnese | null,
    weaknesses: AiWeakness[],
    exercises: AiExerciseCatalog[],
    metric: Metric | null,
    goals: Goal[],
    recentReviews: Review[],
    request?: AiPlanRequest,
  ): AiPromptContext {
    return {
      planRequest: request ?? undefined,
      client: {
        id: client.id,
        name: `${client.firstname} ${client.lastname}`,
        birthdate: client.birthday ?? undefined,
        gender: client.gender ?? undefined,
        minHeartRate: client.minHeartRate ?? undefined,
        maxHeartRate: client.maxHeartRate ?? undefined,
      },
      anamnese: {
        injuries: anamnese?.injury_type ?? null,
        injuryBodypart: anamnese?.injury_bodypart ?? null,
        injuryChronic: anamnese?.injury_chronic === 1,
        diseases: this.extractContraindications(anamnese),
        musculoskeletalProblems: anamnese?.musculoskeletal_problems_description ?? null,
        goals: anamnese?.goals ?? null,
        sportarts: anamnese?.sportarts ?? null,
        sportartsIntensity: anamnese?.sportarts_intencity ?? null,
        profession: anamnese?.profession ?? null,
        activities: anamnese?.activities ?? null,
        physicalDemands: anamnese?.physical_demands ?? null,
        sleepWeek: anamnese?.sleep_week ?? null,
        sleepWeekend: anamnese?.sleep_weekend ?? null,
        medicalTreatment: anamnese?.medical_treatment === 1,
        takingDrugs: anamnese?.taking_drugs === 1,
        comments: anamnese?.comments ?? null,
      },
      bodyComposition: metric
        ? {
            date: metric.date,
            weight: metric.weight ?? null,
            bodyFatPerc: metric.body_fat_perc ?? null,
            bodyFatKg: metric.body_fat_kg ?? null,
            waistCircumference: metric.waist_circumference ?? null,
            bcm: metric.bcm ?? null,
            sys: metric.sys ?? null,
            dia: metric.dia ?? null,
            calmPulse: metric.calm_pulse ?? null,
          }
        : null,
      goals: goals.map((g) => ({
        description: g.description ?? '',
        targetDate: g.targetDate ?? null,
        achieved: g.achieved === 1,
      })),
      recentTrainings: recentReviews.map((r) => ({
        trainingType: r.training_type ?? null,
        duration: r.duration ?? null,
        kcal: r.kcal ?? null,
        heartRate: r.heart_rate ?? null,
        feedbackEmoticon: r.feedback_emoticon ?? null,
      })),
      performanceTest: test
        ? {
            date: test.date,
            // Only include actually tested values (> 0). Value 0 = not tested.
            results: Object.fromEntries(
              Object.keys(TEST_BENCHMARKS)
                .filter((k) => {
                  const v = Number(test[k]) || 0;
                  return v > 0;
                })
                .map((k) => [k, Number(test[k])]),
            ),
            notTested: Object.keys(TEST_BENCHMARKS)
              .filter((k) => {
                const v = Number(test[k]) || 0;
                return v === 0 && !k.startsWith('sprint_');
              })
              .map((k) => TEST_BENCHMARKS[k].label),
          }
        : { date: '', results: {} },
      weaknesses,
      exerciseCatalog: exercises,
    };
  }

  /** Route to the active provider, with automatic fallback */
  private async callLlm(context: AiPromptContext): Promise<AiLlmResponse> {
    if (this.provider === 'none') {
      throw new ServiceUnavailableException('No AI provider configured');
    }

    // Try primary provider
    try {
      return this.provider === 'groq'
        ? await this.callGroq(context)
        : await this.callAnthropic(context);
    } catch (primaryErr) {
      // Determine if a fallback provider is available
      const fallbackAvailable = this.provider === 'anthropic' ? !!this.groq : !!this.anthropic;
      if (!fallbackAvailable) throw primaryErr;

      const fallbackName = this.provider === 'anthropic' ? 'Groq' : 'Anthropic';
      this.logger.warn(`${this.provider} failed (${primaryErr.message}), trying ${fallbackName}...`);

      // Try fallback provider
      try {
        return this.provider === 'anthropic'
          ? await this.callGroq(context)
          : await this.callAnthropic(context);
      } catch (fallbackErr) {
        // Both failed — throw combined error
        throw new Error(`Primary(${this.provider}): ${primaryErr.message} | Fallback(${fallbackName}): ${fallbackErr.message}`);
      }
    }
  }

  // ── Groq (Llama 3.3 70B — free tier) ────────────────────────────────────

  private async callGroq(context: AiPromptContext): Promise<AiLlmResponse> {
    if (!this.groq) throw new ServiceUnavailableException('Groq API key not configured');

    const userPrompt = this.buildUserPrompt(context);
    const systemPrompt = this.buildSystemPrompt(context.planRequest, context);

    const response = await Promise.race([
      this.groq.chat.completions.create({
        model: 'llama-3.3-70b-versatile',
        max_tokens: 4096,
        temperature: 0.3,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt },
        ],
      }),
      new Promise<never>((_, reject) =>
        setTimeout(() => reject(new Error('Groq timeout after 45s')), 45_000),
      ),
    ]);

    const raw = response.choices?.[0]?.message?.content?.trim();
    if (!raw) throw new Error('No content in Groq response');

    return this.parseResponse(raw);
  }

  // ── Anthropic Claude ─────────────────────────────────────────────────────

  private async callAnthropic(context: AiPromptContext): Promise<AiLlmResponse> {
    if (!this.anthropic) throw new ServiceUnavailableException('Anthropic API key not configured');

    const userPrompt = this.buildUserPrompt(context);
    const systemPrompt = this.buildSystemPrompt(context.planRequest, context);

    const response = await Promise.race([
      this.anthropic.messages.create({
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 4096,
        system: systemPrompt,
        messages: [{ role: 'user', content: userPrompt }],
      }),
      new Promise<never>((_, reject) =>
        setTimeout(() => reject(new Error('Anthropic timeout after 45s')), 45_000),
      ),
    ]);

    const textBlock = response.content.find((b) => b.type === 'text');
    if (!textBlock || textBlock.type !== 'text') {
      throw new Error('No text content in Anthropic response');
    }

    return this.parseResponse(textBlock.text.trim());
  }

  // ── Shared JSON parser ───────────────────────────────────────────────────

  private parseResponse(raw: string): AiLlmResponse {
    // Strip potential markdown fences
    let cleaned = raw;
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replace(/^```(?:json)?\n?/, '').replace(/\n?```$/, '');
    }

    let parsed: AiLlmResponse;
    try {
      parsed = JSON.parse(cleaned);
    } catch (e) {
      this.logger.error(`Failed to parse LLM JSON: ${cleaned.substring(0, 500)}`);
      throw new Error(`LLM returned invalid JSON: ${e.message}`);
    }

    // Validate required fields (mobility is optional for backward compat)
    if (!parsed.plan_name || !parsed.sonsomo || !parsed.main || !parsed.core) {
      throw new Error('LLM response missing required fields (plan_name, sonsomo, main, core)');
    }
    if (!parsed.mobility) parsed.mobility = [];

    return parsed;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RULE-BASED FALLBACK (when LLM is unavailable)
  // ═══════════════════════════════════════════════════════════════════════════

  private ruleBasedFallback(
    weaknesses: AiWeakness[],
    exercises: AiExerciseCatalog[],
    contraindications: string[],
  ): AiLlmResponse {
    // ── Contraindication helpers ──────────────────────────────────────────
    const contraLower = contraindications.map((c) => c.toLowerCase());
    const hasKneeContra = contraLower.some(
      (c) => c.includes('knie') || c.includes('patella') || c.includes('meniskus'),
    );
    const hasShoulderContra = contraLower.some(
      (c) => c.includes('schulter') || c.includes('impingement') || c.includes('rotator'),
    );
    const hasBackContra = contraLower.some(
      (c) => c.includes('rücken') || c.includes('lws') || c.includes('bandscheibe'),
    );

    // Filter out exercises that conflict with contraindications
    const isSafe = (e: AiExerciseCatalog): boolean => {
      const joint = (e.joint ?? '').toLowerCase();
      const name = e.name.toLowerCase();
      if (hasKneeContra && (joint.includes('knie') || name.includes('squat') || name.includes('lunge') || name.includes('sprung') || name.includes('jump'))) return false;
      if (hasShoulderContra && (joint.includes('schulter') || name.includes('press') || name.includes('überkopf') || name.includes('handstand'))) return false;
      if (hasBackContra && (joint.includes('lws') || name.includes('deadlift') || name.includes('hyperextension'))) return false;
      return true;
    };

    const safeExercises = exercises.filter(isSafe);

    // ── Sonsomo: Proprioception, coordination, foot muscles ──────────────
    // Priority: bodyRegion=Foot, group containing Balance/Sensomotorik/Fuß, pattern=Static with ankle joint
    const sonsomoPool = safeExercises.filter((e) => {
      const region = (e.bodyRegion ?? '').toLowerCase();
      const group = (e.group ?? '').toLowerCase();
      const joint = (e.joint ?? '').toLowerCase();
      const pattern = (e.pattern ?? '').toLowerCase();
      const name = e.name.toLowerCase();
      // Foot exercises
      if (region === 'foot') return true;
      // Balance/Sensomotorik group
      if (group.includes('balance') || group.includes('sensomotorik') || group.includes('slackline')) return true;
      // Static ankle exercises (proprioceptive)
      if (pattern === 'static' && joint.includes('sprunggelenk')) return true;
      // Seilspringen (coordination)
      if (name.includes('seilspring') || name.includes('rope') || name.includes('skip')) return true;
      return false;
    });

    // ── Core: Core stability & rotation ──────────────────────────────────
    const corePool = safeExercises.filter((e) => {
      const region = (e.bodyRegion ?? '').toLowerCase();
      const muscle = (e.muscle ?? '').toLowerCase();
      const joint = (e.joint ?? '').toLowerCase();
      const pattern = (e.pattern ?? '').toLowerCase();
      const name = e.name.toLowerCase();
      // Direct core region
      if (region === 'core') return true;
      // Muscle-based: abdominal/back stabilizers
      if (muscle.includes('bauch') || muscle.includes('core') || muscle.includes('rumpf') || muscle.includes('rückenstrecker')) return true;
      // Joint: LWS or BWS (spinal stabilizers)
      if (joint.includes('lws') || joint.includes('bws')) return true;
      // Pattern: rotation or static with core indication
      if (pattern === 'rotation') return true;
      // Name-based hints
      if (name.includes('plank') || name.includes('stütz') || name.includes('pallof') || name.includes('hollow')) return true;
      return false;
    });

    // ── Main: Address weaknesses, pick from remaining pool ───────────────
    const usedIds = new Set<number>();
    const sonsomoIds = new Set(sonsomoPool.map((e) => e.id));
    const coreIds = new Set(corePool.map((e) => e.id));

    // Try to match exercises to weaknesses
    const weaknessExercises: AiExerciseCatalog[] = [];
    for (const w of weaknesses) {
      if (w.category === 'core' || w.category === 'warmup') continue; // handled by sonsomo/core
      const categoryLower = w.label.toLowerCase();
      const match = safeExercises.find((e) => {
        if (usedIds.has(e.id) || sonsomoIds.has(e.id)) return false;
        const muscle = (e.muscle ?? '').toLowerCase();
        const pattern = (e.pattern ?? '').toLowerCase();
        const name = e.name.toLowerCase();
        // Match by weakness type
        if (categoryLower.includes('zug') && (pattern === 'pull' || name.includes('pull') || name.includes('ruder') || name.includes('row'))) return true;
        if (categoryLower.includes('druck') && (pattern === 'push' || name.includes('push') || name.includes('press') || name.includes('dip'))) return true;
        if (categoryLower.includes('rumpf') && (muscle.includes('bauch') || muscle.includes('rückenstrecker'))) return true;
        if (categoryLower.includes('wand') && (pattern === 'squat' || name.includes('squat') || name.includes('kniebeuge'))) return true;
        if (categoryLower.includes('sprung') && (pattern === 'plyo' || name.includes('jump') || name.includes('sprung'))) return true;
        if (categoryLower.includes('sprint') && (pattern === 'sprint' || name.includes('sprint'))) return true;
        return false;
      });
      if (match) {
        weaknessExercises.push(match);
        usedIds.add(match.id);
      }
    }

    // Fill remaining main slots with general strength exercises
    const mainPool = safeExercises.filter((e) => {
      if (usedIds.has(e.id) || sonsomoIds.has(e.id) || coreIds.has(e.id)) return false;
      const region = (e.bodyRegion ?? '').toLowerCase();
      const pattern = (e.pattern ?? '').toLowerCase();
      return (
        (region === 'upperbody' || region === 'lowerbody' || region === 'fullbody') &&
        (pattern === 'push' || pattern === 'pull' || pattern === 'squat' || pattern === 'hinge')
      );
    });

    // ── Assemble with deduplication & shuffle for variety ─────────────────
    const shuffle = <T>(arr: T[]): T[] => {
      const a = [...arr];
      for (let i = a.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [a[i], a[j]] = [a[j], a[i]];
      }
      return a;
    };

    const toRow = (e: AiExerciseCatalog, sets = '3×12'): AiLlmResponse['sonsomo'][0] => ({
      exercise_name: e.name,
      exercise_id: e.id,
      device: '',
      position: '',
      sets,
      weight: '',
    });

    const sonsomoRows = shuffle(sonsomoPool).slice(0, 3).map((e) => toRow(e, '2×30s'));
    const mainRows = [
      ...weaknessExercises.map((e) => toRow(e)),
      ...shuffle(mainPool).slice(0, Math.max(0, 5 - weaknessExercises.length)).map((e) => toRow(e)),
    ].slice(0, 5);
    const coreRows = shuffle(corePool.filter((e) => !usedIds.has(e.id))).slice(0, 3).map((e) => toRow(e, '3×30s'));

    // ── Mobility: CARs, active stretches, fascia work ────────────────────
    const mobilityPool = safeExercises.filter((e) => {
      const group = (e.group ?? '').toLowerCase();
      const pattern = (e.pattern ?? '').toLowerCase();
      const name = e.name.toLowerCase();
      if (group.includes('mobilit') || group.includes('beweglichkeit')) return true;
      if (name.includes('car') || name.includes('kreisbewegung') || name.includes('dehnung') || name.includes('stretch')) return true;
      if (pattern === 'rotation' && (e.joint ?? '').toLowerCase().includes('bws')) return true;
      return false;
    });
    const mobilityRows = shuffle(mobilityPool).slice(0, 2).map((e) => toRow(e, '2×30s'));

    // ── Build reasoning text ─────────────────────────────────────────────
    const weaknessText = weaknesses.length
      ? weaknesses.map((w) => `${w.label} (${w.deficit}% unter Benchmark)`).join(', ')
      : 'Keine Schwächen identifiziert';

    const contraText = contraindications.length
      ? `Kontraindikationen berücksichtigt: ${contraindications.join(', ')}.`
      : '';

    return {
      plan_name: 'Automatischer Trainingsplan',
      sonsomo: sonsomoRows,
      main: mainRows,
      core: coreRows,
      mobility: mobilityRows,
      reasoning:
        `Regelbasierter Plan (KI nicht verfügbar). ` +
        `Sonsomo: Propriozeption, Koordination & Fußmuskulatur. ` +
        `Identifizierte Schwächen: ${weaknessText}. ${contraText} ` +
        `Bitte überprüfe die Übungsauswahl manuell und passe sie an die individuellen Bedürfnisse an.`,
    };
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  private toPlanRow(row: AiPlanRow) {
    return {
      exercise: row.exercise,
      device: row.device,
      position: row.position,
      weight: row.weight,
      sets: row.sets || '',
      dates: row.dates,
      ...(row.exerciseId ? { exerciseId: row.exerciseId } : {}),
    };
  }
}
