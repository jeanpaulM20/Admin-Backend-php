import { Injectable, Logger, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Exercise } from '../entities/exercise.entity';
import { Exercisegroup } from '../entities/exercise-group.entity';
import { Exercisesubgroup } from '../entities/exercise-subgroup.entity';
import { EXERCISE_SEED_DATA } from './exercise-seed.data';

/** Result returned by the AI exercise verification endpoint */
export interface ExerciseVerifyResult {
  valid: boolean;
  correctedName: string;
  corrections: { type: string; original: string; corrected: string; explanation: string }[];
  bodyRegion: string | null;
  movementPattern: string | null;
  confidence: number;
  summary: string;
}

@Injectable()
export class ExerciseService {
  private readonly logger = new Logger(ExerciseService.name);
  private anthropic: any = null;

  constructor(
    @InjectRepository(Exercise)
    private readonly exerciseRepo: Repository<Exercise>,
    @InjectRepository(Exercisegroup)
    private readonly groupRepo: Repository<Exercisegroup>,
    @InjectRepository(Exercisesubgroup)
    private readonly subgroupRepo: Repository<Exercisesubgroup>,
  ) {
    const key = process.env.ANTHROPIC_API_KEY;
    if (key) {
      try {
        // eslint-disable-next-line @typescript-eslint/no-var-requires
        const Anthropic = require('@anthropic-ai/sdk');
        this.anthropic = new Anthropic({ apiKey: key });
        this.logger.log('Anthropic client initialised for exercise verification');
      } catch (e) {
        this.logger.warn('Anthropic SDK not available for exercise verification');
      }
    }
  }

  findAll() {
    return this.exerciseRepo.find({ relations: ['group', 'subgroup', 'exercisePictures'] });
  }

  async findOne(id: number) {
    const exercise = await this.exerciseRepo.findOne({
      where: { id },
      relations: ['group', 'subgroup', 'exercisePictures'],
    });
    if (!exercise) throw new NotFoundException(`Exercise ${id} not found`);
    return exercise;
  }

  findGroups() {
    return this.groupRepo.find();
  }

  private static readonly VALID_BODY_REGIONS = [
    'UpperBody', 'LowerBody', 'Core', 'FullBody', 'Foot',
    'Shoulder', 'Spine',
  ];

  private static readonly VALID_MOVEMENT_PATTERNS = [
    'Push', 'Pull', 'Squat', 'Hinge', 'Carry',
    'Rotation', 'Static', 'Plyo', 'Sprint', 'Agility',
  ];

  /** Validate create/update payload and throw 400 on bad input. */
  private validatePayload(data: Partial<Exercise>, requireName = false) {
    if (requireName) {
      if (!data.name || typeof data.name !== 'string' || data.name.trim().length === 0) {
        throw new BadRequestException('Name is required and must be non-empty');
      }
      if (data.name.trim().length > 200) {
        throw new BadRequestException('Name must be 200 characters or fewer');
      }
    }
    if (data.bodyRegion !== undefined && data.bodyRegion !== null) {
      if (!ExerciseService.VALID_BODY_REGIONS.includes(data.bodyRegion)) {
        throw new BadRequestException(
          `Invalid bodyRegion "${data.bodyRegion}". Allowed: ${ExerciseService.VALID_BODY_REGIONS.join(', ')}`,
        );
      }
    }
    if (data.movementPattern !== undefined && data.movementPattern !== null) {
      if (!ExerciseService.VALID_MOVEMENT_PATTERNS.includes(data.movementPattern)) {
        throw new BadRequestException(
          `Invalid movementPattern "${data.movementPattern}". Allowed: ${ExerciseService.VALID_MOVEMENT_PATTERNS.join(', ')}`,
        );
      }
    }
  }

  /** Strip fields that clients must never set directly. */
  private sanitizePayload(data: Partial<Exercise>): Partial<Exercise> {
    const { id, archive, published, group, subgroup, exercisePictures, ...safe } = data as any;
    return safe;
  }

  async create(data: Partial<Exercise>) {
    this.validatePayload(data, true);
    const safe = this.sanitizePayload(data);
    safe.name = safe.name!.trim();
    safe.archive = 0;
    safe.published = 0;
    // Validate group exists if provided
    if (safe.groupId) {
      const group = await this.groupRepo.findOne({ where: { id: safe.groupId } });
      if (!group) throw new BadRequestException(`Group ${safe.groupId} not found`);
    }
    return this.exerciseRepo.save(this.exerciseRepo.create(safe));
  }

  async update(id: number, data: Partial<Exercise>) {
    this.validatePayload(data, false);
    const safe = this.sanitizePayload(data);
    if (safe.name !== undefined) safe.name = safe.name.trim();
    if (safe.groupId) {
      const group = await this.groupRepo.findOne({ where: { id: safe.groupId } });
      if (!group) throw new BadRequestException(`Group ${safe.groupId} not found`);
    }
    await this.findOne(id);
    await this.exerciseRepo.update(id, safe);
    return this.findOne(id);
  }

  async remove(id: number) {
    const exercise = await this.findOne(id);
    return this.exerciseRepo.remove(exercise);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AI VERIFY — spell-check and validate exercise names before creation
  // ═══════════════════════════════════════════════════════════════════════════

  async verifyExercise(
    name: string,
    groupName?: string,
    bodyRegion?: string,
  ): Promise<ExerciseVerifyResult> {
    if (!name || name.trim().length < 2) {
      throw new BadRequestException('Name muss mindestens 2 Zeichen haben');
    }

    // Check for duplicate name in DB
    const existing = await this.exerciseRepo.findOne({
      where: { name: name.trim() },
      relations: ['group'],
    });

    if (!this.anthropic) {
      // Fallback: no AI available — accept as-is with duplicate check
      return {
        valid: !existing,
        correctedName: name.trim(),
        corrections: [],
        bodyRegion: null,
        movementPattern: null,
        confidence: existing ? 0.5 : 0.7,
        summary: existing
          ? `"${name.trim()}" existiert bereits im Katalog (Gruppe: ${existing.group?.name ?? '–'}).`
          : 'KI-Prüfung nicht verfügbar. Name wird ungeprüft übernommen.',
      };
    }

    // Load existing exercise names for context
    const allExercises = await this.exerciseRepo.find({
      select: ['name', 'bodyRegion', 'movementPattern'],
      relations: ['group'],
    });
    const catalogNames = allExercises
      .filter((e) => e.name)
      .map((e) => `${e.name} (${e.group?.name ?? '–'})`)
      .slice(0, 200) // limit context size
      .join('\n');

    const systemPrompt = `Du bist ein Fitnessexperte und Sprachprüfer für einen Übungskatalog eines Personal-Training-Studios.

Deine Aufgabe: Prüfe den eingegebenen Übungsnamen auf:
1. **Rechtschreibung** — deutsche und englische Fitnessbegriffe (z.B. "Bankdrücken", "Deadlift", "Plank")
2. **Korrektheit** — Ist es ein realer, bekannter Übungsname?
3. **Formatierung** — Korrekte Groß-/Kleinschreibung, Bindestriche, Sonderzeichen
4. **Duplikate** — Ähnliche Übung bereits im Katalog? (Warnung wenn ja)

Bestehender Katalog (Auswahl):
${catalogNames}

Antworte NUR als valides JSON (kein Markdown):
{
  "valid": true/false,
  "correctedName": "Korrigierter Name",
  "corrections": [
    {"type": "spelling|format|unknown", "original": "...", "corrected": "...", "explanation": "Kurze Erklärung auf Deutsch"}
  ],
  "bodyRegion": "UpperBody|LowerBody|Core|FullBody|Foot|Shoulder|Spine|null",
  "movementPattern": "Push|Pull|Squat|Hinge|Carry|Rotation|Static|Plyo|Sprint|Agility|null",
  "confidence": 0.0-1.0,
  "summary": "Ein Satz auf Deutsch: Was wurde geprüft/korrigiert?"
}

Regeln:
- "valid" = true wenn der Name (ggf. korrigiert) eine echte Übung ist
- "valid" = false nur wenn der Name völlig unsinnig/keine Übung ist
- corrections Array leer lassen wenn nichts zu korrigieren
- summary immer auf Deutsch, kurz und freundlich
- bodyRegion und movementPattern vorschlagen wenn erkennbar, sonst null`;

    const userPrompt = `Prüfe diesen Übungsnamen:
Name: "${name.trim()}"${groupName ? `\nGruppe: ${groupName}` : ''}${bodyRegion ? `\nKörperregion: ${bodyRegion}` : ''}`;

    try {
      const response = await Promise.race([
        this.anthropic.messages.create({
          model: 'claude-haiku-4-5-20251001',
          max_tokens: 512,
          system: systemPrompt,
          messages: [{ role: 'user', content: userPrompt }],
        }),
        new Promise((_, reject) =>
          setTimeout(() => reject(new Error('AI timeout')), 15000),
        ),
      ]) as any;

      const raw = response.content?.[0]?.text ?? '';
      const json = raw.replace(/```json?\n?/g, '').replace(/```/g, '').trim();
      const parsed = JSON.parse(json);

      // Add duplicate warning if name matches existing
      if (existing && parsed.corrections) {
        const hasDuplicateWarning = parsed.corrections.some(
          (c: any) => c.type === 'duplicate',
        );
        if (!hasDuplicateWarning) {
          parsed.corrections.push({
            type: 'duplicate',
            original: name.trim(),
            corrected: existing.name,
            explanation: `Übung "${existing.name}" existiert bereits im Katalog (${existing.group?.name ?? 'Keine Gruppe'}).`,
          });
        }
      }

      return {
        valid: parsed.valid ?? true,
        correctedName: parsed.correctedName ?? name.trim(),
        corrections: parsed.corrections ?? [],
        bodyRegion: parsed.bodyRegion ?? null,
        movementPattern: parsed.movementPattern ?? null,
        confidence: parsed.confidence ?? 0.8,
        summary: parsed.summary ?? 'Prüfung abgeschlossen.',
      };
    } catch (err) {
      this.logger.warn(`Exercise verify AI failed: ${err}`);
      return {
        valid: true,
        correctedName: name.trim(),
        corrections: [],
        bodyRegion: null,
        movementPattern: null,
        confidence: 0.5,
        summary: 'KI-Prüfung fehlgeschlagen. Name wird ungeprüft übernommen.',
      };
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SEED — idempotent: skips exercises that already exist by name
  // ═══════════════════════════════════════════════════════════════════════════

  async seed(): Promise<{
    groupsCreated: number;
    subgroupsCreated: number;
    exercisesCreated: number;
    exercisesSkipped: number;
    metadataUpdated: number;
    details: string[];
  }> {
    const details: string[] = [];
    let groupsCreated = 0;
    let subgroupsCreated = 0;
    let exercisesCreated = 0;
    let exercisesSkipped = 0;
    let metadataUpdated = 0;

    // Cache existing exercise names for deduplication
    const existingExercises = await this.exerciseRepo.find({ select: ['name'] });
    const existingNames = new Set(existingExercises.map((e) => e.name.toLowerCase()));

    for (const category of EXERCISE_SEED_DATA) {
      // 1. Find or create group
      let group = await this.groupRepo.findOne({
        where: { name: category.group },
      });
      if (!group) {
        group = await this.groupRepo.save(
          this.groupRepo.create({ name: category.group }),
        );
        groupsCreated++;
        this.logger.log(`Created group: "${category.group}" → id=${group.id}`);
      }

      // 2. Find or create subgroups
      const subgroupMap = new Map<string, number>();
      for (const sgName of category.subgroups) {
        let sg = await this.subgroupRepo.findOne({ where: { name: sgName } });
        if (!sg) {
          sg = await this.subgroupRepo.save(
            this.subgroupRepo.create({ name: sgName }),
          );
          subgroupsCreated++;
        }
        subgroupMap.set(sgName, sg.id);
      }

      // 3. Create or update exercises (skip duplicates for new, update metadata for existing)
      for (const ex of category.exercises) {
        if (existingNames.has(ex.name.toLowerCase())) {
          // Update anatomy metadata on existing exercises (idempotent)
          if (ex.body_region || ex.primary_muscle_group || ex.target_joint || ex.movement_pattern) {
            await this.exerciseRepo.update(
              { name: ex.name },
              {
                ...(ex.body_region && { bodyRegion: ex.body_region }),
                ...(ex.primary_muscle_group && { primaryMuscleGroup: ex.primary_muscle_group }),
                ...(ex.target_joint && { targetJoint: ex.target_joint }),
                ...(ex.movement_pattern && { movementPattern: ex.movement_pattern }),
              },
            );
            metadataUpdated++;
          }
          exercisesSkipped++;
          continue;
        }

        const exercise = await this.exerciseRepo.save(
          this.exerciseRepo.create({
            name: ex.name,
            groupId: group.id,
            subgroupId: ex.subgroup ? subgroupMap.get(ex.subgroup) : undefined,
            published: 1,
            archive: 0,
            bodyRegion: ex.body_region || undefined,
            primaryMuscleGroup: ex.primary_muscle_group || undefined,
            targetJoint: ex.target_joint || undefined,
            movementPattern: ex.movement_pattern || undefined,
          }),
        );
        existingNames.add(ex.name.toLowerCase());
        exercisesCreated++;
      }

      details.push(
        `${category.group}: ${category.exercises.length} Übungen definiert`,
      );
    }

    this.logger.log(
      `Seed complete: ${groupsCreated} groups, ${subgroupsCreated} subgroups, ` +
      `${exercisesCreated} exercises created, ${exercisesSkipped} skipped, ${metadataUpdated} metadata updated`,
    );

    return { groupsCreated, subgroupsCreated, exercisesCreated, exercisesSkipped, metadataUpdated, details };
  }
}
