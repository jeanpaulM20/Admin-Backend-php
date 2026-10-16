/**
 * Ausschnitt der AccessLink-Antwort von GET /v3/exercises[/{id}] — nur die
 * Felder, die wir übernehmen. Alles ist optional: Polar lässt Felder weg,
 * wenn das Gerät sie nicht misst.
 */
export interface PolarExercise {
  id: string;
  /** Lokale Startzeit ohne Zone, z. B. "2026-10-14T07:12:03" */
  start_time?: string;
  /** Abweichung der lokalen Zeit von UTC in Minuten */
  start_time_utc_offset?: number;
  /** ISO-8601-Dauer, z. B. "PT1H2M3S" */
  duration?: string;
  calories?: number;
  /** Meter */
  distance?: number;
  heart_rate?: { average?: number; maximum?: number };
  sport?: string;
  detailed_sport_info?: string;
  samples?: PolarSample[];
  route?: PolarRoutePoint[];
}

export interface PolarSample {
  /** Sekunden zwischen zwei Werten */
  'recording-rate'?: number;
  'sample-type'?: string;
  /** Kommagetrennte Werte */
  data?: string;
}

export interface PolarRoutePoint {
  latitude?: number;
  longitude?: number;
  /** Abstand zum Start als ISO-8601-Dauer, z. B. "PT210.026S" */
  time?: string;
}

/**
 * Sample-Typen laut AccessLink-Anhang. Die Doku-Seite nennt die Tabelle nicht
 * im Fliesstext; 0 = Herzfrequenz (bpm) und 3 = Höhe (m) entsprechen der
 * bekannten Polar-Belegung und werden beim ersten echten Import geprüft.
 */
export const SAMPLE_TYPE_HEART_RATE = '0';
export const SAMPLE_TYPE_ALTITUDE = '3';
