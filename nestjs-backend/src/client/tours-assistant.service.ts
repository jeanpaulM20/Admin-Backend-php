import { Injectable, Logger } from '@nestjs/common';
import Anthropic from '@anthropic-ai/sdk';
import { RoutePoint, ToursService } from './tours.service';

/**
 * Planungsdaten einer berechneten Route: die Punkte in Reihenfolge, die
 * Planer-Aktivität und ob es ein Rundkurs ist. Damit lässt sich die
 * Empfehlung in der App im Routenplaner öffnen und anpassen (Phase 4).
 */
interface RoutePlan {
  points: RoutePoint[];
  activity: string;
  roundtrip: boolean;
}

/**
 * Touren-Assistent (KONZEPT-TOUREN-CHAT.md, Phase C1):
 * Natürlichsprachige Tourenwünsche → Claude mit Werkzeug-Loop
 * (geocode/route/route_ueber/rundtour) → ehrliche Antwort + berechnete
 * Route samt Planungspunkten für den Routenplaner.
 * Das Modell darf keine Route empfehlen, die es nicht berechnet hat.
 */
@Injectable()
export class ToursAssistantService {
  private readonly logger = new Logger(ToursAssistantService.name);
  private readonly anthropic?: Anthropic;

  /**
   * Tageslimit je Kunde (Missbrauchs-/Kostenbremse): 30 Fragen pro Tag.
   * Über die Umgebungsvariable ASSISTANT_DAILY_LIMIT übersteuerbar;
   * dort bedeutet 0 „kein Limit". Der Zähler lebt im Speicher der
   * Instanz und beginnt nach einem Neustart/Deploy von vorn.
   */
  private readonly usage = new Map<number, { date: string; count: number }>();
  private static readonly DEFAULT_DAILY_LIMIT = 30;
  private static readonly DAILY_LIMIT = ToursAssistantService.dailyLimit(process.env.ASSISTANT_DAILY_LIMIT);

  /** Nicht gesetzt/leer/ungültig → Standard; eine Zahl (auch 0) gilt wie angegeben. */
  static dailyLimit(raw: string | undefined): number {
    const value = raw?.trim();
    if (!value) return ToursAssistantService.DEFAULT_DAILY_LIMIT;
    const parsed = parseInt(value, 10);
    return Number.isFinite(parsed) && parsed >= 0 ? parsed : ToursAssistantService.DEFAULT_DAILY_LIMIT;
  }

  /** Kalendertag in der Schweiz — das Limit wechselt um Mitternacht Ortszeit. */
  private static today(): string {
    return new Date().toLocaleDateString('sv-SE', { timeZone: 'Europe/Zurich' });
  }

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
- Nennt der Wunsch Zwischenziele ("über", "via", "vorbei an", "mit Abstecher zu"), geocode JEDEN genannten Ort und berechne die Route mit route_ueber — alle Punkte in der gewünschten Reihenfolge. Soll die Tour am Start enden ("und zurück", "Runde über …"), setze rundkurs=true und nenne den Start NICHT nochmals als letzten Punkt. Ohne Zwischenziele bleibt es bei route bzw. rundtour. Nach route_ueber gilt wie immer: empfehlung(...) aufrufen und Distanz, Dauer sowie Höhenmeter im Text nennen — keine Rückfrage mehr.
- Für hochalpine Touren (Gipfel, Hütten, weiss-rot-weiss/alpin) nutze aktivitaet "bergtour".
- Velo-Wünsche: "gravel" für Touren auf Nebenstrassen, Rad- und Kieswegen (auch für allgemeine Velotouren), "rennrad" für Strasse, "mtb" für Trails.
- Korrigiere offensichtliche Ortsnamen-Tippfehler stillschweigend (z. B. "Vetznau" → "Vitznau").
- Wenn Angaben fehlen (Start, Aktivität), stelle EINE kurze Rückfrage statt zu raten. Eine Rückfrage ist NUR erlaubt, wenn dir Angaben fehlen, um überhaupt eine Route zu rechnen — nie, um eine Empfehlung abzusichern. Hast du bereits eine Route berechnet, empfiehl die beste davon.
- Wenn du eine finale Route empfiehlst: Rufe zuerst empfehlung(routeId, titel) auf und beschreibe die Route danach im Text (Distanz, Dauer, Höhenmeter, ggf. Bahn-Hinweis).
- Maximal eine empfohlene Route pro Antwort.`;

  /**
   * Aktivitäten der Werkzeuge = Aktivitäten des Routenplaners. „velo"
   * (Trekking) ist bewusst nicht dabei: Der Planer hat kein solches
   * Profil, und die Empfehlung soll dort exakt gleich nachgerechnet werden.
   */
  private static readonly ACTIVITIES = ['wandern', 'bergtour', 'joggen', 'rennrad', 'gravel', 'mtb'];

  /**
   * Höchstens so viele Routing-Aufrufe je Chat-Anfrage — schützt die
   * öffentliche BRouter-Instanz (und damit den Planer aller Nutzer) vor
   * einer Anfrage, die das Modell zu vielen Berechnungen treibt.
   */
  private static readonly MAX_ROUTING_CALLS = 6;
  private static readonly ROUTING_TOOLS = ['route', 'route_ueber', 'rundtour'];

  /**
   * Assistenten-Aktivität → Aktivität des Routenplaners. Der Planer kennt
   * kein „velo" (Trekking-Rad); am nächsten liegt Gravel.
   */
  private static plannerActivity(aktivitaet: string): string {
    if (aktivitaet === 'velo' || aktivitaet === 'rad') return 'gravel';
    return ToursService.PLANNER_ACTIVITIES.includes(aktivitaet) ? aktivitaet : 'wandern';
  }

  /** Zwei Punkte liegen praktisch aufeinander (< ~50 m). */
  private static near(a: RoutePoint, b: RoutePoint): boolean {
    const dLat = (a.lat - b.lat) * 110_574;
    const dLon = (a.lon - b.lon) * 111_320 * Math.cos((a.lat * Math.PI) / 180);
    return Math.hypot(dLat, dLon) < 50;
  }

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
          aktivitaet: { type: 'string', enum: ToursAssistantService.ACTIVITIES },
        },
        required: ['startLat', 'startLon', 'zielLat', 'zielLon', 'aktivitaet'],
      },
    },
    {
      name: 'route_ueber',
      description:
        'Berechnet eine Route über mehrere Punkte in fester Reihenfolge: Start, Zwischenziele, Ziel '
        + '(echte Wege, Höhenmeter auf/ab, SAC-Dauer). Für Wünsche mit "über", "via" oder mehreren Etappenorten.',
      input_schema: {
        type: 'object',
        properties: {
          punkte: {
            type: 'array',
            description: 'Start, Zwischenziele und Ziel in Reihenfolge (2 bis 25 Punkte), Koordinaten aus geocode.',
            minItems: 2,
            maxItems: ToursService.MAX_VIA_POINTS,
            items: {
              type: 'object',
              properties: { lat: { type: 'number' }, lon: { type: 'number' } },
              required: ['lat', 'lon'],
            },
          },
          aktivitaet: { type: 'string', enum: ToursAssistantService.ACTIVITIES },
          rundkurs: { type: 'boolean', description: 'true = vom letzten Punkt zurück zum Start' },
        },
        required: ['punkte', 'aktivitaet'],
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
          aktivitaet: { type: 'string', enum: ToursAssistantService.ACTIVITIES },
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
      const today = ToursAssistantService.today();
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
    const routes = new Map<string, { detail: any; plan: RoutePlan }>();
    const budget = { routingLeft: ToursAssistantService.MAX_ROUTING_CALLS };
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
          result = await this.runTool(tu.name, tu.input as any, routes, () => `r${++routeCounter}`, budget);
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
    const picked = chosen ? routes.get(chosen.routeId) : undefined;
    if (chosen && picked) {
      route = { ...picked.detail, id: `assist-${Date.now()}`, name: chosen.titel, plan: picked.plan };
    } else if (routes.size > 0) {
      const lastEntry = [...routes.values()][routes.size - 1];
      const last = lastEntry.detail;
      const name = last.name && !['Route', 'Geplante Route'].includes(last.name)
        ? last.name
        : `Route · ${last.distanceKm} km`;
      route = { ...last, id: `assist-${Date.now()}`, name, plan: lastEntry.plan };
    }
    if (truncated && reply) reply += ' …';
    return { reply: reply || 'Da ist etwas schiefgelaufen — versuch es bitte nochmal.', route };
  }

  // ── Werkzeuge ──────────────────────────────────────────────────────

  private async runTool(
    name: string,
    input: any,
    routes: Map<string, { detail: any; plan: RoutePlan }>,
    nextId: () => string,
    budget: { routingLeft: number },
  ): Promise<any> {
    if (ToursAssistantService.ROUTING_TOOLS.includes(name)) {
      if (budget.routingLeft <= 0) {
        return { fehler: 'Rechenlimit dieser Anfrage erreicht — empfiehl die beste bereits berechnete Route.' };
      }
      budget.routingLeft--;
    }
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
        const plan: RoutePlan = {
          points: [
            { lat: Number(input.startLat), lon: Number(input.startLon) },
            { lat: Number(input.zielLat), lon: Number(input.zielLon) },
          ],
          activity: ToursAssistantService.plannerActivity(String(input.aktivitaet ?? 'wandern')),
          roundtrip: false,
        };
        routes.set(id, { detail, plan });
        return {
          routeId: id,
          distanceKm: detail.distanceKm,
          elevationGain: detail.elevationGain,
          durationMin: detail.durationMin,
        };
      }
      case 'route_ueber': {
        const raw: any[] = Array.isArray(input.punkte) ? input.punkte : [];
        const points: RoutePoint[] = raw.map((p) => ({ lat: Number(p?.lat), lon: Number(p?.lon) }));
        if (points.length < 2 || points.length > ToursService.MAX_VIA_POINTS
            || points.some((p) => !Number.isFinite(p.lat) || !Number.isFinite(p.lon)
              || Math.abs(p.lat) > 90 || Math.abs(p.lon) > 180)) {
          return { fehler: `punkte: 2 bis ${ToursService.MAX_VIA_POINTS} gültige Koordinaten erforderlich` };
        }
        const aktivitaet = String(input.aktivitaet ?? 'wandern');
        // Nennt das Modell den Start nochmals als letzten Punkt, ist das ein
        // Rundkurs — so normalisiert liegen im Planer nicht Start- und
        // Ziel-Pin aufeinander
        let roundtrip = input.rundkurs === true;
        if (points.length >= 3 && ToursAssistantService.near(points[0], points[points.length - 1])) {
          points.pop();
          roundtrip = true;
        }
        const detail = await this.tours.routeVia(points, aktivitaet, roundtrip);
        const id = nextId();
        routes.set(id, {
          detail,
          plan: { points, activity: ToursAssistantService.plannerActivity(aktivitaet), roundtrip },
        });
        return {
          routeId: id,
          distanceKm: detail.distanceKm,
          elevationGain: detail.elevationGain,
          elevationLoss: detail.elevationLoss,
          durationMin: detail.durationMin,
        };
      }
      case 'rundtour': {
        const detail = await this.tours.generateRoundtrip(
          Number(input.lat), Number(input.lon),
          Number(input.distanceKm), String(input.aktivitaet ?? 'wandern'),
        );
        const id = nextId();
        routes.set(id, {
          detail,
          plan: {
            points: detail.waypoints,
            activity: ToursAssistantService.plannerActivity(String(input.aktivitaet ?? 'wandern')),
            roundtrip: true,
          },
        });
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
