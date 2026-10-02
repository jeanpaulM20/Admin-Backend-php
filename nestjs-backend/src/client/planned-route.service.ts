import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PlannedRoute } from '../entities/planned-route.entity';
import { RoutePoint, ToursService } from './tours.service';

/** Gespeicherte Route existiert nicht (oder gehört einem anderen Klienten). */
export class PlannedRouteNotFoundError extends Error {
  constructor() {
    super('Route nicht gefunden');
    this.name = 'PlannedRouteNotFoundError';
  }
}

/** Obergrenze gespeicherter Routen je Klient erreicht. */
export class PlannedRouteLimitError extends Error {
  constructor(max: number) {
    super(`Maximal ${max} gespeicherte Routen — bitte zuerst eine löschen.`);
    this.name = 'PlannedRouteLimitError';
  }
}

export interface PlannedRouteInput {
  name: string;
  activity: string;
  roundtrip: boolean;
  points: RoutePoint[];
}

/**
 * „Meine Routen": gespeicherte Planungen je Klient. Die Geometrie wird
 * beim Speichern serverseitig aus den Punkten berechnet (nicht vom Gerät
 * übernommen) — über den Routing-Cache kostet das in der Regel keinen
 * weiteren BRouter-Aufruf, weil die App dieselbe Route gerade gerechnet hat.
 */
@Injectable()
export class PlannedRouteService {
  static readonly MAX_PER_CLIENT = 100;
  private static readonly NAME_MAX = 120;

  constructor(
    @InjectRepository(PlannedRoute) private readonly repo: Repository<PlannedRoute>,
    private readonly tours: ToursService,
  ) {}

  /** Liste ohne Geometrie (leicht), neueste zuerst. */
  async list(clientId: number) {
    const rows = await this.repo.find({
      where: { clientId },
      order: { updatedAt: 'DESC', id: 'DESC' },
      select: ['id', 'name', 'activity', 'roundtrip', 'points', 'distanceKm',
               'elevationGain', 'elevationLoss', 'durationMin', 'difficulty', 'updatedAt'],
    });
    return rows.map((r) => PlannedRouteService.summary(r));
  }

  /** Volle Route in der Tour-Detail-Form (Karte, Höhenprofil, Starten). */
  async detail(clientId: number, id: number) {
    const row = await this.find(clientId, id);
    const geometry: (number | null)[][] = JSON.parse(row.geometry);
    return {
      ...PlannedRouteService.summary(row),
      id: `saved-${row.id}`,
      savedId: row.id,
      plannerActivity: row.activity,
      activity: ToursService.osmActivity(row.activity),
      generated: true,
      segments: [geometry.map((g) => ({ lat: g[0], lon: g[1], ele: g[2] ?? null }))],
    };
  }

  async create(clientId: number, input: PlannedRouteInput) {
    const count = await this.repo.count({ where: { clientId } });
    if (count >= PlannedRouteService.MAX_PER_CLIENT) {
      throw new PlannedRouteLimitError(PlannedRouteService.MAX_PER_CLIENT);
    }
    // Das Routing kann Sekunden dauern — die Grenze deshalb unmittelbar
    // vor dem Einfügen nochmals prüfen (parallele Speicher-Anfragen)
    const fields = await this.computed(input);
    const now = new Date();
    const saved = await this.repo.manager.transaction(async (m) => {
      const repo = m.getRepository(PlannedRoute);
      if (await repo.count({ where: { clientId } }) >= PlannedRouteService.MAX_PER_CLIENT) {
        throw new PlannedRouteLimitError(PlannedRouteService.MAX_PER_CLIENT);
      }
      return repo.save(repo.create({ clientId, createdAt: now, updatedAt: now, ...fields }));
    });
    return PlannedRouteService.summary(saved);
  }

  /** Umbenennen (nur `name`) oder die Route mit neuen Punkten ersetzen. */
  async update(clientId: number, id: number, patch: { name?: string; route?: Omit<PlannedRouteInput, 'name'> }) {
    const row = await this.find(clientId, id);
    if (patch.route) {
      Object.assign(row, await this.computed({ ...patch.route, name: patch.name ?? row.name }));
    } else if (patch.name !== undefined) {
      row.name = PlannedRouteService.cleanName(patch.name);
    }
    row.updatedAt = new Date();
    return PlannedRouteService.summary(await this.repo.save(row));
  }

  async remove(clientId: number, id: number) {
    const res = await this.repo.delete({ id, clientId });
    if (!res.affected) throw new PlannedRouteNotFoundError();
    return { deleted: true };
  }

  // ── intern ───────────────────────────────────────────────────────────

  /** Eigentumsprüfung in der Abfrage: fremde IDs sind „nicht gefunden". */
  private async find(clientId: number, id: number): Promise<PlannedRoute> {
    const row = await this.repo.findOne({ where: { id, clientId } });
    if (!row) throw new PlannedRouteNotFoundError();
    return row;
  }

  /** Punkte → berechnete Route → zu speichernde Felder. */
  private async computed(input: PlannedRouteInput) {
    const activity = ToursService.PLANNER_ACTIVITIES.includes(input.activity) ? input.activity : 'wandern';
    const tour = await this.tours.routeVia(input.points, activity, input.roundtrip);
    return {
      name: PlannedRouteService.cleanName(input.name),
      activity,
      roundtrip: input.roundtrip,
      points: JSON.stringify(input.points.map((p) => ({ lat: p.lat, lon: p.lon }))),
      geometry: JSON.stringify(tour.segments[0].map((p) => [p.lat, p.lon, p.ele])),
      distanceKm: tour.distanceKm,
      elevationGain: tour.elevationGain ?? null,
      elevationLoss: tour.elevationLoss ?? null,
      durationMin: tour.durationMin ?? null,
      difficulty: tour.difficulty ?? null,
    };
  }

  private static cleanName(name: string): string {
    const trimmed = String(name ?? '').replace(/\s+/g, ' ').trim().slice(0, PlannedRouteService.NAME_MAX);
    return trimmed || 'Route';
  }

  private static summary(r: PlannedRoute) {
    return {
      id: r.id,
      name: r.name,
      activity: r.activity,
      roundtrip: !!r.roundtrip,
      points: JSON.parse(r.points) as RoutePoint[],
      distanceKm: r.distanceKm,
      elevationGain: r.elevationGain,
      elevationLoss: r.elevationLoss,
      durationMin: r.durationMin,
      difficulty: r.difficulty,
      updatedAt: r.updatedAt,
    };
  }
}
