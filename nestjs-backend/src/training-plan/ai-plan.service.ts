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

import {
  AiPlanResult,
  AiPlanRow,
  AiWeakness,
  AiExerciseCatalog,
  AiPromptContext,
  AiLlmResponse,
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
          model: 'claude-3-haiku-20240307',
          max_tokens: 10,
          messages: [{ role: 'user', content: 'Say OK' }],
        });
        status.anthropicTest = { ok: true, model: 'claude-3-haiku-20240307', response: resp.content?.[0] };
      } catch (err: any) {
        status.anthropicTest = { ok: false, error: err.message?.substring(0, 300) };
      }
    }

    return status;
  }

  async generateAiPlan(clientId: number): Promise<AiPlanResult> {
    // 1. Load all required data in parallel
    const [client, test, anamnese, exercises] = await Promise.all([
      this.loadClient(clientId),
      this.loadLatestTest(clientId),
      this.loadAnamnese(clientId),
      this.loadExerciseCatalog(),
    ]);

    // 2. Identify weaknesses from test
    const weaknesses = this.identifyWeaknesses(test);

    // 3. Extract contraindications from anamnese
    const contraindications = this.extractContraindications(anamnese);

    // 4. Build prompt context
    const context = this.buildPromptContext(
      client, test, anamnese, weaknesses, exercises,
    );

    // 5. Generate plan (AI or rule-based fallback)
    let llmResponse: AiLlmResponse;
    try {
      llmResponse = await this.callLlm(context);
    } catch (err) {
      this.logger.warn(`LLM call failed, using rule-based fallback: ${err.message}`);
      llmResponse = this.ruleBasedFallback(weaknesses, exercises, contraindications);
      llmResponse.reasoning = `⚠️ AI-Fehler: ${err.message}\n\n${llmResponse.reasoning}`;
    }

    // 6. Match suggested exercises against DB
    const exerciseMap = new Map(exercises.map((e) => [e.id, e]));
    const exerciseByName = new Map(exercises.map((e) => [e.name.toLowerCase(), e]));

    const mapRows = (rows: AiLlmResponse['sonsomo']): AiPlanRow[] =>
      rows.map((r) => {
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

    return {
      name: llmResponse.plan_name,
      sonsomo: mapRows(llmResponse.sonsomo),
      main: mapRows(llmResponse.main),
      core: mapRows(llmResponse.core),
      ai_reasoning: llmResponse.reasoning,
      weaknesses,
      basedOnTestId: test?.id ?? null,
      basedOnTestDate: test?.date ?? null,
      contraindications,
    };
  }

  /**
   * Generate and immediately persist the plan to the DB.
   * Returns the saved TrainingPlan entity + AI metadata.
   */
  async generateAndSave(clientId: number): Promise<{
    plan: TrainingPlan;
    meta: Omit<AiPlanResult, 'sonsomo' | 'main' | 'core' | 'name'>;
  }> {
    const result = await this.generateAiPlan(clientId);

    const values = JSON.stringify({
      sonsomo: result.sonsomo.map(this.toPlanRow),
      main: result.main.map(this.toPlanRow),
      core: result.core.map(this.toPlanRow),
      dates: Array(8).fill(''),
    });

    // Auto-create new exercises that the AI suggested
    for (const row of [...result.sonsomo, ...result.main, ...result.core]) {
      if (row.isNew && row.exercise) {
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

    const plan = await this.planRepo.save(
      this.planRepo.create({
        clientId,
        values,
        name: result.name || 'KI-Trainingsplan',
        goal: result.ai_reasoning.substring(0, 500),
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
    }));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ANALYSIS
  // ═══════════════════════════════════════════════════════════════════════════

  private identifyWeaknesses(test: PerformanceTest | null): AiWeakness[] {
    if (!test) return [];

    return Object.entries(TEST_BENCHMARKS)
      .filter(([key, bench]) => {
        const value = test[key] as number;
        // Sprint: lower = better, skip 0 values
        if (key.startsWith('sprint_')) return false;
        return bench.min > 0 && value < bench.min;
      })
      .map(([key, bench]) => ({
        field: key,
        label: bench.label,
        value: test[key] as number,
        benchmark: bench.min,
        deficit: Math.round((1 - (test[key] as number) / bench.min) * 100),
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

    return result;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LLM CALL — supports Groq and Anthropic
  // ═══════════════════════════════════════════════════════════════════════════

  /** Shared system prompt used by all providers */
  private get systemPrompt(): string {
    return `Du bist ein erfahrener Sportwissenschaftler und Personal Trainer.
Deine Aufgabe: Erstelle einen individualisierten Trainingsplan basierend auf den Leistungstest-Ergebnissen und der medizinischen Anamnese des Kunden.

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
3. SCHWÄCHEN VOLLSTÄNDIG ABDECKEN: Adressiere JEDE identifizierte Schwäche aus dem Leistungstest mit mindestens einer gezielten Übung. Prüfe am Ende, ob alle Schwächen im Plan vertreten sind.
4. VERFÜGBARE ÜBUNGEN BEVORZUGEN: Wähle Übungen aus dem mitgelieferten Katalog (mit exercise_id). Nur wenn keine passende Übung im Katalog existiert, schlage eine neue vor (exercise_id: null).
5. STRUKTUR:
   - "sonsomo" (Aufwärmen/Sensomotorik): 2-4 Übungen mit Fokus auf propriozeptives Training und Koordination. Ziel: Nervensystem aktivieren, Dopaminausschüttung anregen, den Kunden ins Hier-und-Jetzt bringen. Bevorzuge: Barfuß-Übungen, Balance Board, Einbeinstand, Slackline, koordinative Herausforderungen. KEINE klassischen Dehnübungen oder passives Aufwärmen.
   - "main" (Haupttraining): 4-6 Übungen für die identifizierten Schwächen
   - "core" (Core/Rumpf): 2-3 Übungen für Rumpfstabilität
6. GEWICHT/BELASTUNG: Gib realistische Startgewichte an. Trenne Sätze/Wiederholungen (sets) und Gewicht (weight).
7. SPRACHE: Antworte auf Deutsch.

Antworte AUSSCHLIESSLICH mit validem JSON in genau diesem Format:
{
  "plan_name": "Kurzer Planname (z.B. 'Kraft & Stabilität Phase 1')",
  "sonsomo": [
    { "exercise_name": "Name", "exercise_id": 123, "device": "Gerät", "position": "Position/Ausführung", "sets": "3×12", "weight": "20kg" }
  ],
  "main": [ ... ],
  "core": [ ... ],
  "reasoning": "2-4 Sätze die erklären WARUM dieser Plan gewählt wurde, welche Schwächen adressiert werden, und welche Kontraindikationen berücksichtigt wurden."
}`;
  }

  private buildUserPrompt(context: AiPromptContext): string {
    // Build a compact prompt to stay within token limits (Groq free: 12k TPM).
    // Exercise catalog is sent as compact lines instead of verbose JSON.
    const { exerciseCatalog, ...rest } = context;

    const catalogLines = exerciseCatalog
      .map((e) => `${e.id}|${e.name}${e.group ? '|' + e.group : ''}`)
      .join('\n');

    return [
      'Erstelle einen Trainingsplan für folgenden Kunden:',
      '',
      JSON.stringify(rest, null, 2),
      '',
      'VERFÜGBARE ÜBUNGEN (id|name|gruppe):',
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
  ): AiPromptContext {
    return {
      client: {
        id: client.id,
        name: `${client.firstname} ${client.lastname}`,
        birthdate: client.birthday ?? undefined,
        gender: client.gender ?? undefined,
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
      },
      performanceTest: test
        ? {
            date: test.date,
            results: Object.fromEntries(
              Object.keys(TEST_BENCHMARKS).map((k) => [k, test[k] as number]),
            ),
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

    const response = await this.groq.chat.completions.create({
      model: 'llama-3.3-70b-versatile',
      max_tokens: 4096,
      temperature: 0.3,
      messages: [
        { role: 'system', content: this.systemPrompt },
        { role: 'user', content: userPrompt },
      ],
    });

    const raw = response.choices?.[0]?.message?.content?.trim();
    if (!raw) throw new Error('No content in Groq response');

    return this.parseResponse(raw);
  }

  // ── Anthropic Claude ─────────────────────────────────────────────────────

  private async callAnthropic(context: AiPromptContext): Promise<AiLlmResponse> {
    if (!this.anthropic) throw new ServiceUnavailableException('Anthropic API key not configured');

    const userPrompt = this.buildUserPrompt(context);

    const response = await this.anthropic.messages.create({
      model: 'claude-3-haiku-20240307',
      max_tokens: 4096,
      system: this.systemPrompt,
      messages: [{ role: 'user', content: userPrompt }],
    });

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

    // Validate required fields
    if (!parsed.plan_name || !parsed.sonsomo || !parsed.main || !parsed.core) {
      throw new Error('LLM response missing required fields (plan_name, sonsomo, main, core)');
    }

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
    const hasCardioContra = contraindications.some(
      (c) => c.includes('Herz') || c.includes('Kreislauf'),
    );

    // Group exercises by their group name
    const byGroup = new Map<string, AiExerciseCatalog[]>();
    for (const e of exercises) {
      const g = e.group?.toLowerCase() ?? 'sonstige';
      if (!byGroup.has(g)) byGroup.set(g, []);
      byGroup.get(g)!.push(e);
    }

    // Pick exercises for each weakness category
    const pick = (
      pool: AiExerciseCatalog[],
      count: number,
    ): AiLlmResponse['sonsomo'] =>
      pool.slice(0, count).map((e) => ({
        exercise_name: e.name,
        exercise_id: e.id,
        device: '',
        position: '',
        sets: '3×12',
        weight: '',
      }));

    // Simple matching: try to find exercises whose group loosely matches
    const warmupExercises = exercises.filter(
      (e) =>
        e.group?.toLowerCase().includes('mobil') ||
        e.group?.toLowerCase().includes('warm') ||
        e.group?.toLowerCase().includes('stabil') ||
        e.group?.toLowerCase().includes('dehnung'),
    );
    const coreExercises = exercises.filter(
      (e) =>
        e.group?.toLowerCase().includes('core') ||
        e.group?.toLowerCase().includes('rumpf') ||
        e.group?.toLowerCase().includes('bauch'),
    );
    const mainExercises = exercises.filter(
      (e) =>
        !warmupExercises.includes(e) &&
        !coreExercises.includes(e),
    );

    const sonsomo = pick(warmupExercises.length ? warmupExercises : exercises, 3);
    const main = pick(mainExercises.length ? mainExercises : exercises, 5);
    const core = pick(coreExercises.length ? coreExercises : exercises, 3);

    const weaknessText = weaknesses.length
      ? weaknesses.map((w) => `${w.label} (${w.deficit}% unter Benchmark)`).join(', ')
      : 'Keine Schwächen identifiziert';

    const contraText = contraindications.length
      ? `Beachte: ${contraindications.join(', ')}.`
      : '';

    return {
      plan_name: 'Automatischer Trainingsplan',
      sonsomo,
      main,
      core,
      reasoning:
        `Regelbasierter Plan (KI nicht verfügbar). ` +
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
