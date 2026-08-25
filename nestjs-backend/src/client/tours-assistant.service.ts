import { Injectable, Logger } from '@nestjs/common';
import Anthropic from '@anthropic-ai/sdk';
import { ToursService } from './tours.service';

/**
 * Touren-Assistent (KONZEPT-TOUREN-CHAT.md, Phase C1):
 * Natürlichsprachige Tourenwünsche → Claude mit Werkzeug-Loop
 * (geocode/route/rundtour) → ehrliche Antwort + berechnete Route.
 * Das Modell darf keine Route empfehlen, die es nicht berechnet hat.
 */
@Injectable()
export class ToursAssistantService {
  private readonly logger = new Logger(ToursAssistantService.name);
  private readonly anthropic?: Anthropic;

  /**
   * Tageslimit je Kunde (Missbrauchs-/Kostenbremse). Über die
   * Umgebungsvariable ASSISTANT_DAILY_LIMIT steuerbar; 0 oder nicht
   * gesetzt = kein Limit (Testphase).
   */
  private readonly usage = new Map<number, { date: string; count: number }>();
  private static readonly DAILY_LIMIT =
    parseInt(process.env.ASSISTANT_DAILY_LIMIT ?? '0', 10) || 0;

  constructor(private readonly tours: ToursService) {
    const key = process.env.ANTHROPIC_API_KEY?.trim();
    if (key) this.anthropic = new Anthropic({ apiKey: key });
    else this.logger.warn('ANTHROPIC_API_KEY not set — Touren-Assistent deaktiviert');
  }

  private static readonly SYSTEM = `Du bist der Touren-Assistent der Sihl-Training-App (Schweizer Personal Training, Zürich). Du hilfst Kundinnen und Kunden, Wander-, Lauf- und Velorouten zu finden.

Regeln:
- Antworte in der Sprache der Frage (meist Deutsch), knapp und freundlich per Du.
- Du darfst NUR Routen empfehlen, die du mit den Werkzeugen berechnet hast — nie Distanzen, Dauern oder Höhenmeter schätzen.
- Prüfe Wünsche ehrlich gegen die berechneten Werte (SAC-Dauer). Weicht eine Route vom Wunsch ab (z. B. länger als das Zeitbudget), benenne die Abweichung ehrlich in Zahlen.
- EISERNE REGEL: Jede Antwort endet ENTWEDER mit genau einer Rückfrage ODER mit einer empfohlenen Route (empfehlung(...) wurde aufgerufen). Es gibt keinen dritten Fall. Auch eine nicht perfekte Route ist besser als keine — empfiehl die beste berechnete Option und sag ehrlich, was abweicht.
- Liegt die berechnete Dauer ÜBER dem Zeitbudget, aber unter dem Doppelten: Empfiehl die berechnete Route DIREKT per empfehlung(...) und benenne die Abweichung ehrlich — KEINE Alternativsuche.
- PFLICHT-SCHRITT: Überschreitet die berechnete Dauer das genannte Zeitbudget auf MEHR ALS DAS DOPPELTE, darfst du NICHT direkt antworten. Du MUSST zuerst mindestens eine Alternative berechnen (geocode eines höher gelegenen, mit Bahn/Bus erreichbaren Startpunkts — z. B. Bergstationen wie "Rigi Kaltbad" oder "Rigi Klösterli" — dann route von dort) und DIESE Alternative per empfehlung(...) empfehlen. Die unmachbare Direktroute nie als Empfehlung stehen lassen.
- "Mit der Bahn zurück/runter" o. Ä. heisst: Einweg-Route reicht; erwähne die Bahn im Text.
- Korrigiere offensichtliche Ortsnamen-Tippfehler stillschweigend (z. B. "Vetznau" → "Vitznau").
- Wenn Angaben fehlen (Start, Aktivität), stelle EINE kurze Rückfrage statt zu raten. Eine Rückfrage ist NUR erlaubt, wenn dir Angaben fehlen, um überhaupt eine Route zu rechnen — nie, um eine Empfehlung abzusichern. Hast du bereits eine Route berechnet, empfiehl die beste davon.
- Wenn du eine finale Route empfiehlst: Rufe zuerst empfehlung(routeId, titel) auf und beschreibe die Route danach im Text (Distanz, Dauer, Höhenmeter, ggf. Bahn-Hinweis).
- Maximal eine empfohlene Route pro Antwort.`;

  private static readonly TOOLS: Anthropic.Tool[] = [
    {
      name: 'geocode',
      description: 'Findet Koordinaten zu einem Ortsnamen (Schweiz und Nachbarländer).',
      input_schema: {
        type: 'object',
        properties: { ort: { type: 'string', description: 'Ortsname, z. B. "Vitznau" oder "Rigi Kulm"' } },
        required: ['ort'],
      },
    },
    {
      name: 'route',
      description: 'Berechnet eine Route von A nach B (echte Wege, Höhenmeter, SAC-Dauer).',
      input_schema: {
        type: 'object',
        properties: {
          startLat: { type: 'number' }, startLon: { type: 'number' },
          zielLat: { type: 'number' }, zielLon: { type: 'number' },
          aktivitaet: { type: 'string', enum: ['wandern', 'joggen', 'velo', 'rennrad', 'gravel', 'mtb'] },
        },
        required: ['startLat', 'startLon', 'zielLat', 'zielLon', 'aktivitaet'],
      },
    },
    {
      name: 'rundtour',
      description: 'Erzeugt eine Rundtour ab einem Startpunkt mit gewünschter Länge.',
      input_schema: {
        type: 'object',
        properties: {
          lat: { type: 'number' }, lon: { type: 'number' },
          distanceKm: { type: 'number' },
          aktivitaet: { type: 'string', enum: ['wandern', 'joggen', 'velo', 'rennrad', 'gravel', 'mtb'] },
        },
        required: ['lat', 'lon', 'distanceKm', 'aktivitaet'],
      },
    },
    {
      name: 'empfehlung',
      description: 'Wählt die finale Route aus, die dem Kunden angezeigt wird.',
      input_schema: {
        type: 'object',
        properties: {
          routeId: { type: 'string', description: 'ID aus route/rundtour' },
          titel: { type: 'string', description: 'Sprechender Name, z. B. "Rigi Kaltbad – Rigi Kulm"' },
        },
        required: ['routeId', 'titel'],
      },
    },
  ];

  async chat(clientId: number, messages: { role: string; content: string }[]) {
    if (!this.anthropic) {
      return { reply: 'Der Touren-Assistent ist zurzeit nicht verfügbar.' };
    }
    // Tageslimit
    if (ToursAssistantService.DAILY_LIMIT > 0) {
      const today = new Date().toISOString().slice(0, 10);
      const u = this.usage.get(clientId);
      const count = u?.date === today ? u.count : 0;
      if (count >= ToursAssistantService.DAILY_LIMIT) {
        return { reply: 'Du hast das Tageslimit des Assistenten erreicht — morgen geht es weiter.' };
      }
      this.usage.set(clientId, { date: today, count: count + 1 });
    }

    // Verlauf säubern und begrenzen
    const history: Anthropic.MessageParam[] = messages
      .filter((m) => (m.role === 'user' || m.role === 'assistant') && typeof m.content === 'string')
      .slice(-12)
      .map((m) => ({ role: m.role as 'user' | 'assistant', content: m.content.slice(0, 2000) }));
    if (!history.length || history[history.length - 1].role !== 'user') {
      return { reply: 'Beschreib mir deine Wunschtour — z. B. Start, Ziel und wie lange sie dauern darf.' };
    }

    // Berechnete Routen der Konversation (nur Zusammenfassung geht ans Modell)
    const routes = new Map<string, any>();
    let chosen: { routeId: string; titel: string } | null = null;
    let routeCounter = 0;

    const convo: Anthropic.MessageParam[] = [...history];
    let reply = '';
    let truncated = false;
    for (let step = 0; step < 8; step++) {
      const res = await this.anthropic.messages.create({
        model: 'claude-haiku-4-5',
        max_tokens: 1500,
        system: ToursAssistantService.SYSTEM,
        tools: ToursAssistantService.TOOLS,
        messages: convo,
      });

      const toolUses = res.content.filter((b): b is Anthropic.ToolUseBlock => b.type === 'tool_use');
      const texts = res.content.filter((b): b is Anthropic.TextBlock => b.type === 'text');
      if (texts.length) reply = texts.map((t) => t.text).join('\n').trim();

      if (!toolUses.length || res.stop_reason !== 'tool_use') {
        truncated = res.stop_reason === 'max_tokens';
        break;
      }

      convo.push({ role: 'assistant', content: res.content });
      const results: Anthropic.ToolResultBlockParam[] = [];
      for (const tu of toolUses) {
        let result: any;
        try {
          result = await this.runTool(tu.name, tu.input as any, routes, () => `r${++routeCounter}`);
          if (tu.name === 'empfehlung') chosen = tu.input as any;
        } catch (err: any) {
          result = { fehler: err?.message ?? 'Werkzeug fehlgeschlagen' };
        }
        results.push({ type: 'tool_result', tool_use_id: tu.id, content: JSON.stringify(result) });
      }
      convo.push({ role: 'user', content: results });
    }

    // Finale Route als TourDetail-JSON (Schema des Rundtouren-Endpoints).
    // Garantie: Hat der Loop Routen berechnet, bekommt der Kunde eine Karte —
    // auch wenn das Modell empfehlung() vergessen hat (zuletzt berechnete
    // Route = in der Regel die beste/letzte Alternative).
    let route: any;
    if (chosen && routes.has(chosen.routeId)) {
      const r = routes.get(chosen.routeId);
      route = { ...r.detail, id: `assist-${Date.now()}`, name: chosen.titel };
    } else if (routes.size > 0) {
      const last = [...routes.values()][routes.size - 1].detail;
      const name = last.name && last.name !== 'Route'
        ? last.name
        : `Route · ${last.distanceKm} km`;
      route = { ...last, id: `assist-${Date.now()}`, name };
    }
    if (truncated && reply) reply += ' …';
    return { reply: reply || 'Da ist etwas schiefgelaufen — versuch es bitte nochmal.', route };
  }

  // ── Werkzeuge ──────────────────────────────────────────────────────

  private async runTool(
    name: string,
    input: any,
    routes: Map<string, any>,
    nextId: () => string,
  ): Promise<any> {
    switch (name) {
      case 'geocode':
        return this.tours.geocode(String(input.ort ?? ''));
      case 'route': {
        const detail = await this.tours.routeAB(
          Number(input.startLat), Number(input.startLon),
          Number(input.zielLat), Number(input.zielLon),
          String(input.aktivitaet ?? 'wandern'),
        );
        const id = nextId();
        routes.set(id, { detail });
        return {
          routeId: id,
          distanceKm: detail.distanceKm,
          elevationGain: detail.elevationGain,
          durationMin: detail.durationMin,
        };
      }
      case 'rundtour': {
        const detail = await this.tours.generateRoundtrip(
          Number(input.lat), Number(input.lon),
          Number(input.distanceKm), String(input.aktivitaet ?? 'wandern'),
        );
        const id = nextId();
        routes.set(id, { detail });
        return {
          routeId: id,
          distanceKm: detail.distanceKm,
          elevationGain: detail.elevationGain,
          durationMin: detail.durationMin,
        };
      }
      case 'empfehlung':
        if (!routes.has(String(input.routeId))) return { fehler: 'Unbekannte routeId' };
        return { ok: true };
      default:
        return { fehler: `Unbekanntes Werkzeug ${name}` };
    }
  }

}
