import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Exercise } from '../entities/exercise.entity';
import OpenAI from 'openai';
import * as fs from 'fs';
import * as path from 'path';

// ── Prompt building ──────────────────────────────────────────────────────────

const STYLE_SUFFIX = `drawn with one single unbroken continuous black line on a pure white background, minimalist single line art style, one continuous flowing line varying in thickness, no shading, no fill, no color, no facial features, anatomically proportionate simplified human figure, clean modern illustration, white background`;

/** Map exercise group/category to a visual pose hint */
const GROUP_HINTS: Record<string, string> = {
  'Kettlebell-Training': 'holding a kettlebell (teardrop-shaped weight with handle)',
  'Eigenkörpergewicht / Calisthenics': 'bodyweight exercise, no equipment',
  'Ring- & Suspension-Training': 'using gymnastic rings or suspension straps',
  'Plyometrie & Reaktivkraft': 'explosive jumping or landing movement',
  'Mobilität & Aktive Beweglichkeit': 'flowing stretching or mobility pose',
  'Propriozeption': 'balancing on one leg or unstable surface',
  'Fußmuskulatur & Barfuß-Training': 'close-up of bare foot, detailed toe and arch',
  'Slackline': 'grip strength or hanging movement',
  'Exzentrisches Training': 'slow controlled lowering phase of an exercise',
  'Ausdauer & Intervalltraining': 'running or cardio movement',
};

function buildPrompt(exercise: Exercise): string {
  const name = exercise.name || 'exercise';
  const groupName = (exercise as any).group?.name || '';
  const groupHint = GROUP_HINTS[groupName] || '';

  // Extract the German description in parentheses if present
  const parenMatch = name.match(/\(([^)]+)\)/);
  const description = parenMatch ? parenMatch[1] : '';

  const parts = [
    `A single continuous line art drawing of a person performing "${name}"`,
    description ? `(${description})` : '',
    groupHint ? `— ${groupHint}` : '',
    `. The figure should clearly show the key body position and movement of this exercise.`,
    STYLE_SUFFIX,
  ];

  return parts.filter(Boolean).join(' ');
}

// ── Service ──────────────────────────────────────────────────────────────────

@Injectable()
export class ExerciseIconService {
  private readonly logger = new Logger(ExerciseIconService.name);
  private readonly openai: OpenAI | null;
  private readonly iconsDir: string;

  constructor(
    @InjectRepository(Exercise)
    private readonly exerciseRepo: Repository<Exercise>,
  ) {
    const apiKey = process.env.OPENAI_API_KEY;
    this.openai = apiKey ? new OpenAI({ apiKey }) : null;

    // Icons stored in public/exercise-icons/ → served at /exercise-icons/
    this.iconsDir = path.join(__dirname, '..', 'public', 'exercise-icons');
    if (!fs.existsSync(this.iconsDir)) {
      fs.mkdirSync(this.iconsDir, { recursive: true });
    }

    if (!this.openai) {
      this.logger.warn('OPENAI_API_KEY not set — icon generation disabled');
    }
  }

  /** Get the public URL path for an exercise icon */
  iconUrl(exerciseId: number): string {
    return `/exercise-icons/${exerciseId}.png`;
  }

  /** Check if an icon already exists on disk */
  iconExists(exerciseId: number): boolean {
    return fs.existsSync(path.join(this.iconsDir, `${exerciseId}.png`));
  }

  /** Get status: which exercises have icons, which don't */
  async getStatus(): Promise<{
    total: number;
    withIcon: number;
    withoutIcon: number;
    configured: boolean;
    missing: { id: number; name: string }[];
  }> {
    const exercises = await this.exerciseRepo.find({ select: ['id', 'name'] });
    const withIcon = exercises.filter((e) => this.iconExists(e.id));
    const withoutIcon = exercises.filter((e) => !this.iconExists(e.id));

    return {
      total: exercises.length,
      withIcon: withIcon.length,
      withoutIcon: withoutIcon.length,
      configured: !!this.openai,
      missing: withoutIcon.map((e) => ({ id: e.id, name: e.name })),
    };
  }

  /**
   * Generate an icon for a single exercise via DALL-E 3.
   * Returns the public URL path on success, null on failure.
   */
  async generateIcon(exerciseId: number): Promise<string | null> {
    if (!this.openai) {
      this.logger.warn('Cannot generate icon: OPENAI_API_KEY not configured');
      return null;
    }

    const exercise = await this.exerciseRepo.findOne({
      where: { id: exerciseId },
      relations: ['group'],
    });
    if (!exercise) {
      this.logger.warn(`Exercise ${exerciseId} not found`);
      return null;
    }

    const prompt = buildPrompt(exercise);
    this.logger.log(`Generating icon for "${exercise.name}" (id=${exerciseId})`);
    this.logger.debug(`Prompt: ${prompt.substring(0, 120)}...`);

    try {
      const response = await this.openai.images.generate({
        model: 'gpt-image-1',
        prompt,
        n: 1,
        size: '1024x1024',
        quality: 'low',
      } as any);

      const item = response.data?.[0] as any;
      let imageBuffer: Buffer;

      if (item?.b64_json) {
        // gpt-image-1 returns base64 directly
        imageBuffer = Buffer.from(item.b64_json, 'base64');
      } else if (item?.url) {
        // DALL-E models return a temporary URL
        const dl = await fetch(item.url);
        imageBuffer = Buffer.from(await dl.arrayBuffer());
      } else {
        this.logger.warn(`No image data returned for exercise ${exerciseId}`);
        return null;
      }

      // Save as PNG
      const filePath = path.join(this.iconsDir, `${exerciseId}.png`);
      fs.writeFileSync(filePath, imageBuffer);

      this.logger.log(`Icon saved: ${filePath}`);
      return this.iconUrl(exerciseId);
    } catch (err: any) {
      const detail = err?.error?.message || err?.message || String(err);
      this.logger.error(
        `Failed to generate icon for "${exercise.name}": ${detail}`,
      );
      // Throw so controller can return the actual error
      throw new Error(detail);
    }
  }

  /**
   * Batch generate icons for all exercises that don't have one yet.
   * Runs with a delay between requests to avoid rate limiting.
   * Returns progress info.
   */
  async generateMissing(options?: {
    limit?: number;
    delayMs?: number;
  }): Promise<{
    generated: number;
    failed: number;
    skipped: number;
    results: { id: number; name: string; status: string; url?: string }[];
  }> {
    const limit = options?.limit ?? 50;
    const delayMs = options?.delayMs ?? 2000;

    const exercises = await this.exerciseRepo.find({
      relations: ['group'],
      order: { id: 'ASC' },
    });

    const missing = exercises.filter((e) => !this.iconExists(e.id));
    const batch = missing.slice(0, limit);

    this.logger.log(
      `Batch generating: ${batch.length} of ${missing.length} missing icons (limit=${limit})`,
    );

    const results: { id: number; name: string; status: string; url?: string }[] = [];
    let generated = 0;
    let failed = 0;

    for (const exercise of batch) {
      try {
        const url = await this.generateIcon(exercise.id);
        if (url) {
          results.push({ id: exercise.id, name: exercise.name, status: 'ok', url });
          generated++;
        } else {
          results.push({ id: exercise.id, name: exercise.name, status: 'failed' });
          failed++;
        }
      } catch (err: any) {
        results.push({ id: exercise.id, name: exercise.name, status: 'error' });
        failed++;
      }

      // Rate limit delay (DALL-E 3: 5 req/min on free tier)
      if (batch.indexOf(exercise) < batch.length - 1) {
        await new Promise((r) => setTimeout(r, delayMs));
      }
    }

    return {
      generated,
      failed,
      skipped: missing.length - batch.length,
      results,
    };
  }

  /** Delete an icon (for regeneration) */
  deleteIcon(exerciseId: number): boolean {
    const filePath = path.join(this.iconsDir, `${exerciseId}.png`);
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
      return true;
    }
    return false;
  }
}
