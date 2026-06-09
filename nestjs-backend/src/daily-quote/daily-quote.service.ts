import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import Anthropic from '@anthropic-ai/sdk';
import { TrainingPlan } from '../entities/training-plan.entity';

export interface DailyQuoteDto {
  text: string;
  author: string;
}

interface CacheEntry {
  date: string; // YYYY-MM-DD
  quote: DailyQuoteDto;
}

/** Fallback quotes — only used when no ANTHROPIC_API_KEY is set. */
const FALLBACK_QUOTES: DailyQuoteDto[] = [
  { text: 'Es ist nicht das Gebirge, das wir bezwingen, sondern uns selbst.', author: 'Edmund Hillary' },
  { text: 'Bewegung ist Leben. Ohne Bewegung ist das Leben nicht denkbar.', author: 'Moshe Feldenkrais' },
  { text: 'Der Körper wird stark durch Arbeit, der Geist durch Gedanken.', author: 'Jean-Paul Sartre' },
  { text: 'Was uns nicht umbringt, macht uns stärker.', author: 'Friedrich Nietzsche' },
  { text: 'Der Wille ist der Schlüssel zur Kraft.', author: 'Muhammad Ali' },
];

@Injectable()
export class DailyQuoteService {
  private readonly logger = new Logger(DailyQuoteService.name);
  private readonly anthropic?: Anthropic;

  /** In-memory cache: clientId → { date, quote } */
  private readonly cache = new Map<number, CacheEntry>();

  constructor(
    @InjectRepository(TrainingPlan)
    private readonly planRepo: Repository<TrainingPlan>,
  ) {
    const key = process.env.ANTHROPIC_API_KEY?.trim();
    if (key) this.anthropic = new Anthropic({ apiKey: key });
    else this.logger.warn('ANTHROPIC_API_KEY not set — daily quotes will use fallback list');
  }

  async getQuote(clientId: number, firstName: string): Promise<DailyQuoteDto> {
    const today = new Date().toISOString().slice(0, 10); // YYYY-MM-DD

    // ── 1. In-memory cache hit ──────────────────────────────────────────────
    const cached = this.cache.get(clientId);
    if (cached?.date === today) return cached.quote;

    // ── 2. Build client context from most recent published plan ────────────
    const plan = await this.planRepo.findOne({
      where: { clientId, status: 'published' },
      order: { updatedAt: 'DESC' },
    });
    const context = [plan?.goal, plan?.name, plan?.type]
      .filter(Boolean)
      .join(', ') || 'allgemeine Fitness und Gesundheit';

    // ── 3. Generate via Claude (or use fallback) ────────────────────────────
    const quote = this.anthropic
      ? await this._generateWithClaude(firstName, context)
      : this._fallback();

    // ── 4. Cache for today ──────────────────────────────────────────────────
    this.cache.set(clientId, { date: today, quote });
    return quote;
  }

  private async _generateWithClaude(
    firstName: string,
    context: string,
  ): Promise<DailyQuoteDto> {
    try {
      const msg = await this.anthropic!.messages.create({
        model: 'claude-haiku-4-5',
        max_tokens: 256,
        messages: [
          {
            role: 'user',
            content: `Du generierst ein inspirierendes Zitat für ${firstName}, der/die gerade mit folgendem Schwerpunkt trainiert: ${context}.

Regeln:
- Wähle ein ECHTES, belegtes Zitat einer realen Person (Athlet, Philosoph, Denker, Wissenschaftler).
- Verwende nur Zitate, bei denen du sehr sicher bist, dass sie korrekt zitiert und korrekt zugeschrieben sind.
- Das Zitat soll thematisch zu Disziplin, Bewegung, Gesundheit, Wachstum oder Ausdauer passen.
- Antwort auf Deutsch (oder das Originalzitat + deutsche Übersetzung falls passend).
- Antworte NUR als valides JSON ohne Markdown: {"text": "...", "author": "Vorname Nachname, Beruf/Epoche"}`,
          },
        ],
      });

      const raw = ((msg.content[0] as any).text ?? '').trim();
      const clean = raw.replace(/^```json\n?/i, '').replace(/\n?```$/i, '').trim();
      const parsed = JSON.parse(clean);
      if (typeof parsed.text === 'string' && typeof parsed.author === 'string') {
        return { text: parsed.text, author: parsed.author };
      }
    } catch (err: any) {
      this.logger.warn(`Claude quote generation failed: ${err?.message}`);
    }
    return this._fallback();
  }

  /** Day-stable fallback: same quote for the whole day across clients. */
  private _fallback(): DailyQuoteDto {
    const dayIndex = Math.floor(Date.now() / 86_400_000);
    return FALLBACK_QUOTES[dayIndex % FALLBACK_QUOTES.length];
  }
}
