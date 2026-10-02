import { Entity, PrimaryGeneratedColumn, Column, Index } from 'typeorm';

/**
 * Eine gespeicherte Route aus dem Routenplaner („Meine Routen").
 * Gespeichert werden die gesetzten Punkte (zum Weiterbearbeiten) und die
 * berechnete, ausgedünnte Geometrie mit Kennzahlen (zum Anzeigen und
 * Starten ohne erneutes Routing). Privat je Klient — geplante Routen
 * beginnen oft zu Hause.
 */
@Entity({ name: 'planned_route' })
export class PlannedRoute {
  @PrimaryGeneratedColumn()
  id: number;

  @Index('idx_planned_route_client')
  @Column({ name: 'client_id' })
  clientId: number;

  @Column({ length: 120 })
  name: string;

  /** Planer-Aktivität: wandern | bergtour | joggen | rennrad | gravel | mtb */
  @Column({ length: 20 })
  activity: string;

  @Column({ default: false })
  roundtrip: boolean;

  /** JSON: [{lat, lon}] — die gesetzten Punkte in Reihenfolge */
  @Column({ type: 'text' })
  points: string;

  /**
   * JSON: [[lat, lon, ele|null]] — berechnete Route, ≤ 2000 Punkte (~60 KB).
   * In MySQL als MEDIUMTEXT angelegt (Startup-Migration); hier `text`,
   * weil SQLite (lokale Entwicklung) `mediumtext` nicht kennt.
   */
  @Column({ type: 'text' })
  geometry: string;

  @Column({ name: 'distance_km', type: 'float' })
  distanceKm: number;

  @Column({ name: 'elevation_gain', type: 'int', nullable: true })
  elevationGain: number | null;

  @Column({ name: 'elevation_loss', type: 'int', nullable: true })
  elevationLoss: number | null;

  @Column({ name: 'duration_min', type: 'int', nullable: true })
  durationMin: number | null;

  @Column({ type: 'varchar', length: 20, nullable: true })
  difficulty: string | null;

  @Column({ name: 'created_at', type: 'datetime' })
  createdAt: Date;

  @Column({ name: 'updated_at', type: 'datetime' })
  updatedAt: Date;
}
