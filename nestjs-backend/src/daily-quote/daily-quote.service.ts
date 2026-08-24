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

  /** Zuletzt verwendete Autoren je Client (best effort, übersteht keinen Deploy). */
  private readonly recentAuthors = new Map<number, string[]>();

  /** Themenrichtungen — erzwingen Tagesvarianz, wo das Modell sonst auf
   *  dieselben Lieblingszitate konvergiert. */
  private static readonly THEMES = [
    'Ausdauer und Dranbleiben',
    'Mut und Anfangen',
    'Disziplin und Gewohnheit',
    'Erholung und Geduld',
    'Freude an der Bewegung',
    'Wachstum durch Widerstand',
    'Gelassenheit und mentale Stärke',
    'Natur und Draussensein',
    'kleine Schritte, grosse Wirkung',
    'Selbstvertrauen',
  ];

  constructor(
    @InjectRepository(TrainingPlan)
    private readonly planRepo: Repository<TrainingPlan>,
  ) {
    const key = process.env.ANTHROPIC_API_KEY?.trim();
    if (key) this.anthropic = new Anthropic({ apiKey: key });
    else this.logger.warn('ANTHROPIC_API_KEY not set — daily quotes will use fallback list');
  }

  async getQuote(clientId: number, firstName: string): Promise<DailyQuoteDto> {
    // Tageswechsel um Mitternacht Schweizer Zeit (nicht UTC — sonst erst um 1/2 Uhr)
    const today = new Intl.DateTimeFormat('sv-SE', {
      timeZone: 'Europe/Zurich',
    }).format(new Date()); // YYYY-MM-DD

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
    // Tagesabhängiges Thema (je Client verschoben) + zuletzt verwendete
    // Autoren vermeiden → echte Varianz von Tag zu Tag
    const dayNum = Math.floor(new Date(today).getTime() / 86_400_000);
    const theme = DailyQuoteService.THEMES[(dayNum + clientId) % DailyQuoteService.THEMES.length];
    const avoid = this.recentAuthors.get(clientId) ?? [];

    const quote = this.anthropic
      ? await this._generateWithClaude(firstName, context, today, theme, avoid)
      : this._fallback();

    const authors = [quote.author, ...avoid].slice(0, 7);
    this.recentAuthors.set(clientId, authors);

    // ── 4. Cache for today ──────────────────────────────────────────────────
    this.cache.set(clientId, { date: today, quote });
    return quote;
  }

  private async _generateWithClaude(
    firstName: string,
    context: string,
    today: string,
    theme: string,
    avoidAuthors: string[],
  ): Promise<DailyQuoteDto> {
    try {
      const avoidLine = avoidAuthors.length
        ? `\n- Wähle eine Person, die NICHT in dieser Liste steht: ${avoidAuthors.join('; ')}.`
        : '';
      const msg = await this.anthropic!.messages.create({
        model: 'claude-haiku-4-5',
        max_tokens: 256,
        messages: [
          {
            role: 'user',
            content: `Heute ist der ${today}. Du wählst das Tageszitat für ${firstName}, der/die gerade mit folgendem Schwerpunkt trainiert: ${context}.

Heutige Themenrichtung: ${theme}.

Regeln:
- Wähle ein ECHTES, belegtes Zitat einer realen Person (Athlet, Philosoph, Denker, Wissenschaftler, Künstler).
- Verwende nur Zitate, bei denen du sehr sicher bist, dass sie korrekt zitiert und korrekt zugeschrieben sind.
- Überrasche: Jeder Tag soll ein anderes Zitat einer anderen Person bringen — greife bewusst auch zu weniger naheliegenden Persönlichkeiten.${avoidLine}
- Das Zitat soll zur heutigen Themenrichtung passen.
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
