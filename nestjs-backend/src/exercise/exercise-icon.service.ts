import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, IsNull, Not } from 'typeorm';
import { Exercise } from '../entities/exercise.entity';
import OpenAI from 'openai';

// ── Prompt building (Photorealistic Nike/HYROX performance style) ─────────────

const ATHLETES = [
  'A highly athletic Black woman',
  'A highly athletic Caucasian man',
  'A highly athletic Mediterranean man',
  'A highly athletic Black man',
  'A highly athletic Caucasian woman',
  'A highly athletic East Asian woman',
];

const GROUNDS: Record<string, string> = {
  grass: 'on a perfectly manicured, vibrant green natural grass sports field; the vivid green blades of grass are crystal-sharp beneath the bare feet.',
  rubber: 'on heavy-duty black speckled rubber fitness flooring tiles, exactly like in a premium outdoor gym; the matte, textured impact-protection surface is crystal-sharp beneath the bare feet.',
  sawdust: 'on an outdoor Finnenbahn running path made from natural wood chips and coarse sawdust; the rich, realistic texture of the wood-chip surface is crystal-sharp beneath the bare feet.',
  tartan: 'on a professional terracotta-red polyurethane running track (Tartanbahn); the textured, high-grip athletic surface is crystal-sharp beneath the bare feet.',
};

/** Map exercise group to the best-fitting ground surface */
const GROUP_GROUND: Record<string, string> = {
  'Plyometrie & Reaktivkraft': 'tartan',
  'Ausdauer & Intervalltraining': 'tartan',
  'Kettlebell-Training': 'rubber',
  'Eigenkörpergewicht / Calisthenics': 'rubber',
  'Ring- & Suspension-Training': 'rubber',
  'Exzentrisches Training': 'rubber',
  'Mobilität & Aktive Beweglichkeit': 'grass',
  'Propriozeption': 'sawdust',
  'Fußmuskulatur & Barfuß-Training': 'grass',
  'Slackline': 'grass',
};

/** Map exercise group to a movement description hint */
const GROUP_HINTS: Record<string, string> = {
  'Kettlebell-Training': 'with a kettlebell',
  'Ring- & Suspension-Training': 'on gymnastic rings or suspension straps',
  'Plyometrie & Reaktivkraft': 'in an explosive, powerful athletic movement',
  'Mobilität & Aktive Beweglichkeit': 'in a controlled mobility and flexibility pose',
  'Propriozeption': 'focusing on balance and proprioceptive control',
  'Fußmuskulatur & Barfuß-Training': 'with emphasis on barefoot foot mechanics',
  'Slackline': 'on a slackline',
  'Exzentrisches Training': 'in a slow, controlled eccentric lowering phase',
  'Ausdauer & Intervalltraining': 'in a high-intensity cardio movement',
  'Eigenkörpergewicht / Calisthenics': 'using only bodyweight',
};

function buildPrompt(exercise: Exercise): string {
  const name = exercise.name || 'exercise';
  const groupName = (exercise as any).group?.name || '';
  const groupHint = GROUP_HINTS[groupName] || '';

  // Rotate athlete based on exercise ID
  const athlete = ATHLETES[(exercise.id ?? 0) % ATHLETES.length];

  // Select ground surface based on group
  const groundKey = GROUP_GROUND[groupName] || 'rubber';
  const ground = GROUNDS[groundKey];

  // Build exercise description in English
  const parenMatch = name.match(/\(([^)]+)\)/);
  const subTitle = parenMatch ? ` (${parenMatch[1]})` : '';
  const exerciseDesc = `executing "${name}"${subTitle} ${groupHint}`.trim();

  return `Dynamic outdoor fitness photography shot from a low angle looking up. ${athlete} with a fit, athletic physique is ${exerciseDesc}. The body posture must be anatomically correct and biomechanically accurate for this specific exercise — correct joint angles, proper spine alignment, and realistic weight distribution. The athlete is completely barefoot, NO shoes, NO socks. STRICT ANATOMY RULES: exactly 5 fingers on each hand, exactly 5 toes on each foot, no extra or missing digits. Hands and feet must be anatomically perfect and photorealistic. The bare feet show natural toe splay with all five toes clearly separated and individually visible, active foot arch engagement. The scene is shot outdoors ${ground} The background features lush green trees, foliage and bright sky with beautiful natural bokeh. The athlete is wearing a fitted matte black athletic t-shirt and matching matte black training shorts — fully clothed, professional sportswear look. The lighting is bright natural daylight filtering through trees, with subtle rim light and backlight on the athlete's body. The overall mood is energetic, free and dynamic — a frozen split-second of powerful athletic movement in nature. Shot from a dramatic low angle perspective, sharp focus on the athlete with strong depth of field separation, natural warm color tones, 8k resolution, authentic outdoor sports photography.`;
}

// ── Service ──────────────────────────────────────────────────────────────────

@Injectable()
export class ExerciseIconService {
  private readonly logger = new Logger(ExerciseIconService.name);
  private readonly openai: OpenAI | null;

  constructor(
    @InjectRepository(Exercise)
    private readonly exerciseRepo: Repository<Exercise>,
  ) {
    const apiKey = process.env.OPENAI_API_KEY;
    this.openai = apiKey ? new OpenAI({ apiKey }) : null;

    if (!this.openai) {
      this.logger.warn('OPENAI_API_KEY not set — icon generation disabled');
    }
  }

  /** Get the public URL path for an exercise icon */
  iconUrl(exerciseId: number): string {
    return `/api/exercise/${exerciseId}/icon.png`;
  }

  /** Check if an exercise has an icon in the DB */
  async iconExists(exerciseId: number): Promise<boolean> {
    const row = await this.exerciseRepo
      .createQueryBuilder('e')
      .select('1')
      .where('e.id = :id', { id: exerciseId })
      .andWhere('e.icon IS NOT NULL')
      .getRawOne();
    return !!row;
  }

  /** Get the icon binary from DB (for serving) */
  async getIconBuffer(exerciseId: number): Promise<Buffer | null> {
    const row = await this.exerciseRepo
      .createQueryBuilder('e')
      .select('e.icon', 'icon')
      .where('e.id = :id', { id: exerciseId })
      .getRawOne();
    return row?.icon ?? null;
  }

  /** Get status: which exercises have icons, which don't */
  async getStatus(): Promise<{
    total: number;
    withIcon: number;
    withoutIcon: number;
    configured: boolean;
    missing: { id: number; name: string }[];
  }> {
    const total = await this.exerciseRepo.count();
    const withIcon = await this.exerciseRepo
      .createQueryBuilder('e')
      .where('e.icon IS NOT NULL')
      .getCount();
    const missing = await this.exerciseRepo
      .createQueryBuilder('e')
      .select(['e.id', 'e.name'])
      .where('e.icon IS NULL')
      .orderBy('e.id', 'ASC')
      .getMany();

    return {
      total,
      withIcon,
      withoutIcon: total - withIcon,
      configured: !!this.openai,
      missing: missing.map((e) => ({ id: e.id, name: e.name })),
    };
  }

  /**
   * Generate an icon for a single exercise via OpenAI and save to DB.
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

    try {
      const response = await this.openai.images.generate({
        model: 'gpt-image-1',
        prompt,
        n: 1,
        size: '1024x1024',
        quality: 'medium',
        output_format: 'png',
      } as any);

      const item = response.data?.[0] as any;
      let imageBuffer: Buffer;

      if (item?.b64_json) {
        imageBuffer = Buffer.from(item.b64_json, 'base64');
      } else if (item?.url) {
        const dl = await fetch(item.url);
        imageBuffer = Buffer.from(await dl.arrayBuffer());
      } else {
        this.logger.warn(`No image data returned for exercise ${exerciseId}`);
        return null;
      }

      // Save to DB
      await this.exerciseRepo
        .createQueryBuilder()
        .update(Exercise)
        .set({ icon: imageBuffer } as any)
        .where('id = :id', { id: exerciseId })
        .execute();

      this.logger.log(`Icon saved to DB for "${exercise.name}" (${imageBuffer.length} bytes)`);
      return this.iconUrl(exerciseId);
    } catch (err: any) {
      const detail = err?.error?.message || err?.message || String(err);
      this.logger.error(`Failed to generate icon for "${exercise.name}": ${detail}`);
      throw new Error(detail);
    }
  }

  /**
   * Batch generate icons for all exercises that don't have one yet.
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
    const delayMs = options?.delayMs ?? 15000; // 15s default (safe for 5 req/min rate limit)

    const missing = await this.exerciseRepo
      .createQueryBuilder('e')
      .select(['e.id', 'e.name'])
      .where('e.icon IS NULL')
      .orderBy('e.id', 'ASC')
      .take(limit)
      .getMany();

    this.logger.log(`Batch generating: ${missing.length} icons (limit=${limit}, delay=${delayMs}ms)`);

    const results: { id: number; name: string; status: string; url?: string }[] = [];
    let generated = 0;
    let failed = 0;

    for (let i = 0; i < missing.length; i++) {
      const exercise = missing[i];
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
        results.push({ id: exercise.id, name: exercise.name, status: `error: ${err.message?.substring(0, 100)}` });
        failed++;
      }

      // Rate limit delay between requests
      if (i < missing.length - 1) {
        await new Promise((r) => setTimeout(r, delayMs));
      }
    }

    return { generated, failed, skipped: 0, results };
  }

  /** Delete ALL icons from DB (for style change regeneration) */
  async deleteAllIcons(): Promise<{ deleted: number }> {
    const result = await this.exerciseRepo
      .createQueryBuilder()
      .update(Exercise)
      .set({ icon: null } as any)
      .where('icon IS NOT NULL')
      .execute();
    const count = result.affected ?? 0;
    this.logger.log(`Deleted all icons: ${count} exercises cleared`);
    return { deleted: count };
  }

  /** Delete an icon from DB (for regeneration) */
  async deleteIcon(exerciseId: number): Promise<boolean> {
    const result = await this.exerciseRepo
      .createQueryBuilder()
      .update(Exercise)
      .set({ icon: null } as any)
      .where('id = :id', { id: exerciseId })
      .execute();
    return (result.affected ?? 0) > 0;
  }
}
